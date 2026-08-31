// AnimeSlayer (animeslayer.to) backend service.
//
// Scrapes home, categories, search, details, and resolves Arabic Anime metadata.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/anime/anime_media.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';

class AnimeArabicService {
  static final AnimeArabicService instance = AnimeArabicService._internal();
  factory AnimeArabicService() => instance;
  AnimeArabicService._internal();

  static const String baseUrl = 'https://animeslayer.to';
  static const String _xorKey = 'asxwqa147';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  // ─── Cache (per-process, short-lived) ───────────────────────────
  static final Map<String, _CacheEntry> _httpCache = {};
  static const _cacheTtl = Duration(minutes: 10);

  // ─── HTTP helper ────────────────────────────────────────────────
  Future<String> _get(String path) async {
    final url = path.startsWith('http') ? path : '$baseUrl$path';
    final cached = _httpCache[url];
    if (cached != null && DateTime.now().isBefore(cached.expires)) {
      return cached.body;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', _userAgent);
      req.headers.set('Accept-Language', 'ar,en;q=0.8');
      req.followRedirects = true;
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      _httpCache[url] = _CacheEntry(body, DateTime.now().add(_cacheTtl));
      return body;
    } finally {
      client.close(force: true);
    }
  }

  // ─── Obfuscation: data-href → /e/... or /title/... ──────────────
  static String? decodeHref(String encoded) {
    try {
      final decoded = base64.decode(encoded);
      final keyBytes = utf8.encode(_xorKey);
      final out = StringBuffer();
      for (var i = 0; i < decoded.length; i++) {
        out.writeCharCode(decoded[i] ^ keyBytes[i % keyBytes.length]);
      }
      return out.toString();
    } catch (_) {
      return null;
    }
  }

  // ─── Public API ─────────────────────────────────────────────────
  Future<HomeFeed> getHome() async {
    final html = await _get('/home');
    return _parseHome(html);
  }

  Future<List<ArabicAnimeCard>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final body = await _get('/api/search.php?q=${Uri.encodeQueryComponent(q)}');
    try {
      final raw = jsonDecode(body);
      if (raw is! List) return [];
      final out = <ArabicAnimeCard>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final href = (item['href'] ?? '').toString();
        if (href.isEmpty) continue;
        final slug = href.startsWith('/title/')
            ? href.substring(7)
            : href.replaceAll(RegExp(r'^/+'), '');
        final tag = (item['type'] ?? item['status'] ?? '').toString();
        out.add(ArabicAnimeCard(
          slug: slug,
          title: _stripBrand(_decodeEntities((item['title'] ?? '').toString()).trim()),
          cover: (item['image'] ?? '').toString().isEmpty
              ? null
              : item['image'].toString(),
          tag: tag.isEmpty ? null : tag,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('[AnimeArabicService] search JSON parse failed: $e');
      try {
        final html = await _get('/?s=${Uri.encodeQueryComponent(q)}');
        return _parseCardGrid(html);
      } catch (_) {
        return [];
      }
    }
  }

  Future<ArabicAnimeDetails> getDetails(String slug) async {
    final path = slug.startsWith('/title/') ? slug : '/title/$slug';
    final html = await _get(path);
    return _parseDetails(
      html,
      slug.startsWith('/title/') ? slug.substring(7) : slug,
    );
  }

  // ─── Parsing ────────────────────────────────────────────────────
  HomeFeed _parseHome(String html) {
    final headings = <_HeadingHit>[];
    final hRe = RegExp(r'<h[12][^>]*>([\s\S]*?)<\/h[12]>', multiLine: true);
    for (final m in hRe.allMatches(html)) {
      final text = _stripTags(m.group(1) ?? '').trim();
      if (text.isEmpty) continue;
      headings.add(_HeadingHit(text, m.start, m.end));
    }

    final feed = HomeFeed();
    feed.spotlight = _parseSpotlight(html);

    for (var i = 0; i < headings.length; i++) {
      final h = headings[i];
      final endIdx = i + 1 < headings.length ? headings[i + 1].start : html.length;
      final section = html.substring(h.end, endIdx);
      final cards = _parseCardGrid(section);
      if (cards.isEmpty) continue;
      final t = h.text;
      if (t.contains('آخر الحلقات') || t.contains('Latest')) {
        feed.recentEpisodes = cards;
      } else if (t.contains('الأكثر شهرة') || t.contains('شعبية هذا') || t.contains('Trending')) {
        feed.trending = cards;
      } else if (t.contains('الأفلام الأكثر شعبية') || t.contains('Movies')) {
        feed.popularMovies = cards;
      } else if (t.contains('أفضل انميات') || t.contains('أفضل الأنميات')) {
        feed.topSeasonal = cards;
      } else if (t.contains('أنميات موسيمية') || t.contains('Seasonal')) {
        feed.seasonal = cards;
      } else if (t.contains('أسطورية') || t.contains('Legendary')) {
        feed.legendary = cards;
      } else if (t.contains('المنتظرة') || t.contains('Upcoming')) {
        feed.upcoming = cards;
      } else {
        feed.misc.add(MapEntry(t, cards));
      }
    }

    return feed;
  }

  List<ArabicAnimeCard> _parseSpotlight(String html) {
    final out = <ArabicAnimeCard>[];
    final re = RegExp(
      r'href="(/title/[^"]+)"[\s\S]{0,4000}?(?:<img[^>]*?src="([^"]+)"[\s\S]{0,200})?',
      multiLine: true,
    );
    final seen = <String>{};
    for (final m in re.allMatches(html)) {
      if (out.length >= 8) break;
      final path = m.group(1)!;
      if (seen.contains(path)) continue;
      seen.add(path);
      final slug = path.substring('/title/'.length);
      out.add(ArabicAnimeCard(
        slug: slug,
        title: _humanizeSlug(slug),
        cover: m.group(2),
      ));
    }
    return out;
  }

  List<ArabicAnimeCard> _parseCardGrid(String chunk) {
    final out = <ArabicAnimeCard>[];
    final seen = <String>{};

    final reA = RegExp(
      r'data-href="([A-Za-z0-9+/=]+)"[\s\S]{0,1500}?'
      r'<img[^>]*?src="([^"]+)"[^>]*?alt="([^"]*)"[\s\S]{0,1500}?'
      r'(?:media-card-title[^>]*>([^<]+)</span>'
      r'|item[^>]*>(?:[\s\S]{0,800}?)<span[^>]*>([^<]+)</span>)?',
      multiLine: true,
    );

    for (final m in reA.allMatches(chunk)) {
      final encoded = m.group(1)!;
      final decoded = decodeHref(encoded) ?? '';
      if (!decoded.startsWith('/title/')) continue;
      final slug = decoded.substring('/title/'.length);
      if (seen.contains(slug)) continue;
      seen.add(slug);

      final cover = _normalizeImg(m.group(2)!);
      final alt = m.group(3) ?? '';
      final tA = m.group(4);
      final tB = m.group(5);
      var title = (tA?.isNotEmpty == true ? tA! : (tB?.isNotEmpty == true ? tB! : alt)).trim();
      title = _stripBrand(title);
      if (title.isEmpty || title.toLowerCase().contains('scum of the brave')) {
        title = _humanizeSlug(slug);
      }

      final ctxEnd = (m.end + 800).clamp(0, chunk.length);
      final ctx = chunk.substring(m.start, ctxEnd);
      String? tag;
      final tagMatch = RegExp(r'media-card-type[^>]*>([^<]+)<').firstMatch(ctx);
      if (tagMatch != null) tag = _stripTags(tagMatch.group(1)!).trim();
      String? rating;
      final rateMatch = RegExp(r'(?:تقييم|rating)\s*([\d.]+)', caseSensitive: false).firstMatch(ctx);
      if (rateMatch != null) rating = rateMatch.group(1);
      String? episodeBadge;
      final epMatch = RegExp(r'الحلقة\s*(\d+)').firstMatch(ctx);
      if (epMatch != null) episodeBadge = 'الحلقة ${epMatch.group(1)}';

      out.add(ArabicAnimeCard(
        slug: slug,
        title: title,
        cover: cover,
        tag: tag,
        rating: rating,
        episodeBadge: episodeBadge,
      ));
    }

    return out;
  }

  ArabicAnimeDetails _parseDetails(String html, String slug) {
    String? title;
    final ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(html);
    if (ogTitle != null) title = _stripBrand(_decodeEntities(ogTitle.group(1)!));
    title ??= _humanizeSlug(slug);

    String? banner;
    final bannerMatch = RegExp(
      r'<img[^>]*alt="[^"]*banner[^"]*"[^>]*src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (bannerMatch != null) banner = _normalizeImg(bannerMatch.group(1)!);

    String? cover;
    final coverMatch = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"').firstMatch(html);
    if (coverMatch != null) cover = _normalizeImg(coverMatch.group(1)!);

    String? description;
    final descMatch = RegExp(r'<meta\s+name="description"\s+content="([^"]+)"').firstMatch(html);
    if (descMatch != null) description = _decodeEntities(descMatch.group(1)!).trim();

    final synopsisRe = RegExp(r'<p[^>]*class="[^"]*description[^"]*"[^>]*>([\s\S]*?)</p>', caseSensitive: false);
    final synopsisMatch = synopsisRe.firstMatch(html);
    if (synopsisMatch != null) {
      final long = _stripTags(synopsisMatch.group(1)!).trim();
      if (long.length > (description?.length ?? 0)) description = long;
    }

    String? status;
    final statusMatch = RegExp(r'(مكتمل|يعرض الآن|قادم)').firstMatch(html);
    if (statusMatch != null) status = statusMatch.group(1);
    String? year;
    final yearMatch = RegExp(r'بداية العرض[:\s]*([\d-]+)').firstMatch(html);
    if (yearMatch != null) year = yearMatch.group(1);
    String? rating;
    final ratingMatch = RegExp(r'التقييم[\s:]*([\d.]+)').firstMatch(html);
    if (ratingMatch != null) rating = ratingMatch.group(1);
    String? studio;
    final studioMatch = RegExp(r'الاستوديو[\s:]*([^<\n]+)').firstMatch(html);
    if (studioMatch != null) studio = _stripTags(studioMatch.group(1)!).trim();

    final genres = <String>{};
    final genreMatch = RegExp(r'أصناف([\s\S]{0,400})').firstMatch(html);
    if (genreMatch != null) {
      final raw = _stripTags(genreMatch.group(1)!);
      for (final g in raw.split(RegExp(r'[\s,،]+'))) {
        final t = g.trim();
        if (t.length > 1 && t.length < 20) genres.add(t);
      }
    }

    final episodes = <ArabicEpisode>[];
    final epsBlock = RegExp(r'const\s+episodes\s*=\s*\[([\s\S]*?)\];').firstMatch(html);
    if (epsBlock != null) {
      final body = epsBlock.group(1)!;
      final epRe = RegExp(
        r'\{\s*n\s*:\s*(\d+)\s*,\s*title\s*:\s*"([^"]*)"\s*,\s*'
        r'href\s*:\s*"([^"]*)"\s*,\s*desc\s*:\s*"([^"]*)"\s*,\s*'
        r'views\s*:\s*"([^"]*)"\s*,\s*thumb\s*:\s*"([^"]*)"\s*\}',
      );
      for (final m in epRe.allMatches(body)) {
        final n = int.tryParse(m.group(1) ?? '') ?? 0;
        final encHref = m.group(3) ?? '';
        final relUrl = decodeHref(encHref) ?? '';
        episodes.add(ArabicEpisode(
          number: n,
          title: _decodeEntities(m.group(2) ?? '').trim(),
          encodedHref: encHref,
          watchPath: relUrl,
          description: _decodeEntities(m.group(4) ?? '').trim(),
          thumb: m.group(6),
        ));
      }
    }
    episodes.sort((a, b) => a.number.compareTo(b.number));
    if (episodes.length > 1) {
      final seen = <int>{};
      episodes.retainWhere((e) => seen.add(e.number));
    }

    final related = _parseCardGrid(_sliceAfterMarker(html, 'related-grid'));

    return ArabicAnimeDetails(
      slug: slug,
      title: title,
      cover: cover,
      banner: banner,
      description: description ?? '',
      status: status,
      year: year,
      rating: rating,
      studio: studio,
      genres: genres.toList(),
      episodes: episodes,
      related: related,
    );
  }

  String _sliceAfterMarker(String html, String marker) {
    final idx = html.indexOf(marker);
    if (idx < 0) return '';
    return html.substring(idx);
  }

  static String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), ' ');

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'");

  static String _normalizeImg(String src) {
    const pre = 'serveproxy.com/?url=';
    final i = src.indexOf(pre);
    if (i >= 0) return src.substring(i + pre.length);
    return src;
  }

  static String _humanizeSlug(String slug) {
    final raw = slug.replaceAll(RegExp(r'-[a-z0-9]{2,5}$'), '');
    return raw
        .split('-')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  static String _stripBrand(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    final brandRe = RegExp(
      r'(انمي\s*سلاير|أنمي\s*سلاير|انيمي\s*سلاير|انمى\s*سلاير'
      r'|anime\s*slayer|animeslayer)',
      caseSensitive: false,
    );
    final sepRe = RegExp(r'\s*[\-–—|•·:]+\s*');
    while (true) {
      final matches = sepRe.allMatches(s).toList();
      if (matches.isEmpty) break;
      final last = matches.last;
      final tail = s.substring(last.end).trim();
      if (tail.isEmpty || brandRe.hasMatch(tail)) {
        s = s.substring(0, last.start).trim();
        continue;
      }
      break;
    }
    s = s.replaceAll(brandRe, '').trim();
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    s = s.replaceAll(RegExp(r'^[\-–—|•·:\s]+|[\-–—|•·:\s]+$'), '').trim();
    return s;
  }

  // ─── Watch history (continue watching) ──────────────────────────
  static const String _historyKey = 'anime_arabic_history_v1';
  static final ValueNotifier<int> watchHistoryRevision = ValueNotifier<int>(0);

  Future<void> recordWatch({
    required ArabicAnimeCard anime,
    required int episodeNumber,
    required int totalEpisodes,
    Duration? position,
    Duration? duration,
  }) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    list.removeWhere((e) {
      try {
        return jsonDecode(e)['slug'] == anime.slug;
      } catch (_) {
        return true;
      }
    });
    list.insert(
      0,
      jsonEncode({
        'slug': anime.slug,
        'title': anime.title,
        'cover': anime.cover,
        'episodeNumber': episodeNumber,
        'totalEpisodes': totalEpisodes,
        'positionMs': position?.inMilliseconds ?? 0,
        'durationMs': duration?.inMilliseconds ?? 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    if (list.length > 50) list.removeRange(50, list.length);
    await p.setStringList(_historyKey, list);
    watchHistoryRevision.value++;
  }

  Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final raw in list) {
      try {
        out.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  Future<Map<String, dynamic>?> getProgress(String slug) async {
    final all = await getWatchHistory();
    for (final h in all) {
      if (h['slug'] == slug) return h;
    }
    return null;
  }
}

class _CacheEntry {
  final String body;
  final DateTime expires;
  _CacheEntry(this.body, this.expires);
}

class _HeadingHit {
  final String text;
  final int start;
  final int end;
  _HeadingHit(this.text, this.start, this.end);
}

// ════════════════════════════════════════════════════════════════════
//  Models
// ════════════════════════════════════════════════════════════════════

class ArabicAnimeCard {
  final String slug;
  final String title;
  final String? cover;
  final String? tag;
  final String? rating;
  final String? episodeBadge;

  const ArabicAnimeCard({
    required this.slug,
    required this.title,
    this.cover,
    this.tag,
    this.rating,
    this.episodeBadge,
  });

  String get pageUrl => '${AnimeArabicService.baseUrl}/title/$slug';

  AnimeMedia toAnimeMedia() {
    final epCount = episodeBadge != null
        ? int.tryParse(RegExp(r'\d+').firstMatch(episodeBadge ?? '')?.group(0) ?? '') ?? 0
        : 0;
    final score = ((double.tryParse(rating ?? '') ?? 0.0) * 10).round();

    return AnimeMedia(
      id: slug.hashCode.abs(),
      titleRomaji: title,
      titleEnglish: title,
      titleNative: title,
      titleUserPreferred: title,
      coverImageLarge: cover ?? '',
      coverImageExtraLarge: cover ?? '',
      bannerImage: cover ?? '',
      format: (episodeBadge != null && episodeBadge!.isNotEmpty)
          ? episodeBadge!
          : ((tag?.contains('فيلم') == true || tag?.contains('Movie') == true) ? 'MOVIE' : 'TV'),
      status: tag ?? 'FINISHED',
      totalEpisodes: epCount,
      averageScore: score,
      description: title,
    );
  }
}

class ArabicAnimeDetails {
  final String slug;
  final String title;
  final String? cover;
  final String? banner;
  final String description;
  final String? status;
  final String? year;
  final String? rating;
  final String? studio;
  final List<String> genres;
  final List<ArabicEpisode> episodes;
  final List<ArabicAnimeCard> related;

  const ArabicAnimeDetails({
    required this.slug,
    required this.title,
    this.cover,
    this.banner,
    required this.description,
    this.status,
    this.year,
    this.rating,
    this.studio,
    this.genres = const [],
    this.episodes = const [],
    this.related = const [],
  });

  String get displayCover => cover ?? '';
  String get displayBanner => banner ?? cover ?? '';

  ArabicAnimeCard toCard() => ArabicAnimeCard(
        slug: slug,
        title: title,
        cover: cover,
        tag: status,
        rating: rating,
      );

  AnimeMedia toAnimeMedia() {
    final score = ((double.tryParse(rating ?? '') ?? 0.0) * 10).round();
    final y = int.tryParse(year ?? '') ?? 0;

    return AnimeMedia(
      id: slug.hashCode.abs(),
      titleRomaji: title,
      titleEnglish: title,
      titleNative: title,
      titleUserPreferred: title,
      coverImageLarge: cover ?? '',
      coverImageExtraLarge: cover ?? '',
      bannerImage: displayBanner,
      format: (status?.contains('فيلم') == true || genres.contains('فيلم')) ? 'MOVIE' : 'TV',
      status: status ?? 'FINISHED',
      totalEpisodes: episodes.length,
      averageScore: score,
      description: description,
      studioName: studio ?? '',
      seasonYear: y,
      genres: genres,
    );
  }

  MovieDetail toMovieDetail() {
    return MovieDetail(
      id: 'arabic_anime:$slug',
      type: 'anime',
      name: title,
      poster: displayCover,
      background: displayBanner,
      description: description,
      year: year,
      imdbRating: rating,
      genres: genres,
      videos: episodes
          .map((e) => Video(
                id: 'arabic_anime:$slug:${e.number}',
                season: 1,
                episode: e.number,
                title: e.title.isNotEmpty ? e.title : 'الحلقة ${e.number}',
                thumbnail: e.thumb ?? displayBanner,
              ))
          .toList(),
    );
  }
}

class ArabicEpisode {
  final int number;
  final String title;
  final String encodedHref;
  final String watchPath; // e.g. "/e/jujutsu-kaisen-cly#bkgy"
  final String description;
  final String? thumb;

  const ArabicEpisode({
    required this.number,
    required this.title,
    required this.encodedHref,
    required this.watchPath,
    this.description = '',
    this.thumb,
  });

  String get watchUrl => '${AnimeArabicService.baseUrl}$watchPath';
}

class HomeFeed {
  List<ArabicAnimeCard> spotlight = [];
  List<ArabicAnimeCard> recentEpisodes = [];
  List<ArabicAnimeCard> trending = [];
  List<ArabicAnimeCard> popularMovies = [];
  List<ArabicAnimeCard> topSeasonal = [];
  List<ArabicAnimeCard> seasonal = [];
  List<ArabicAnimeCard> legendary = [];
  List<ArabicAnimeCard> upcoming = [];
  List<MapEntry<String, List<ArabicAnimeCard>>> misc = [];
}
