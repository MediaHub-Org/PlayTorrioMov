import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VidNestAnimeResult {
  final String url;
  final String server;
  final String quality;
  final Map<String, String> headers;

  VidNestAnimeResult({
    required this.url,
    required this.server,
    required this.quality,
    required this.headers,
  });
}

/// Pure-Dart VidNest Stream Extractor for AnimeScraperService.
///
/// Ported 1-to-1 from Vyla VidNest provider.
/// Custom alphabet substitution deciphering for hianime/anime endpoints.
class VidNestExtractor {
  static final VidNestExtractor instance = VidNestExtractor._internal();
  VidNestExtractor._internal();

  static const _baseUrl = 'https://vidnest.fun';
  static const _apiBaseUrl = 'https://new.vidnest.fun';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _alphabet = 'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';
  static final Uint8List _revMap = () {
    final map = Uint8List(256);
    for (var i = 0; i < _alphabet.length; i++) {
      map[_alphabet.codeUnitAt(i)] = i;
    }
    return map;
  }();

  dynamic _decrypt(String payload) {
    try {
      final len = payload.length;
      final bytes = Uint8List(len);
      var j = 0;
      for (var i = 0; i < len; i += 4) {
        final c0 = i < len ? (_revMap[payload.codeUnitAt(i)]) : 64;
        final c1 = (i + 1) < len ? (_revMap[payload.codeUnitAt(i + 1)]) : 64;
        final c2 = (i + 2) < len ? (_revMap[payload.codeUnitAt(i + 2)]) : 64;
        final c3 = (i + 3) < len ? (_revMap[payload.codeUnitAt(i + 3)]) : 64;

        bytes[j++] = (c0 << 2) | (c1 >> 4);
        if (c2 != 64) bytes[j++] = ((c1 & 15) << 4) | (c2 >> 2);
        if (c3 != 64) bytes[j++] = ((c2 & 3) << 6) | c3;
      }
      final jsonStr = utf8.decode(bytes.sublist(0, j));
      return jsonDecode(jsonStr);
    } catch (_) {
      return null;
    }
  }

  Future<List<VidNestAnimeResult>> extract({
    required int anilistId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    final results = <VidNestAnimeResult>[];
    final client = http.Client();

    try {
      final catParam = category.toLowerCase() == 'dub' ? 'dub' : 'sub';
      final endpoint = '$_apiBaseUrl/hianime/anime/$anilistId/$episodeNumber/$catParam';

      final res = await client.get(
        Uri.parse(endpoint),
        headers: {
          'User-Agent': _ua,
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer': '$_baseUrl/',
          'Origin': _baseUrl,
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map) {
          final data = json['encrypted'] == true
              ? _decrypt(json['data']?.toString() ?? '')
              : json['data'];

          if (data is Map && data['sources'] is List && (data['sources'] as List).isNotEmpty) {
            final file = data['sources'][0]['file']?.toString();
            if (file != null && file.isNotEmpty) {
              const proxyHeaders = {
                'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:137.0) Gecko/20100101 Firefox/137.0',
                'accept': '*/*',
                'origin': 'https://megaplay.buzz',
                'referer': 'https://megaplay.buzz/',
              };

              final proxiedUrl = 'https://megacloud.animanga.fun/proxy?url=${Uri.encodeComponent(file)}&headers=${Uri.encodeComponent(jsonEncode(proxyHeaders))}';

              results.add(VidNestAnimeResult(
                url: proxiedUrl,
                server: 'VidNest (HiAnime)',
                quality: '1080p',
                headers: {
                  'User-Agent': _ua,
                  'Referer': '$_baseUrl/',
                  'Origin': _baseUrl,
                },
              ));
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[VidNestExtractor] error: $e');
    } finally {
      client.close();
    }

    return results;
  }
}
