import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_service.dart';

/// GitHub refused a gist request. [message] says which step and what to check.
class GistSyncException implements Exception {
  final String message;
  const GistSyncException(this.message);

  @override
  String toString() => message;
}

/// The profile's cloud copy, as one secret gist in the person's own account.
///
/// The gist is found by its description, so a new device needs only the token:
/// the gist id is remembered on the device after the first lookup. The token is
/// a fine-grained one whose only permission is Gists, so it cannot touch any
/// repository. The content is sealed with the backup passphrase before it
/// leaves the device, so GitHub only ever holds ciphertext. Every upload is a
/// revision of the gist, which keeps the earlier profiles one click away.
abstract final class GistSync {
  static const description = 'PlayTorrio profile (encrypted)';
  static const fileName = 'profile.enc';
  static const _idKey = 'profile_sync_gist_id';
  static const _api = 'https://api.github.com';
  static const _timeout = Duration(seconds: 20);

  /// Whether this build carries a token. Sync also needs a passphrase.
  static bool get isConfigured => EnvService.githubSyncToken.isNotEmpty;

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${EnvService.githubSyncToken}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'PlayTorrioMov',
      };

  /// The sealed cloud copy, or null when there is none yet.
  static Future<String?> download() async {
    final id = await _knownId() ?? await _findId();
    if (id == null) return null;

    final res = await http
        .get(Uri.parse('$_api/gists/$id'), headers: _headers)
        .timeout(_timeout);
    if (res.statusCode == 404) {
      // Deleted on GitHub. The next sync finds or creates one.
      await _forgetId();
      return null;
    }
    _check(res, 'read the profile gist');

    final gist = jsonDecode(res.body) as Map<String, dynamic>;
    final file = (gist['files'] as Map?)?[fileName] as Map?;
    if (file == null) return null;
    if (file['truncated'] == true) {
      // GitHub returns at most 1 MB of a file in the API; the rest is at raw_url.
      final raw = await http
          .get(Uri.parse(file['raw_url'] as String), headers: _headers)
          .timeout(_timeout);
      _check(raw, 'read the profile file');
      return raw.body;
    }
    return file['content'] as String?;
  }

  /// Replaces the cloud copy with [sealed], creating the gist on first use.
  static Future<void> upload(String sealed) async {
    final id = await _knownId() ?? await _findId();
    if (id == null) {
      final res = await http
          .post(
            Uri.parse('$_api/gists'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'description': description,
              'public': false,
              'files': {
                fileName: {'content': sealed},
              },
            }),
          )
          .timeout(_timeout);
      _check(res, 'create the profile gist');
      await _rememberId((jsonDecode(res.body) as Map)['id'] as String);
      return;
    }

    final res = await http
        .patch(
          Uri.parse('$_api/gists/$id'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'files': {
              fileName: {'content': sealed},
            },
          }),
        )
        .timeout(_timeout);
    if (res.statusCode == 404) {
      await _forgetId();
      throw const GistSyncException(
        'The profile gist was deleted on GitHub; the next sync creates it.',
      );
    }
    _check(res, 'update the profile gist');
  }

  /// The id of the first gist with [description] in [gists], which GitHub lists
  /// newest first. Null when there is none.
  static String? pickGistId(List<dynamic> gists) {
    for (final gist in gists) {
      if (gist is Map && gist['description'] == description) {
        return gist['id'] as String?;
      }
    }
    return null;
  }

  static Future<String?> _findId() async {
    // 100 gists per page, and a few pages is more than any personal account
    // needs to reach the profile gist.
    for (var page = 1; page <= 5; page++) {
      final res = await http
          .get(
            Uri.parse('$_api/gists?per_page=100&page=$page'),
            headers: _headers,
          )
          .timeout(_timeout);
      _check(res, 'list your gists');
      final gists = jsonDecode(res.body) as List<dynamic>;
      final id = pickGistId(gists);
      if (id != null) {
        await _rememberId(id);
        return id;
      }
      if (gists.length < 100) break;
    }
    return null;
  }

  static void _check(http.Response res, String step) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw GistSyncException(
        'GitHub refused the token (HTTP ${res.statusCode}) and could not '
        '$step. Check GITHUB_SYNC_TOKEN has the Gists permission.',
      );
    }
    throw GistSyncException(
      'GitHub answered HTTP ${res.statusCode} when asked to $step.',
    );
  }

  static Future<String?> _knownId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  static Future<void> _rememberId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, id);
  }

  static Future<void> _forgetId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
  }
}
