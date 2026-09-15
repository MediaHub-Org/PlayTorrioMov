import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../scraper/user_agent.dart';

class LunaAnimeResult {
  final String url;
  final String server;
  final String quality;
  final String type;
  final Map<String, String> headers;

  LunaAnimeResult({
    required this.url,
    required this.server,
    required this.quality,
    required this.type,
    required this.headers,
  });
}

/// Pure-Dart Luna Stream Extractor for AnimeScraperService.
///
/// Ported 1-to-1 from Vyla Luna provider.
/// Resolves high-speed HLS streams directly from luna-stream.me using Next.js Server Actions.
class LunaExtractor {
  static final LunaExtractor instance = LunaExtractor._internal();
  LunaExtractor._internal();

  static const _actionFetchSources = 'afb0491c5516f9fff5fcb464d627638df76062f8';
  static const _watchUrl = 'https://luna-stream.me/anime/watch/21/gogoanime/1';
  static const _ua =
      kDefaultUA;

  static const _providers = [
    {'id': 'megaplay', 'name': 'Helios'},
    {'id': 'gogoanime', 'name': 'Quasar'},
    {'id': 'zoro', 'name': 'Zenith'},
    {'id': 'anibd', 'name': 'Nova'},
    {'id': 'pahe', 'name': 'Polaris'},
    {'id': 'animepahe', 'name': 'Vega'},
  ];

  /// The payload object out of a Next.js React Server Components stream.
  ///
  /// An RSC response is not JSON: it is newline-separated `<id>:<payload>`
  /// rows, and only the row keyed `1` carries what this extractor wants. The
  /// others are React's own bookkeeping and are not always valid JSON at all,
  /// so a row that will not parse is skipped rather than ending the search --
  /// it simply was not the one.
  @visibleForTesting
  static Map<String, dynamic>? parseRscResponse(String text) {
    for (final line in text.split('\n')) {
      if (line.startsWith('1:')) {
        try {
          final jsonStr = line.substring(2);
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map) return Map<String, dynamic>.from(parsed);
        } catch (_) {
          // Not every line prefixed 1: is the payload. A line that will not
          // parse is simply not the one.
        }
      }
    }
    return null;
  }

  /// Undoes a doubled origin in a URL the API sometimes returns.
  ///
  /// Luna occasionally concatenates its own base onto an already-absolute
  /// URL, producing a host that does not resolve. Left alone the stream just
  /// fails to load, with nothing to say why.
  @visibleForTesting
  static String cleanUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    return rawUrl.replaceFirst(
      'https://api.luna-stream.mehttps://api.luna-stream.me',
      'https://api.luna-stream.me',
    );
  }

  Future<List<LunaAnimeResult>> extract({
    required int anilistId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    final results = <LunaAnimeResult>[];
    final client = http.Client();

    try {
      final subtype = category.toLowerCase() == 'dub' ? 'dub' : 'sub';

      final futures = _providers.map((p) async {
        final pId = p['id']!;
        final pName = p['name']!;

        try {
          final res = await client.post(
            Uri.parse(_watchUrl),
            headers: {
              'User-Agent': _ua,
              'Next-Action': _actionFetchSources,
              'Content-Type': 'text/plain;charset=UTF-8',
              'Accept': 'text/x-component',
              'Referer': _watchUrl,
              'Origin': 'https://luna-stream.me',
            },
            body: jsonEncode([anilistId, pId, '$episodeNumber', episodeNumber, subtype, null]),
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode != 200) return <LunaAnimeResult>[];

          final parsed = parseRscResponse(res.body);
          if (parsed == null || parsed['sources'] is! List) return <LunaAnimeResult>[];

          final sources = parsed['sources'] as List;
          final list = <LunaAnimeResult>[];

          for (final s in sources) {
            if (s is! Map) continue;
            final rawUrl = s['url']?.toString();
            if (rawUrl == null || rawUrl.isEmpty) continue;

            final url = cleanUrl(rawUrl);
            final format = (s['type']?.toString() ?? '').toLowerCase();
            final isHls = format == 'hls' || format == 'm3u8' || url.contains('.m3u8') || url.contains('.txt');

            list.add(LunaAnimeResult(
              url: url,
              server: 'Luna ($pName)',
              quality: s['quality']?.toString() ?? '1080p',
              type: isHls ? 'hls' : 'mp4',
              headers: {
                'User-Agent': _ua,
                'Referer': 'https://luna-stream.me/',
              },
            ));
          }
          return list;
        } catch (_) {
          return <LunaAnimeResult>[];
        }
      });

      final settled = await Future.wait(futures);
      for (final list in settled) {
        results.addAll(list);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LunaExtractor] extraction error: $e');
    } finally {
      client.close();
    }

    return results;
  }
}
