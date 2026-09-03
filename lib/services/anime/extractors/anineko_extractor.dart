import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AniNekoAnimeResult {
  final String url;
  final String server;
  final String quality;
  final String category; // 'sub' or 'dub'
  final Map<String, String> headers;

  AniNekoAnimeResult({
    required this.url,
    required this.server,
    required this.quality,
    required this.category,
    required this.headers,
  });
}

/// Pure-Dart AniNeko Stream Extractor for AnimeScraperService.
///
/// Ported 1-to-1 from Vyla AniNeko provider.
/// Resolves direct HLS streams from anineko.to.
class AniNekoExtractor {
  static final AniNekoExtractor instance = AniNekoExtractor._internal();
  AniNekoExtractor._internal();

  static const _baseUrl = 'https://anineko.to';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  String _cleanTitle(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _decodeEntities(String str) {
    return str
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<List<Map<String, String>>> _search(http.Client client, String query) async {
    final results = <Map<String, String>>[];
    try {
      final res = await client.get(
        Uri.parse('$_baseUrl/browser?keyword=${Uri.encodeComponent(query)}'),
        headers: {'User-Agent': _ua},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final html = res.body;

        final linkMatches = RegExp(r'''href=["']/watch/([^"']+)["']''', caseSensitive: false)
            .allMatches(html);

        for (final match in linkMatches) {
          final slug = match.group(1);
          if (slug != null && !results.any((r) => r['slug'] == slug)) {
            final linkIdx = html.indexOf(match.group(0)!);
            final titleStart = html.lastIndexOf('>', linkIdx);
            final titleEnd = html.indexOf('<', linkIdx);
            if (titleStart != -1 && titleEnd != -1 && titleEnd > linkIdx) {
              final text = html.substring(titleStart + 1, (titleEnd).clamp(0, html.length)).trim();
              if (text.length > 2 && text.length < 100) {
                results.add({'slug': slug, 'text': text});
              }
            } else {
              results.add({'slug': slug, 'text': slug});
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<String?> _extractHls(http.Client client, String embedUrl) async {
    try {
      final res = await client.get(
        Uri.parse(embedUrl),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final html = res.body;
        final m = RegExp(r'''const\s+src\s*=\s*["'](https?://[^"']+\.m3u8[^"']*)["']''', caseSensitive: false).firstMatch(html) ??
            RegExp(r'''file\s*:\s*["'](https?://[^"']+\.m3u8[^"']*)["']''', caseSensitive: false).firstMatch(html) ??
            RegExp(r'''["'](https?://[^"']+/master\.m3u8[^"']*)["']''', caseSensitive: false).firstMatch(html) ??
            RegExp(r'''["'](https?://[^"']+\.m3u8[^"']*)["']''', caseSensitive: false).firstMatch(html);

        if (m != null && m.group(1) != null) {
          return _decodeEntities(m.group(1)!);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<AniNekoAnimeResult>> extract({
    required List<String> titleCandidates,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    final results = <AniNekoAnimeResult>[];
    final client = http.Client();

    try {
      String? seriesSlug;

      // 1. Direct slug probe
      for (final title in titleCandidates) {
        final potentialSlug = title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        if (potentialSlug.isEmpty) continue;

        try {
          final checkRes = await client.get(
            Uri.parse('$_baseUrl/watch/$potentialSlug/ep-$episodeNumber'),
            headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/watch/$potentialSlug'},
          ).timeout(const Duration(seconds: 4));

          if (checkRes.statusCode == 200 && checkRes.body.contains('nv-watch-page')) {
            seriesSlug = potentialSlug;
            break;
          }
        } catch (_) {}
      }

      // 2. Search fallback
      if (seriesSlug == null) {
        for (final title in titleCandidates) {
          final searchList = await _search(client, title);
          if (searchList.isEmpty) continue;

          final targetClean = _cleanTitle(title);
          for (final item in searchList) {
            final sClean = _cleanTitle(item['slug'] ?? '');
            final tClean = _cleanTitle(item['text'] ?? '');
            if (sClean == targetClean || tClean == targetClean || tClean.contains(targetClean)) {
              seriesSlug = item['slug'];
              break;
            }
          }
          if (seriesSlug != null) break;
        }
      }

      if (seriesSlug == null) return results;

      // 3. Fetch watch page
      final watchRes = await client.get(
        Uri.parse('$_baseUrl/watch/$seriesSlug/ep-$episodeNumber'),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/watch/$seriesSlug'},
      ).timeout(const Duration(seconds: 6));

      if (watchRes.statusCode != 200) return results;
      final watchHtml = watchRes.body;

      final byAudio = <String, List<String>>{'sub': [], 'dub': []};

      final iframeMatch = RegExp(r'''<iframe[^>]*src=["']([^"']+)["'][^>]*>''', caseSensitive: false)
          .firstMatch(watchHtml);
      if (iframeMatch != null && iframeMatch.group(1) != null) {
        final iframeSrc = _decodeEntities(iframeMatch.group(1)!);
        final hls = await _extractHls(client, iframeSrc);
        if (hls != null) {
          final audioType = category.toLowerCase() == 'dub' ? 'dub' : 'sub';
          byAudio[audioType]?.add(hls);
        }
      }

      // Check server buttons
      final btnRegex = RegExp(r'''<button\s+[^>]*class=["'][^"']*server-video[^"']*["'][^>]*>''', caseSensitive: false);
      for (final match in btnRegex.allMatches(watchHtml)) {
        final btnHtml = match.group(0)!;
        final videoMatch = RegExp(r'''data-video=["']([^"']+)["']''', caseSensitive: false).firstMatch(btnHtml);
        final tabMatch = RegExp(r'''data-tab=["']([^"']+)["']''', caseSensitive: false).firstMatch(btnHtml);
        if (videoMatch != null && videoMatch.group(1) != null) {
          final videoUrl = _decodeEntities(videoMatch.group(1)!);
          final isDub = tabMatch?.group(1)?.toLowerCase().contains('dub') ?? false;
          final cat = isDub ? 'dub' : 'sub';
          if (!byAudio[cat]!.contains(videoUrl)) {
            byAudio[cat]!.add(videoUrl);
          }
        }
      }

      final targetUrls = byAudio[category.toLowerCase()] ?? [];
      for (final u in targetUrls) {
        var finalUrl = u;
        if (!finalUrl.contains('.m3u8')) {
          final resolved = await _extractHls(client, finalUrl);
          if (resolved != null) finalUrl = resolved;
        }

        if (finalUrl.contains('.m3u8') || finalUrl.startsWith('http')) {
          results.add(AniNekoAnimeResult(
            url: finalUrl,
            server: 'AniNeko',
            quality: '1080p',
            category: category.toUpperCase(),
            headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AniNekoExtractor] extract error: $e');
    } finally {
      client.close();
    }

    return results;
  }
}
