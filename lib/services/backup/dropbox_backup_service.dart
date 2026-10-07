import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/pkce.dart';
import '../config/env_service.dart';
import '../storage/secure_value_store.dart';
import 'backup_service.dart';

/// Dropbox backup, as a PKCE "public client" (installed app) -- the Dropbox
/// app itself needs only an App Key, never a secret, so the key in
/// `DROPBOX_APP_KEY` (see `EnvService.dropboxAppKey`) is the only credential
/// this build is missing until someone registers one. See
/// `docs/SYNC_AND_BACKUP.md` for why that is a deliberate "bring your own
/// app" choice, same as Trakt, rather than a client secret shipped in the
/// app (which a PKCE public client has no secret to ship in the first
/// place -- Dropbox's own docs are explicit that a secret belongs to a
/// confidential client this app is not).
///
/// No redirect URI: Dropbox's authorize page shows the code on screen for
/// the user to copy back in, the same shape as Trakt's device code and
/// Simkl's PIN, rather than needing a platform-specific deep link this app
/// has none of yet.
abstract final class DropboxBackupService {
  static const _accessTokenKey = 'dropbox_access_token';
  static const _refreshTokenKey = 'dropbox_refresh_token';
  static const _expiryKey = 'dropbox_token_expiry_ms';
  static const _accountNameKey = 'dropbox_account_name';
  static const _verifierKey = 'dropbox_pending_code_verifier';

  static const _authorizeUrl = 'https://www.dropbox.com/oauth2/authorize';
  static const _tokenUrl = 'https://api.dropboxapi.com/oauth2/token';
  static const _uploadUrl = 'https://content.dropboxapi.com/2/files/upload';
  static const _downloadUrl =
      'https://content.dropboxapi.com/2/files/download';
  static const _accountInfoUrl =
      'https://api.dropboxapi.com/2/users/get_current_account';

  /// Fixed: one backup file, overwritten in place, in the app's own folder
  /// (Dropbox scopes a PKCE app to its own `/Apps/<app name>` folder unless
  /// it asks for full Dropbox access, which this never does).
  static const _backupPath = '/playtorrio-backup.json';

  /// Exposed so a test can pin the file name: a local export, a WebDAV
  /// upload and this all write the same [BackupService] envelope under it,
  /// and a rename here would silently orphan every backup made before it.
  @visibleForTesting
  static const backupPath = _backupPath;

  static bool get isConfigured => EnvService.dropboxAppKey.isNotEmpty;

  // ── PKCE ──────────────────────────────────────────────────────────────
  // The verifier math lives in `lib/utils/pkce.dart`, its own file rather
  // than inlined here -- see its doc comment for why.

  /// Starts a connection: generates and remembers a PKCE verifier, and
  /// returns the URL to open in a browser. The verifier is stashed in
  /// SharedPreferences (not secret -- it is useless without the one-time
  /// code it is paired to, which the user still has to paste back in) so it
  /// survives the app losing focus while the browser is open.
  static Future<String> beginAuthorization() async {
    final verifier = Pkce.newVerifier();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verifierKey, verifier);

    final uri = Uri.parse(_authorizeUrl).replace(queryParameters: {
      'client_id': EnvService.dropboxAppKey,
      'response_type': 'code',
      'code_challenge': Pkce.challengeFor(verifier),
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
    });
    return uri.toString();
  }

  /// Exchanges the code Dropbox showed the user for tokens, completing
  /// [beginAuthorization]. Throws with a message fit to show the user on
  /// failure -- a pasted code is the one step in this flow a person can get
  /// wrong (a stray space, an expired code), unlike the rest which is all
  /// this service's own doing.
  static Future<void> connectWithCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw Exception('Paste the code Dropbox showed you first.');
    }
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(_verifierKey);
    if (verifier == null) {
      throw Exception(
        'That connection attempt expired -- tap Connect again.',
      );
    }

    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': trimmed,
        'grant_type': 'authorization_code',
        'client_id': EnvService.dropboxAppKey,
        'code_verifier': verifier,
      },
    ).timeout(const Duration(seconds: 20));

    await prefs.remove(_verifierKey);

    if (response.statusCode != 200) {
      debugPrint('[Dropbox] Token exchange failed (${response.statusCode}): ${response.body}');
      throw Exception(
        'Dropbox did not accept that code. It may have expired -- try '
        'Connect again and paste it right away.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeTokens(data);
    await _refreshAccountName();
  }

  static Future<void> _storeTokens(Map<String, dynamic> data) async {
    await SecureValueStore.write(_accessTokenKey, data['access_token'] as String);
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken != null) {
      await SecureValueStore.write(_refreshTokenKey, refreshToken);
    }
    final expiresIn = data['expires_in'] as int?;
    final prefs = await SharedPreferences.getInstance();
    if (expiresIn != null) {
      final expiryMs = DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch;
      await prefs.setInt(_expiryKey, expiryMs);
    } else {
      await prefs.remove(_expiryKey);
    }
  }

  /// A valid access token, refreshing first if the stored one has expired
  /// (or is close enough to that a request using it would likely race the
  /// expiry). Null means not connected, or the refresh token itself was
  /// rejected -- in which case [logout] has already run, since a refresh
  /// token Dropbox no longer honors cannot become valid by leaving it in
  /// place.
  static Future<String?> _validAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_expiryKey);
    final needsRefresh = expiryMs == null ||
        DateTime.now()
            .add(const Duration(minutes: 2))
            .millisecondsSinceEpoch >=
            expiryMs;

    if (!needsRefresh) {
      final token = await SecureValueStore.read(_accessTokenKey);
      if (token != null && token.isNotEmpty) return token;
    }

    final refreshToken = await SecureValueStore.read(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': EnvService.dropboxAppKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[Dropbox] Refresh failed (${response.statusCode}), signing out');
        await logout();
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeTokens(data);
      return data['access_token'] as String;
    } catch (e) {
      debugPrint('[Dropbox] Refresh error: $e');
      return null;
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await SecureValueStore.read(_refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// The connected account's display name, cached locally so the settings
  /// page does not re-ask Dropbox on every build. Refreshed on connect; a
  /// stale cached name after a Dropbox-side rename is a cosmetic gap, not a
  /// wrong-data one.
  static Future<String?> getAccountName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountNameKey);
  }

  static Future<void> _refreshAccountName() async {
    try {
      final token = await _validAccessToken();
      if (token == null) return;
      final response = await http.post(
        Uri.parse(_accountInfoUrl),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = (data['name'] as Map?)?['display_name'] as String?;
      if (name == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountNameKey, name);
    } catch (e) {
      // The connection itself already succeeded; a display name is a nicety
      // on top of it, not something worth failing Connect over.
      debugPrint('[Dropbox] Could not fetch account name: $e');
    }
  }

  static Future<void> logout() async {
    await SecureValueStore.delete(_accessTokenKey);
    await SecureValueStore.delete(_refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expiryKey);
    await prefs.remove(_accountNameKey);
  }

  /// Uploads the same envelope the local export and WebDAV paths write, to
  /// the fixed path in this app's own Dropbox app folder.
  static Future<void> upload() async {
    final token = await _validAccessToken();
    if (token == null) {
      throw Exception('Not connected to Dropbox.');
    }
    final json = await BackupService.buildEnvelopeJson();
    final response = await http.post(
      Uri.parse(_uploadUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Dropbox-API-Arg': jsonEncode({
          'path': _backupPath,
          'mode': 'overwrite',
          'mute': true,
        }),
        'Content-Type': 'application/octet-stream',
      },
      body: utf8.encode(json),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint('[Dropbox] Upload failed (${response.statusCode}): ${response.body}');
      throw Exception('Dropbox upload failed (HTTP ${response.statusCode}).');
    }
  }

  /// Downloads and restores the envelope from Dropbox. Returns how many keys
  /// were restored.
  static Future<int> download() async {
    final token = await _validAccessToken();
    if (token == null) {
      throw Exception('Not connected to Dropbox.');
    }
    final response = await http.post(
      Uri.parse(_downloadUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Dropbox-API-Arg': jsonEncode({'path': _backupPath}),
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 409) {
      throw Exception(
        'No backup found in Dropbox yet -- back up from this app at least '
        'once before restoring from it.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint('[Dropbox] Download failed (${response.statusCode}): ${response.body}');
      throw Exception('Dropbox download failed (HTTP ${response.statusCode}).');
    }
    return BackupService.applyEnvelopeJson(response.body);
  }
}
