import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debrid_file.dart';
import '../utils/debrid_media_matcher.dart';

class PremiumizeService {
  static const String _key = 'premiumize_api_key';

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
        Uri.parse('https://www.premiumize.me/api/account/info?apikey=$trimmed'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          return data as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _walkPremiumizeFolder(
    String apiKey,
    String folderId,
    String prefix,
    List<Map<String, dynamic>> out,
  ) async {
    final res = await http.post(
      Uri.parse('https://www.premiumize.me/api/folder/list'),
      body: {'apikey': apiKey, 'id': folderId},
    );
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception('Premiumize folder/list: ${body['message']}');
    }
    final content = (body['content'] as List?) ?? const [];
    for (final raw in content) {
      if (raw is! Map) continue;
      final node = raw.cast<String, dynamic>();
      final name = (node['name'] as String?) ?? '';
      final path = prefix.isEmpty ? name : '$prefix/$name';
      if (node['type'] == 'folder' && node['id'] is String) {
        await _walkPremiumizeFolder(apiKey, node['id'] as String, path, out);
      } else {
        out.add({
          'path': path,
          'size': (node['size'] as num?)?.toInt() ?? 0,
          'link': (node['link'] as String?) ?? '',
        });
      }
    }
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
      throw Exception('Premiumize API key is missing. Please configure it in Settings.');
    }

    List<Map<String, dynamic>> files = [];

    // Direct download (cached)
    try {
      final dlRes = await http.post(
        Uri.parse('https://www.premiumize.me/api/transfer/directdl'),
        body: {'apikey': apiKey, 'src': magnet},
      );
      final dlBody = json.decode(dlRes.body) as Map<String, dynamic>;
      if (dlBody['status'] == 'success') {
        final content = (dlBody['content'] as List?) ?? const [];
        for (final raw in content) {
          if (raw is! Map) continue;
          final node = raw.cast<String, dynamic>();
          files.add({
            'path': (node['path'] as String?) ?? (node['name'] as String?) ?? '',
            'size': (node['size'] as num?)?.toInt() ?? 0,
            'link': (node['stream_link'] as String?)?.isNotEmpty == true
                ? node['stream_link'] as String
                : (node['link'] as String?) ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('[Premiumize] directdl error: $e');
    }

    if (files.isEmpty) {
      final createRes = await http.post(
        Uri.parse('https://www.premiumize.me/api/transfer/create'),
        body: {'apikey': apiKey, 'src': magnet},
      );
      final createBody = json.decode(createRes.body) as Map<String, dynamic>;
      if (createBody['status'] != 'success') {
        throw Exception('Premiumize create: ${createBody['message']}');
      }
      final transferId = createBody['id'] as String?;
      if (transferId == null) {
        throw Exception('Premiumize: no transfer id returned');
      }

      String? folderId;
      int attempts = 0;
      while (attempts < 40) {
        await Future.delayed(const Duration(seconds: 3));
        final listRes = await http.post(
          Uri.parse('https://www.premiumize.me/api/transfer/list'),
          body: {'apikey': apiKey},
        );
        final listBody = json.decode(listRes.body) as Map<String, dynamic>;
        if (listBody['status'] != 'success') {
          throw Exception('Premiumize list: ${listBody['message']}');
        }
        final transfers = (listBody['transfers'] as List?) ?? const [];
        Map<String, dynamic>? mine;
        for (final raw in transfers) {
          if (raw is Map && raw['id'] == transferId) {
            mine = raw.cast<String, dynamic>();
            break;
          }
        }
        if (mine == null) {
          throw Exception('Premiumize: transfer disappeared');
        }
        final status = mine['status'] as String?;
        if (status == 'finished' || status == 'seeding') {
          folderId = mine['folder_id'] as String?;
          break;
        }
        if (status == 'error' || status == 'deleted' || status == 'banned') {
          throw Exception('Premiumize transfer failed: $status (${mine['message']})');
        }
        attempts++;
      }
      if (folderId == null) {
        throw Exception('Premiumize: transfer did not finish in time');
      }

      await _walkPremiumizeFolder(apiKey, folderId, '', files);
    }

    if (files.isEmpty) {
      throw Exception('Premiumize: no files found in torrent');
    }

    final picked = DebridMediaMatcher.pickMediaFile<Map<String, dynamic>>(
      files,
      fileIndex: fileIndex,
      filename: filename,
      season: season,
      episode: episode,
      name: (f) => (f['path'] as String?) ?? '',
      size: (f) => (f['size'] as num?)?.toInt() ?? 0,
    );
    if (picked == null) {
      throw Exception('Premiumize: no suitable media file found in torrent');
    }
    final pickedPath = (picked['path'] as String?) ?? '';
    final pickedLink = (picked['link'] as String?) ?? '';
    if (pickedLink.isEmpty) {
      throw Exception('Premiumize: picked file has no download link');
    }

    return [
      DebridFile(
        filename: pickedPath.split('/').last,
        filesize: (picked['size'] as num?)?.toInt() ?? 0,
        downloadUrl: pickedLink,
      ),
    ];
  }
}
