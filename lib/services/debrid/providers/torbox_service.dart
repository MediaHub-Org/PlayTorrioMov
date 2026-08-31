import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debrid_file.dart';
import '../utils/debrid_media_matcher.dart';

class TorBoxService {
  static const String _key = 'torbox_api_key';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getKey() async {
    final prefs = await _prefs;
    return prefs.getString(_key);
  }

  Future<void> saveKey(String key) async {
    final prefs = await _prefs;
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, trimmed);
    }
  }

  Future<bool> hasKey() async {
    final key = await getKey();
    return key != null && key.isNotEmpty;
  }

  Future<Map<String, dynamic>?> verifyKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    try {
      final res = await http.get(
        Uri.parse('https://api.torbox.app/v1/api/user/me'),
        headers: {'Authorization': 'Bearer $trimmed'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<DebridFile>> resolveMagnet(
    String magnet, {
    int? fileIndex,
    String? filename,
    int? season,
    int? episode,
  }) async {
    final apiKey = await getKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('TorBox API Key is missing. Please configure it in Settings.');
    }

    final headers = {'Authorization': 'Bearer $apiKey'};

    // 1. Create Torrent
    final createRes = await http.post(
      Uri.parse('https://api.torbox.app/v1/api/torrents/createtorrent'),
      headers: headers,
      body: {'magnet': magnet},
    );

    final createData = json.decode(createRes.body);
    if (createData['success'] == false) {
      throw Exception('TorBox failed: ${createData['detail']}');
    }

    final torrentId = createData['data']['torrent_id'];

    // 2. Poll status
    Map<String, dynamic>? info;
    int attempts = 0;
    while (attempts < 25) {
      final infoRes = await http.get(
        Uri.parse('https://api.torbox.app/v1/api/torrents/mylist?id=$torrentId&bypass_cache=true'),
        headers: headers,
      );
      if (infoRes.statusCode == 200) {
        final mylist = json.decode(infoRes.body)['data'];
        info = mylist is Map ? mylist.cast<String, dynamic>() : null;
        if (info != null) {
          if (info['download_finished'] == true || info['download_state'] == 'cached') {
            break;
          }
          if (info['download_state'] == 'error') {
            throw Exception('TorBox Download failed with error status');
          }
        }
      }
      await Future.delayed(const Duration(seconds: 3));
      attempts++;
    }

    if (info == null) {
      throw Exception('TorBox failed to retrieve torrent info');
    }

    final List rawFiles = (info['files'] as List?) ?? const [];
    if (rawFiles.isEmpty) throw Exception('TorBox returned no files');

    // 3. Pick file
    final picked = DebridMediaMatcher.pickMediaFile<dynamic>(
      rawFiles,
      fileIndex: fileIndex,
      filename: filename,
      season: season,
      episode: episode,
      name: (f) => (f['name'] as String?) ?? '',
      size: (f) => (f['size'] as num?)?.toInt() ?? 0,
    );

    if (picked == null) {
      throw Exception('No suitable media file found in TorBox torrent');
    }

    final permalink =
        'https://api.torbox.app/v1/api/torrents/requestdl?token=$apiKey'
        '&torrent_id=$torrentId&file_id=${picked['id']}&redirect=true';

    return [
      DebridFile(
        filename: (picked['name'] as String?) ?? 'media',
        filesize: (picked['size'] as num?)?.toInt() ?? 0,
        downloadUrl: permalink,
      ),
    ];
  }
}
