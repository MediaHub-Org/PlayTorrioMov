import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import 'tmdb_helper.dart';
import '../user_agent.dart';
import 'glendale_master_url.dart';

/// Pure-Dart Bcine Stream Scraper for PlayTorrioHTTP.
///
/// Ported 1-to-1 from Vyla Bcine provider.
/// Resolves direct cryptographic master playlists and multi-server streams.
class BcineScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  static const _ua =
      kDefaultUA;

  static const _servers = [
    {'id': 'NIGHT', 'endpoint': '/server/night', 'name': 'Night'},
    {'id': 'EMP', 'endpoint': '/server/emp', 'name': 'Empire'},
    {'id': 'MAIN', 'endpoint': '/server/vidsrc', 'name': 'VidSrc'},
  ];

  Future<String?> _fetchInternalToken(http.Client client) async {
    try {
      final res = await client.get(
        Uri.parse('https://1embed.cc/api/token'),
        headers: {
          'User-Agent': _ua,
          'Referer': 'https://1embed.cc/',
          'Accept': 'application/json, text/plain, */*',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['token'] != null) {
          return data['token'].toString();
        }
      }
    } catch (_) {
      // No token means this scraper contributes nothing; the others still run.
    }
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
        if (kDebugMode) debugPrint('[BcineScraper] Could not resolve TMDB ID for "$title"');
        return;
      }

      // 1. Direct Cryptographic HLS Master Stream
      final directHls =
          '${glendaleMasterUrl(tmdbId, season, episode)}?$glendaleVersionParam';
      final directHeaders = {
        'User-Agent': _ua,
        'Referer': 'https://bcine.ru/',
        'Origin': 'https://bcine.ru',
      };

      yield StreamSource(
        name: 'PlayTorrioHTTP',
        addonName: 'PlayTorrioHTTP',
        title: 'Bcine · Direct Master · 1080p',
        description: 'Bcine Direct Master HLS Stream',
        url: directHls,
        headers: directHeaders,
        behaviorHints: {
          'notWebReady': false,
          'proxyHeaders': {
            'request': directHeaders,
          },
        },
      );

      // 2. Multi-server streams
      final client = http.Client();
      try {
        final token = await _fetchInternalToken(client);
        if (token != null && token.isNotEmpty) {
          final query = isTv
              ? 'id=$tmdbId?type=tv&s=${season ?? 1}&e=${episode ?? 1}'
              : 'id=$tmdbId?type=movie';

          for (final srv in _servers) {
            try {
              final endpoint = srv['endpoint']!;
              final srvName = srv['name']!;

              final res = await client.get(
                Uri.parse('https://1embed.cc$endpoint?$query'),
                headers: {
                  'User-Agent': _ua,
                  'Referer': 'https://1embed.cc/',
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json, text/plain, */*',
                },
              ).timeout(const Duration(seconds: 6));

              if (res.statusCode == 200) {
                final data = jsonDecode(res.body);
                if (data is Map && data['url'] != null) {
                  final sUrl = data['url'].toString();
                  if (sUrl.contains('.m3u8')) {
                    final reqHeaders = {
                      'User-Agent': _ua,
                      'Referer': 'https://1embed.cc/',
                    };

                    yield StreamSource(
                      name: 'PlayTorrioHTTP',
                      addonName: 'PlayTorrioHTTP',
                      title: 'Bcine · $srvName · 1080p',
                      description: 'Bcine $srvName HLS Stream',
                      url: sUrl,
                      headers: reqHeaders,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': reqHeaders,
                        },
                      },
                    );
                  }
                }
              }
            } catch (_) {
              // This entry did not yield a stream. The rest of the list is
              // still walked.
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BcineScraper] scrapeStream error: $e');
    }
  }
}
