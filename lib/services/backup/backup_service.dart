import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_info.dart';
import 'cloud_backup_settings.dart';

/// True if [host] is `localhost`, a loopback/private-range IPv4 literal, or
/// an `.local` mDNS hostname -- addresses whose traffic never leaves the
/// local machine/network regardless of scheme.
bool isPrivateOrLoopbackHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.local')) return true;

  final ip = InternetAddress.tryParse(host);
  if (ip == null || ip.type != InternetAddressType.IPv4) return false;
  if (ip.isLoopback) return true;

  final parts = ip.rawAddress;
  if (parts[0] == 10) return true; // 10.0.0.0/8
  if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true; // 172.16.0.0/12
  if (parts[0] == 192 && parts[1] == 168) return true; // 192.168.0.0/16
  if (parts[0] == 169 && parts[1] == 254) return true; // 169.254.0.0/16 link-local
  return false;
}

/// Exports/imports all of the app's local user data (library, likes,
/// playback history, settings, addon config, etc.) as a single JSON file --
/// locally, or to a WebDAV endpoint the user points at their own server
/// ([uploadToCloud]/[downloadFromCloud]).
///
/// Every service in the app persists to SharedPreferences, so this reads
/// and restores the entire key-value store generically instead of needing
/// a hand-written serializer per service. Kept as a flat key/value bundle
/// on purpose -- the local and cloud transports both ship the same
/// [_buildEnvelopeJson] envelope, just to a different destination.
abstract final class BackupService {
  /// Builds the same versioned JSON envelope both the local file and the
  /// cloud transport write.
  static Future<String> _buildEnvelopeJson() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    final envelope = {
      'app': AppInfo.name,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    return jsonEncode(envelope);
  }

  /// Restores every key found in an envelope produced by [_buildEnvelopeJson].
  /// Returns how many keys were restored. Existing keys not present in the
  /// backup are left untouched.
  static Future<int> _applyEnvelopeJson(String raw) async {
    final envelope = jsonDecode(raw);
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const FormatException('Not a valid PlayTorrio backup file.');
    }
    final data = (envelope['data'] as Map).cast<String, dynamic>();
    final prefs = await SharedPreferences.getInstance();

    var restored = 0;
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(
          entry.key,
          value.map((e) => e.toString()).toList(),
        );
      } else {
        continue;
      }
      restored++;
    }
    return restored;
  }

  /// The filename offered in the save dialog. Dated, because a backup you
  /// can only ever have one of is a backup you overwrite before you have
  /// checked the last one.
  static String suggestedFileName([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'playtorrio-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  /// Writes every SharedPreferences key to a file the user picks, and
  /// returns where it went. Null means they cancelled the dialog.
  ///
  /// This used to write to the app documents directory and hand back
  /// the path. On desktop that is merely inconvenient; on Android it is
  /// app-private storage (`/data/user/0/<package>/app_flutter`), which no
  /// file manager can open and no other app can read -- so the export
  /// reported a path the user could not reach and could not act on. A
  /// backup nobody can get at is not a backup.
  static Future<String?> exportToPickedFile() async {
    final json = await _buildEnvelopeJson();
    final bytes = Uint8List.fromList(utf8.encode(json));

    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Save your ${AppInfo.name} backup',
      fileName: suggestedFileName(),
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (destination == null) return null;

    // On Android and iOS the plugin writes `bytes` itself, through the
    // system document provider, and what comes back can be a content:// URI
    // that File() cannot open. On desktop it only returns the chosen path
    // and the write is ours to do.
    if (!_pluginWritesTheFile) {
      await File(destination).writeAsString(json);
    }
    return destination;
  }

  /// True on the platforms where file_picker's saveFile performs the write.
  static bool get _pluginWritesTheFile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Restores every key found in a backup file the user picks. Null means
  /// they cancelled.
  ///
  /// Picked rather than read from a fixed path for the same reason as the
  /// export: the file now lives wherever they chose to put it, which may be
  /// another device's Downloads folder entirely.
  static Future<int?> importFromPickedFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a ${AppInfo.name} backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;

    // `withData` gives bytes on every platform including Android, where
    // `path` may be absent or point at a cache copy.
    final data = picked.bytes;
    final String contents;
    if (data != null) {
      contents = utf8.decode(data);
    } else if (picked.path != null) {
      contents = await File(picked.path!).readAsString();
    } else {
      throw Exception('Could not read the selected file.');
    }

    return _applyEnvelopeJson(contents);
  }

  static Map<String, String> _webDavAuthHeader(CloudBackupConfig config) {
    final creds = base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $creds'};
  }

  /// Refuses a plaintext-HTTP WebDAV URL unless it points at the local
  /// machine/network -- the backup envelope carries every SharedPreferences
  /// key (including Trakt/Simkl tokens and the WebDAV password itself, via
  /// the Basic Auth header), so an `http://` URL to a real remote host would
  /// send all of it in cleartext. Loopback/private-LAN/.local addresses are
  /// exempt since that traffic never leaves the local network either way --
  /// the common case for a self-hosted server reached by its bare LAN IP.
  static void _assertSecureUri(Uri uri) {
    if (uri.scheme == 'https') return;
    if (isPrivateOrLoopbackHost(uri.host)) return;
    throw Exception(
      'Refusing to use an insecure "http://" URL for a non-local WebDAV host '
      '-- your backup (including saved Trakt/Simkl tokens and this password) '
      'would travel in cleartext. Use "https://", or a bare local network IP '
      '(e.g. http://192.168.1.50/...) if the server really is on your LAN.',
    );
  }

  /// Uploads the same envelope [export] writes locally to a WebDAV endpoint
  /// via a plain HTTP PUT with Basic Auth -- no vendor lock-in, no
  /// request-signing dependency.
  static Future<void> uploadToCloud(CloudBackupConfig config) async {
    final uri = Uri.parse(config.url);
    _assertSecureUri(uri);
    final response = await http.put(
      uri,
      headers: {..._webDavAuthHeader(config), 'Content-Type': 'application/json'},
      body: await _buildEnvelopeJson(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV upload failed (HTTP ${response.statusCode}).');
    }
  }

  /// Downloads and restores the envelope from a WebDAV endpoint.
  static Future<int> downloadFromCloud(CloudBackupConfig config) async {
    final uri = Uri.parse(config.url);
    _assertSecureUri(uri);
    final response = await http.get(uri, headers: _webDavAuthHeader(config));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('WebDAV download failed (HTTP ${response.statusCode}).');
    }
    return _applyEnvelopeJson(response.body);
  }
}
