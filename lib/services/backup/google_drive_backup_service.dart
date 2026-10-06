import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/pkce.dart';
import '../config/env_service.dart';
import '../storage/secure_value_store.dart';
import 'backup_service.dart';

/// Google Drive backup, as an installed-app OAuth flow against a "Desktop"
/// client -- the one client type whose loopback redirect URIs
/// (`http://127.0.0.1:<any-port>`) need no pre-registration, so any free
/// Google Cloud project yields a client ID with no redirect URI to get
/// right, on any machine this app runs on.
///
/// There is deliberately no "paste the code" step the way Dropbox has one:
/// Google retired its manual copy-paste (`oob`) flow, so the browser comes
/// back to a tiny web server this service holds open on loopback while the
/// user approves access, and the server hands the code straight to the
/// token exchange. The server only ever listens on 127.0.0.1, serves one
/// canned page, and closes the moment the code (or an error, a cancel, or
/// a five-minute timeout) arrives.
///
/// Scope is `drive.file` on purpose: the app sees only files it created
/// itself, never the user's whole Drive -- the narrow scope Google's own
/// docs point installed apps at, and the one that keeps this out of its
/// stricter verification review. The backup is the same JSON envelope the
/// local export, WebDAV and Dropbox paths write, under the same fixed name.
abstract final class GoogleDriveBackupService {
  static const _accessTokenKey = 'google_drive_access_token';
  static const _refreshTokenKey = 'google_drive_refresh_token';
  static const _expiryKey = 'google_drive_token_expiry_ms';
  static const _accountNameKey = 'google_drive_account_name';

  static const _authorizeUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _aboutUrl =
      'https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress)';

  static const _scope = 'https://www.googleapis.com/auth/drive.file';

  /// Fixed: one backup file, found by name and overwritten in place.
  static const _backupName = 'playtorrio-backup.json';

  static bool get isConfigured => EnvService.googleDriveClientId.isNotEmpty;

  // The attempt currently holding the loopback server open, if any. Kept in
  // memory rather than SharedPreferences on purpose: the server dies with
  // the process, so a verifier outliving it (the way Dropbox's pasted-code
  // verifier must) would only ever fail the exchange it was saved for.
  static HttpServer? _server;
  static String? _verifier;
  static String? _redirectUri;

  // ── Authorization ─────────────────────────────────────────────────────

  /// The browser URL for these credentials -- pure, so the shape the user
  /// is sent to (loopback redirect, offline access, PKCE challenge) is
  /// testable without binding a port or opening a browser.
  @visibleForTesting
  static String authorizeUrl({
    required String clientId,
    required String redirectUri,
    required String challenge,
  }) {
    final uri = Uri.parse(_authorizeUrl).replace(queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scope,
      // Offline + consent every time: consent re-issues a refresh token on
      // each connect, so reconnecting after a revoke always heals instead
      // of handing back an access token with nothing to refresh it.
      'access_type': 'offline',
      'prompt': 'consent',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });
    return uri.toString();
  }

  /// Opens a connection attempt: binds the loopback server and returns the
  /// URL to open in a browser. A second call replaces the first -- the old
  /// tab's code would fail against the new verifier, and the exchange error
  /// below already tells the user to try Connect again in exactly that case.
  static Future<String> beginAuthorization() async {
    await cancelAuthorization();
    final verifier = Pkce.newVerifier();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _verifier = verifier;
    _redirectUri = 'http://127.0.0.1:${server.port}';
    return authorizeUrl(
      clientId: EnvService.googleDriveClientId,
      redirectUri: _redirectUri!,
      challenge: Pkce.challengeFor(verifier),
    );
  }

  /// Waits for the browser to come back to the loopback server, then
  /// exchanges the code -- the single call the settings card makes after
  /// launching the URL from [beginAuthorization]. Throws with a message fit
  /// to show the user; never leaves the server open behind it.
  static Future<void> waitForAndConnect({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = _server;
    if (server == null) {
      throw Exception('That connection attempt expired -- tap Connect again.');
    }
    try {
      final request = await server
          .firstWhere(
            (r) =>
                r.uri.queryParameters.containsKey('code') ||
                r.uri.queryParameters.containsKey('error'),
          )
          // A bare TimeoutException would read as a crash report; the
          // user only needs to know the browser never came back.
          .timeout(
            timeout,
            onTimeout: () => throw Exception(
              'Google never answered -- approve the access in the browser, '
              'or tap Connect again.',
            ),
          );
      final params = request.uri.queryParameters;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_connectedPage);
      await request.response.close();

      final error = params['error'];
      if (error != null) {
        throw Exception(
          'Google did not approve that connection ($error) -- tap Connect '
          'again and approve access in the browser.',
        );
      }
      await _exchangeCode(params['code']!);
      await _refreshAccountName();
    } finally {
      await cancelAuthorization();
    }
  }

  /// Closes a pending attempt, if any -- the Cancel button next to the
  /// "waiting for the browser" state. Idempotent: canceling twice, or with
  /// nothing pending, is not an error.
  static Future<void> cancelAuthorization() async {
    _verifier = null;
    _redirectUri = null;
    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (e) {
        debugPrint('[GoogleDrive] Error closing loopback server: $e');
      }
    }
  }

  static const _connectedPage =
      '<!doctype html><html><body style="font-family:sans-serif;'
      'text-align:center;padding-top:4em">'
      '<h2>Connected -- you can close this tab.</h2>'
      '</body></html>';

  static Future<void> _exchangeCode(String code) async {
    final verifier = _verifier;
    final redirectUri = _redirectUri;
    if (verifier == null || redirectUri == null) {
      throw Exception('That connection attempt expired -- tap Connect again.');
    }
    final body = <String, String>{
      'code': code,
      'client_id': EnvService.googleDriveClientId,
      'client_secret': EnvService.googleDriveClientSecret,
      'code_verifier': verifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    };
    // An installed app has nowhere safe to keep a secret, so an empty one
    // is omitted rather than sent: Google's Desktop clients accept PKCE in
    // its place, and an empty `client_secret` param reads as a wrong secret
    // rather than no secret.
    if (body['client_secret']!.isEmpty) body.remove('client_secret');

    final response = await http
        .post(
          Uri.parse(_tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      debugPrint('[GoogleDrive] Token exchange failed (${response.statusCode}): ${response.body}');
      throw Exception(
        'Google did not accept that connection. It may have expired -- try '
        'Connect again.',
      );
    }
    await _storeTokens(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> _storeTokens(Map<String, dynamic> data) async {
    await SecureValueStore.write(
      _accessTokenKey,
      data['access_token'] as String,
    );
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

  /// A valid access token, refreshing first when the stored one is expired
  /// or close enough that a request would likely race the expiry. Null
  /// means not connected, or the refresh token itself was rejected -- in
  /// which case [logout] has already run, since a refresh token Google no
  /// longer honors cannot become valid by leaving it in place.
  static Future<String?> _validAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_expiryKey);
    final needsRefresh =
        expiryMs == null ||
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
      final body = <String, String>{
        'refresh_token': refreshToken,
        'client_id': EnvService.googleDriveClientId,
        'client_secret': EnvService.googleDriveClientSecret,
        'grant_type': 'refresh_token',
      };
      if (body['client_secret']!.isEmpty) body.remove('client_secret');
      final response = await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[GoogleDrive] Refresh failed (${response.statusCode}), signing out');
        await logout();
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storeTokens(data);
      return data['access_token'] as String;
    } catch (e) {
      debugPrint('[GoogleDrive] Refresh error: $e');
      return null;
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await SecureValueStore.read(_refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// The connected account's display name or address, cached locally so the
  /// settings page does not re-ask Google on every build.
  static Future<String?> getAccountName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountNameKey);
  }

  static Future<void> _refreshAccountName() async {
    try {
      final token = await _validAccessToken();
      if (token == null) return;
      final response = await http
          .get(
            Uri.parse(_aboutUrl),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final user =
          (jsonDecode(response.body) as Map<String, dynamic>)['user'] as Map?;
      final name =
          user?['displayName'] as String? ?? user?['emailAddress'] as String?;
      if (name == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountNameKey, name);
    } catch (e) {
      // The connection itself already succeeded; a display name is a nicety
      // on top of it, not something worth failing Connect over.
      debugPrint('[GoogleDrive] Could not fetch account name: $e');
    }
  }

  static Future<void> logout() async {
    await cancelAuthorization();
    await SecureValueStore.delete(_accessTokenKey);
    await SecureValueStore.delete(_refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expiryKey);
    await prefs.remove(_accountNameKey);
  }

  // ── Backup file ─────────────────────────────────────────────────────

  /// The backup file's Drive id from a `files.list` response, or null when
  /// there is none -- pure, so "which file gets overwritten" is testable
  /// without a network. Defensive about the shape: an API that answers
  /// unexpectedly means "no file found" (create it), never a crash.
  @visibleForTesting
  static String? findBackupFileId(Object? json) {
    // `as` casts throw on the wrong type; this answers "no file found"
    // (create it) for anything that is not the expected shape instead.
    if (json is! Map) return null;
    final files = json['files'];
    if (files is! List || files.isEmpty) return null;
    final first = files.first;
    if (first is! Map) return null;
    final id = first['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  static Future<String?> _backupFileId(String token) async {
    final response = await http
        .get(
          Uri.parse(_filesUrl).replace(queryParameters: {
            'q': "name = '$_backupName' and trashed = false",
            'spaces': 'drive',
            'fields': 'files(id)',
            'pageSize': '1',
          }),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      debugPrint('[GoogleDrive] File lookup failed (${response.statusCode}): ${response.body}');
      throw Exception(
        'Google Drive lookup failed (HTTP ${response.statusCode}).',
      );
    }
    return findBackupFileId(jsonDecode(response.body));
  }

  /// A `multipart/related` body: the file metadata, then the envelope
  /// itself. Built by hand rather than with a multipart helper so the exact
  /// bytes (boundary placement, part headers, UTF-8 envelope) have one
  /// place to be tested.
  @visibleForTesting
  static Uint8List buildUploadMultipart({
    required String envelopeJson,
    required String boundary,
  }) {
    final out = <int>[];
    void write(String s) => out.addAll(utf8.encode(s));
    write('--$boundary\r\n');
    write('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    write('{"name": "$_backupName"}\r\n');
    write('--$boundary\r\n');
    write('Content-Type: application/json\r\n\r\n');
    out.addAll(utf8.encode(envelopeJson));
    write('\r\n--$boundary--\r\n');
    return Uint8List.fromList(out);
  }

  static String _newBoundary() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return 'playtorrio-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  /// Uploads the same envelope every other transport writes, creating the
  /// file on first backup and overwriting it after.
  static Future<void> upload() async {
    final token = await _validAccessToken();
    if (token == null) {
      throw Exception('Not connected to Google Drive.');
    }
    final envelope = await BackupService.buildEnvelopeJson();
    final fileId = await _backupFileId(token);
    final boundary = _newBoundary();
    final Uri url = fileId == null
        ? Uri.parse(_uploadUrl).replace(queryParameters: {
            'uploadType': 'multipart',
          })
        : Uri.parse('$_uploadUrl/$fileId').replace(queryParameters: {
            'uploadType': 'multipart',
          });
    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: buildUploadMultipart(
            envelopeJson: envelope,
            boundary: boundary,
          ),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint('[GoogleDrive] Upload failed (${response.statusCode}): ${response.body}');
      throw Exception('Google Drive upload failed (HTTP ${response.statusCode}).');
    }
  }

  /// Downloads and restores the envelope from Drive. Returns how many keys
  /// were restored.
  static Future<int> download() async {
    final token = await _validAccessToken();
    if (token == null) {
      throw Exception('Not connected to Google Drive.');
    }
    final fileId = await _backupFileId(token);
    if (fileId == null) {
      throw Exception(
        'No backup found in Google Drive yet -- back up from this app at '
        'least once before restoring from it.',
      );
    }
    final response = await http
        .get(
          Uri.parse('$_filesUrl/$fileId').replace(queryParameters: {
            'alt': 'media',
          }),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint('[GoogleDrive] Download failed (${response.statusCode}): ${response.body}');
      throw Exception(
        'Google Drive download failed (HTTP ${response.statusCode}).',
      );
    }
    return BackupService.applyEnvelopeJson(response.body);
  }
}
