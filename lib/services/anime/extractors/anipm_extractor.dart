import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AniPMAnimeResult {
  final String url;
  final String server;
  final String quality;
  final Map<String, String> headers;

  AniPMAnimeResult({
    required this.url,
    required this.server,
    required this.quality,
    required this.headers,
  });
}

/// Pure-Dart AniPM Stream Extractor for AnimeScraperService.
///
/// Ported 1-to-1 from Vyla AniPM provider.
/// Resolves HLS and direct file streams from ani.pm.
class AniPMExtractor {
  static final AniPMExtractor instance = AniPMExtractor._internal();
  AniPMExtractor._internal();

  static const _baseUrl = 'https://ani.pm';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  Future<List<AniPMAnimeResult>> extract({
    required int anilistId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
    String? title,
  }) async {
    final results = <AniPMAnimeResult>[];
    final client = http.Client();

    try {
      final queryParams = {
        'ep': episodeNumber.toString(),
        'anilistId': anilistId.toString(),
        if (title != null && title.isNotEmpty) 'title': title,
      };

      final uri = Uri.parse('$_baseUrl/api/anime/src/servers').replace(queryParameters: queryParams);

      final res = await client.get(
        uri,
        headers: {
          'User-Agent': _ua,
          'Referer': '$_baseUrl/',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final targetAud = category.toLowerCase() == 'dub' ? 'dub' : 'sub';
          final list = data[targetAud];

          if (list is List) {
            for (final srv in list) {
              if (srv is! Map) continue;
              final rawUrl = srv['url']?.toString();
              if (rawUrl == null || rawUrl.isEmpty) continue;

              final streamUrl = rawUrl.startsWith('/') ? '$_baseUrl$rawUrl' : rawUrl;
              final provider = srv['provider']?.toString() ?? 'AniPM';

              results.add(AniPMAnimeResult(
                url: streamUrl,
                server: 'AniPM ($provider)',
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
      if (kDebugMode) debugPrint('[AniPMExtractor] error: $e');
    } finally {
      client.close();
    }

    return results;
  }
}
