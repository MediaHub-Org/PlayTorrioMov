import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _providers = [
    {'id': 'megaplay', 'name': 'Helios'},
    {'id': 'gogoanime', 'name': 'Quasar'},
    {'id': 'zoro', 'name': 'Zenith'},
    {'id': 'anibd', 'name': 'Nova'},
    {'id': 'pahe', 'name': 'Polaris'},
    {'id': 'animepahe', 'name': 'Vega'},
  ];

  Map<String, dynamic>? _parseRscResponse(String text) {
    for (final line in text.split('\n')) {
      if (line.startsWith('1:')) {
        try {
          final jsonStr = line.substring(2);
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map) return Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }
    }
    return null;
  }

  String _cleanUrl(String rawUrl) {
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

          final parsed = _parseRscResponse(res.body);
          if (parsed == null || parsed['sources'] is! List) return <LunaAnimeResult>[];

          final sources = parsed['sources'] as List;
          final list = <LunaAnimeResult>[];

          for (final s in sources) {
            if (s is! Map) continue;
            final rawUrl = s['url']?.toString();
            if (rawUrl == null || rawUrl.isEmpty) continue;

            final url = _cleanUrl(rawUrl);
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
