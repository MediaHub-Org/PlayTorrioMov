import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import 'tmdb_helper.dart';

/// Pure-Dart VidVault Stream Scraper for PlayTorrioHTTP.
///
/// Ported 1-to-1 from Vyla VidVault provider.
/// Resolves direct high-speed MP4 & MKV files from vidvault.ru.
class VidVaultScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  static const _baseUrl = 'https://vidvault.ru';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _headers = {
    'Referer': '$_baseUrl/',
    'Origin': _baseUrl,
    'User-Agent': _ua,
  };

  Future<String?> _getToken(http.Client client) async {
    try {
      final res = await client.get(
        Uri.parse('$_baseUrl/api/get-token'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['t'] != null) {
          return data['t'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    final isTv = (type == 'tv' || type == 'series');
    final mediaType = isTv ? 'tv' : 'movie';

    try {
      final tmdbId = await TmdbHelper.resolveTmdbId(
        imdbId: imdbId,
        title: title,
        type: mediaType,
        year: year,
      );

      if (tmdbId == null) {
        if (kDebugMode) debugPrint('[VidVaultScraper] Could not resolve TMDB ID for "$title"');
        return;
      }

      final client = http.Client();
      try {
        final token = await _getToken(client);
        if (token == null || token.isEmpty) return;

        final payload = <String, dynamic>{
          'type': mediaType,
          'tmdbId': tmdbId.toString(),
          if (isTv) 'season': (season ?? 1).toString(),
          if (isTv) 'episode': (episode ?? 1).toString(),
        };

        final res = await client.post(
          Uri.parse('$_baseUrl/api/download-proxy'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
            'x-request-token': token,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) return;
        final data = jsonDecode(res.body);
        if (data is! Map) return;

        final mp4 = data['mp4Data'];
        if (mp4 is Map) {
          final downloads = mp4['downloadInfo']?['data']?['downloads'];
          if (downloads is List) {
            for (final d in downloads) {
              if (d is! Map) continue;
              final dUrl = d['url']?.toString();
              if (dUrl == null || dUrl.isEmpty) continue;

              final resLabel = d['resolution']?.toString() ?? '1080';

              yield StreamSource(
                name: 'PlayTorrioHTTP',
                addonName: 'PlayTorrioHTTP',
                title: 'VidVault · MP4 · ${resLabel}p',
                description: 'VidVault Direct MP4',
                url: dUrl,
                headers: _headers,
                behaviorHints: {
                  'notWebReady': false,
                  'proxyHeaders': {
                    'request': _headers,
                  },
                },
              );
            }
          }
        }

        final mkvFiles = data['mkvData']?['files'];
        if (mkvFiles is List) {
          for (final f in mkvFiles) {
            if (f is! Map) continue;
            final fUrl = f['url']?.toString();
            if (fUrl == null || fUrl.isEmpty) continue;

            final size = f['size']?.toString() ?? '';
            final label = size.isNotEmpty ? 'MKV · $size' : 'MKV';

            yield StreamSource(
              name: 'PlayTorrioHTTP',
              addonName: 'PlayTorrioHTTP',
              title: 'VidVault · $label',
              description: 'VidVault Direct File',
              url: fUrl,
              headers: _headers,
              behaviorHints: {
                'notWebReady': false,
                'proxyHeaders': {
                  'request': _headers,
                },
              },
            );
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[VidVaultScraper] error: $e');
    }
  }
}
