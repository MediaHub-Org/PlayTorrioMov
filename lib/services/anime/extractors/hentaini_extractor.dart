import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Extractor for hentaini.com.
class HentainiResult {
  final String url;
  final String referer;
  final String origin;
  HentainiResult({required this.url, required this.referer, required this.origin});
}

class _HSeries {
  final int id;
  final String title;
  final String titleEnglish;
  final String url;
  _HSeries(this.id, this.title, this.titleEnglish, this.url);
}

class HentainiExtractor {
  static const _site = 'https://hentaini.com';
  static const _api = 'https://admin.hentaini.com/api';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const _stopwords = <String>{
    'a', 'an', 'the', 'of', 'and', 'or', 'to', 'in', 'on', 'at',
    'for', 'with', 'by', 'from', 'is', 'it',
    'no', 'wa', 'ga', 'ni', 'o', 'wo', 'de', 'mo', 'ka', 'ya',
    'na', 'e', 'he', 'te', 'ne',
    'animation', 'anime', 'motion', 'ova', 'ona', 'tv', 'special',
    'version', 'edition', 'dubbed', 'subbed', 'sub', 'dub',
    'uncensored', 'censored', 'episode', 'ep', 'season',
    'side', 'part', 'arc', 'chapter', 'vol', 'volume',
  };

  final HttpClient _http = HttpClient()
    ..userAgent = _ua
    ..connectionTimeout = const Duration(seconds: 15);

  void _setHeaders(HttpClientRequest req, {String? referer, bool json = false}) {
    req.headers.set('User-Agent', _ua);
    req.headers.set('Accept', json ? 'application/json' : '*/*');
    req.headers.set('Accept-Language', 'en-US,en;q=0.9');
    if (referer != null) req.headers.set('Referer', referer);
  }

  Future<String?> _get(String url, {String? referer, bool json = false}) async {
    try {
      final req = await _http.getUrl(Uri.parse(url));
      _setHeaders(req, referer: referer, json: json);
      final resp = await req.close().timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200) {
        if (kDebugMode) debugPrint('[Hentaini] $url HTTP ${resp.statusCode}');
        await resp.drain<void>();
        return null;
      }
      return await resp.transform(const Utf8Decoder()).join();
    } catch (e) {
      if (kDebugMode) debugPrint('[Hentaini] GET $url error: $e');
      return null;
    }
  }

  Set<String> _tokens(String s) {
    final lower = s.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toSet();
  }

  List<String> _titleVariants(String t) {
    final out = <String>{t.trim()};
    for (final pat in [
      RegExp(r'\s*[:\-~–—].+$'),
      RegExp(r'\s*\(.+?\)\s*'),
      RegExp(r'\s*\[.+?\]\s*'),
      RegExp(r'\s+the\s+animation\b', caseSensitive: false),
    ]) {
      final stripped = t.replaceAll(pat, '').trim();
      if (stripped.length >= 3) out.add(stripped);
    }
    final words = t.split(RegExp(r'\s+'));
    if (words.length > 3) {
      out.add(words.take(3).join(' '));
    }
    return out.toList();
  }

  Future<List<_HSeries>> _searchSeries(String query) async {
    final url =
        '$_api/series?filters[title][\$containsi]=${Uri.encodeQueryComponent(query)}&pagination[pageSize]=25';
    final jsonStr = await _get(url, referer: '$_site/', json: true);
    if (jsonStr == null) return const [];

    try {
      final doc = jsonDecode(jsonStr);
      final list = (doc['data'] as List?) ?? const [];
      final out = <_HSeries>[];
      for (final item in list) {
        if (item is! Map) continue;
        final id = (item['id'] as num?)?.toInt();
        final attr = (item['attributes'] as Map?) ?? item;
        final title = (attr['title'] ?? '').toString();
        final titleEng = (attr['title_english'] ?? '').toString();
        final slug = (attr['url'] ?? attr['slug'] ?? '').toString();
        if (id != null && title.isNotEmpty) {
          out.add(_HSeries(id, title, titleEng, slug));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<_HSeries?> _resolveSeries(List<String> titles) async {
    final hits = <int, _HSeries>{};
    for (final raw in titles) {
      for (final q in _titleVariants(raw)) {
        if (q.isEmpty) continue;
        final list = await _searchSeries(q);
        for (final s in list) {
          hits.putIfAbsent(s.id, () => s);
        }
        if (hits.isNotEmpty) break;
      }
      if (hits.isNotEmpty) break;
    }
    if (hits.isEmpty) return null;

    final queryTokenSets = titles.map(_tokens).toList();
    _HSeries? best;
    double bestScore = 0.0;

    for (final s in hits.values) {
      final t1 = _tokens(s.title);
      final t2 = _tokens(s.titleEnglish);
      final combined = t1.union(t2);
      if (combined.isEmpty) continue;

      for (final qTokens in queryTokenSets) {
        if (qTokens.isEmpty) continue;
        final inter = combined.intersection(qTokens).length;
        final union = combined.union(qTokens).length;
        final jaccard = union == 0 ? 0.0 : inter / union;
        if (jaccard > bestScore) {
          bestScore = jaccard;
          best = s;
        }
      }
    }

    if (bestScore < 0.45 || best == null) return null;
    return best;
  }

  Future<HentainiResult?> extract({
    required List<String> titleCandidates,
    required int episodeNumber,
  }) async {
    try {
      final series = await _resolveSeries(titleCandidates);
      if (series == null) return null;

      final url = '$_api/series/${series.id}?populate=episodes';
      final jsonStr = await _get(url, referer: '$_site/', json: true);
      if (jsonStr == null) return null;

      final doc = jsonDecode(jsonStr);
      final data = (doc['data'] as Map?) ?? const {};
      final attr = (data['attributes'] as Map?) ?? data;
      final epContainer = attr['episodes'];
      final epList = (epContainer is Map ? epContainer['data'] : epContainer) as List? ?? const [];

      Map<String, dynamic>? targetEp;
      for (final ep in epList) {
        if (ep is! Map) continue;
        final epAttr = (ep['attributes'] as Map?) ?? ep;
        final epNum = (epAttr['episode_number'] as num?)?.toInt() ??
            int.tryParse(epAttr['episode_number']?.toString() ?? '');
        if (epNum == episodeNumber) {
          targetEp = epAttr.cast<String, dynamic>();
          break;
        }
      }

      if (targetEp == null && epList.isNotEmpty && episodeNumber <= epList.length) {
        final ep = epList[episodeNumber - 1];
        if (ep is Map) {
          targetEp = ((ep['attributes'] as Map?) ?? ep).cast<String, dynamic>();
        }
      }

      if (targetEp == null) return null;

      final rawPlayers = targetEp['players'];
      List<dynamic> players = const [];
      if (rawPlayers is String) {
        try {
          players = jsonDecode(rawPlayers) as List? ?? const [];
        } catch (_) {}
      } else if (rawPlayers is List) {
        players = rawPlayers;
      }

      String? hlsUrl;
      String? mp4Url;

      for (final p in players) {
        if (p is! Map) continue;
        final file = (p['file'] ?? p['url'] ?? p['link'] ?? '').toString();
        if (file.isEmpty) continue;
        if (file.contains('.m3u8')) {
          hlsUrl ??= file;
        } else if (file.contains('.mp4')) {
          mp4Url ??= file;
        }
      }

      final streamUrl = hlsUrl ?? mp4Url;
      if (streamUrl == null || streamUrl.isEmpty) return null;

      return HentainiResult(
        url: streamUrl,
        referer: '$_site/',
        origin: _site,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Hentaini] extract failed: $e');
      return null;
    }
  }
}
