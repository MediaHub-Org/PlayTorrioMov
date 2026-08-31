// bestsimilar.com scraper — title autocomplete + similar-movies extraction.
//
// API surface used:
//   GET /site/autocomplete?term=<q>            (X-Requested-With: XMLHttpRequest)
//        → { movie:[{id,label,url,serial}], tag:[...] }
//        serial: "0" = movie, "1" = TV show
//   GET /movies/{id}-{slug}                    (full HTML detail page; ~30 similar items)
//
// HTML parsing is done with package:html (synchronously). Network with
// package:http. Results are kept in a small in-memory cache per process.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class BSAutocompleteHit {
  final int id;
  final String slug;          // "145-sinister"
  final String label;         // "Sinister (2012)"
  final String title;         // "Sinister"
  final int? year;
  final bool isTv;            // serial == "1"
  final String url;           // "/movies/145-sinister"

  const BSAutocompleteHit({
    required this.id,
    required this.slug,
    required this.label,
    required this.title,
    required this.year,
    required this.isTv,
    required this.url,
  });
}

class BSItem {
  final int id;
  final String slug;
  final String title;
  final int? year;
  final double? rating;       // 0..10
  final String? voteCount;    // "67K"
  final String thumbUrl;      // bestsimilar absolute URL
  final int? similarityPercent;
  final String? genre;
  final String? country;
  final String? duration;
  final String? story;
  final List<String> styleTags;
  final List<String> plotTags;
  final List<String> audienceTags;
  final List<String> timeTags;
  final List<String> placeTags;

  // Optional TMDB enrichment
  String? tmdbPosterUrl;
  String? tmdbBackdropUrl;
  int? tmdbId;
  String? tmdbMediaType;      // 'movie' | 'tv'

  bool get isTv {
    if (tmdbMediaType == 'tv') return true;
    if (slug.contains('serial') || slug.contains('tv-series') || slug.contains('series')) return true;
    final dur = (duration ?? '').toLowerCase();
    if (dur.contains('eps') || dur.contains('episode') || dur.contains('serial') || dur.contains('season')) return true;
    return false;
  }

  BSItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.year,
    required this.rating,
    required this.voteCount,
    required this.thumbUrl,
    required this.similarityPercent,
    required this.genre,
    required this.country,
    required this.duration,
    required this.story,
    required this.styleTags,
    required this.plotTags,
    required this.audienceTags,
    required this.timeTags,
    required this.placeTags,
  });

  String get displayTitle =>
      year != null ? '$title ($year)' : title;
}

class BSDetails {
  final int id;
  final String slug;
  final String title;
  final int? year;
  final double? rating;
  final String? voteCount;
  final String thumbUrl;
  final String? story;
  final String? genre;
  final String? country;
  final String? duration;
  final List<String> styleTags;
  final List<String> plotTags;
  final List<String> audienceTags;
  final List<String> timeTags;
  final List<String> placeTags;
  final String? blurb;        // "If you like X you are looking for ..."
  final List<BSItem> similar;

  const BSDetails({
    required this.id,
    required this.slug,
    required this.title,
    required this.year,
    required this.rating,
    required this.voteCount,
    required this.thumbUrl,
    required this.story,
    required this.genre,
    required this.country,
    required this.duration,
    required this.styleTags,
    required this.plotTags,
    required this.audienceTags,
    required this.timeTags,
    required this.placeTags,
    required this.blurb,
    required this.similar,
  });
}

class BestSimilarScraper {
  static const String baseUrl = 'https://bestsimilar.com';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  // Tiny LRU-ish caches.
  static final Map<String, List<BSAutocompleteHit>> _autocompleteCache = {};
  static final Map<int, BSDetails> _detailsCache = {};

  /// Hit the site's autocomplete endpoint. Returns parsed hits.
  static Future<List<BSAutocompleteHit>> autocomplete(String term) async {
    final q = term.trim();
    if (q.isEmpty) return const [];
    final cached = _autocompleteCache[q.toLowerCase()];
    if (cached != null) return cached;

    final uri = Uri.parse(
        '$baseUrl/site/autocomplete?term=${Uri.encodeQueryComponent(q)}');
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': _ua,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '$baseUrl/',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body);
      if (data is! Map) return const [];
      final movies = data['movie'];
      if (movies is! List) return const [];

      final out = <BSAutocompleteHit>[];
      for (final m in movies) {
        if (m is! Map) continue;
        final id = int.tryParse('${m['id']}');
        final url = (m['url'] ?? '').toString();
        final label = (m['label'] ?? '').toString();
        if (id == null || url.isEmpty || label.isEmpty) continue;
        final isTv = '${m['serial']}' == '1';
        final yearMatch = RegExp(r'\((\d{4})\)\s*$').firstMatch(label);
        final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) : null;
        final title = label.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();
        final slug = url.replaceFirst('/movies/', '');
        out.add(BSAutocompleteHit(
          id: id,
          slug: slug,
          label: label,
          title: title,
          year: year,
          isTv: isTv,
          url: url,
        ));
      }
      _autocompleteCache[q.toLowerCase()] = out;
      if (_autocompleteCache.length > 80) {
        _autocompleteCache.remove(_autocompleteCache.keys.first);
      }
      return out;
    } catch (e) {
      debugPrint('[BestSimilar] autocomplete failed: $e');
      return const [];
    }
  }

  /// Look up the best matching bestsimilar entry for a given TMDB-style
  /// (title, year, isTv) tuple. Returns null if nothing close enough.
  static Future<BSAutocompleteHit?> findBest({
    required String title,
    int? year,
    bool isTv = false,
  }) async {
    // Generate query terms to search
    final terms = <String>[];
    final cleanRaw = title.trim();
    if (cleanRaw.isNotEmpty) terms.add(cleanRaw);

    // If title has a separator like ":", "-", "–", try variations
    final separators = [':', ' - ', ' – ', ' — '];
    for (final sep in separators) {
      if (cleanRaw.contains(sep)) {
        final parts = cleanRaw.split(sep);
        final prefix = parts.first.trim();
        final suffix = parts.sublist(1).join(sep).trim();
        if (prefix.isNotEmpty && !terms.contains(prefix)) terms.add(prefix);
        if (suffix.isNotEmpty && !terms.contains(suffix)) terms.add(suffix);
      }
    }

    // Try each query and collect all hits
    final allHits = <int, BSAutocompleteHit>{};
    for (final term in terms) {
      final hits = await autocomplete(term);
      for (final h in hits) {
        allHits[h.id] = h;
      }
    }

    if (allHits.isEmpty) return null;

    final wantTv = isTv;
    BSAutocompleteHit? best;
    var bestScore = -999.0;

    final normTarget = _normalizeTitle(title);
    final targetWords = normTarget.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    for (final h in allHits.values) {
      var score = 0.0;
      final normHit = _normalizeTitle(h.title);
      final hitWords = normHit.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

      // 1. Title match
      if (normHit == normTarget) {
        score += 8.0;
      } else if (normTarget.startsWith(normHit) || normHit.startsWith(normTarget)) {
        score += 4.0;
      } else {
        // Word overlap
        final intersection = targetWords.intersection(hitWords).length;
        if (intersection > 0 && targetWords.isNotEmpty) {
          score += (intersection / targetWords.length) * 4.0;
        }
      }

      // 2. Format Match (Movie vs TV Show)
      if (h.isTv == wantTv) {
        score += 3.0;
      } else {
        score -= 4.0; // Heavy penalty for wrong media format
      }

      // 3. Strict Year Scoring & Discrepancy Penalties
      if (year != null && h.year != null) {
        final diff = (h.year! - year).abs();
        if (diff == 0) {
          score += 6.0;
        } else if (diff == 1) {
          score += 3.0;
        } else if (diff == 2) {
          score += 1.0;
        } else if (diff <= 4) {
          score -= 4.0;
        } else {
          // Major year mismatch (>4 years off, e.g. 2004 vs 2024 is 20 years!)
          score -= 15.0;
        }
      } else if (year != null && h.year == null) {
        score -= 1.0;
      }

      if (score > bestScore) {
        bestScore = score;
        best = h;
      }
    }

    // Require a healthy positive score (at least 6.0)
    return bestScore >= 6.0 ? best : null;
  }

  static String _normalizeTitle(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fetch & parse a movie detail page. Cached per id.
  static Future<BSDetails?> fetchDetails({
    required int id,
    required String slug,
  }) async {
    final cached = _detailsCache[id];
    if (cached != null) return cached;
    final uri = Uri.parse('$baseUrl/movies/$slug');
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': _ua,
        'Accept': 'text/html,application/xhtml+xml',
        'Referer': '$baseUrl/',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('[BestSimilar] details HTTP ${res.statusCode} for $slug');
        return null;
      }
      final parsed = await compute(_parseDetailsHtml, _ParseInput(
        id: id,
        slug: slug,
        html: res.body,
      ));
      if (parsed != null) _detailsCache[id] = parsed;
      if (_detailsCache.length > 30) {
        _detailsCache.remove(_detailsCache.keys.first);
      }
      return parsed;
    } catch (e) {
      debugPrint('[BestSimilar] details failed for $slug: $e');
      return null;
    }
  }
}

class _ParseInput {
  final int id;
  final String slug;
  final String html;
  const _ParseInput({required this.id, required this.slug, required this.html});
}

// Top-level so it can run on a background isolate via `compute()`.
BSDetails? _parseDetailsHtml(_ParseInput input) {
  try {
    final doc = html_parser.parse(input.html);
    final h1 = doc.querySelector('h1');
    var title = '';
    int? year;
    if (h1 != null) {
      final raw = h1.text.trim();
      final m = RegExp(r'^Movies?\s+(?:Like|Similar to)\s+(.+)$',
              caseSensitive: false)
          .firstMatch(raw);
      title = (m?.group(1) ?? raw).trim();
    }
    // Try to grab the year from page <title>.
    final pageTitle = doc.querySelector('title')?.text ?? '';
    final ym = RegExp(r'\((\d{4})\)').firstMatch(pageTitle);
    if (ym != null) year = int.tryParse(ym.group(1)!);

    // Hero info block — body of "Discover more" before the items.
    final infoBlock =
        doc.querySelector('.h-desc')?.text.trim();

    // Hero attrs (Genre/Country/Duration/Story/Style/...) appear inside the
    // sidebar / top "lb-row" before the recommendation list. Easier:
    // scan all `.attr` elements that are *outside* `#movie-rel-list`.
    final relRoot = doc.querySelector('#movie-rel-list');

    final heroAttrs = <String, String>{};
    final heroTags = <String, List<String>>{};
    for (final el in doc.querySelectorAll('.attr')) {
      if (relRoot != null && _isDescendantOf(el, relRoot)) continue;
      final entry = el.querySelector('.entry')?.text.trim() ?? '';
      final value = el.querySelector('.value');
      if (entry.isEmpty || value == null) continue;
      final key = entry.replaceAll(':', '').trim().toLowerCase();
      if (el.classes.contains('attr-tag')) {
        final tags = value.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty && t != '...')
            .toList();
        heroTags[key] = tags;
      } else {
        heroAttrs[key] = value.text.trim();
      }
    }

    // Hero poster: use thumb pattern /img/movie/thumb/XX/{id}.jpg if present.
    final heroImg = doc
        .querySelectorAll('img')
        .firstWhere(
            (e) =>
                (e.attributes['src'] ?? '')
                    .contains('/img/movie/thumb/') &&
                (e.attributes['src'] ?? '').contains('${input.id}.jpg'),
            orElse: () => doc.createElement('img'));
    final heroSrc = heroImg.attributes['src'] ?? '';
    final heroThumb = heroSrc.startsWith('http')
        ? heroSrc
        : '${BestSimilarScraper.baseUrl}$heroSrc';

    // Hero rating/votes — first .rat-rating outside the relRoot.
    double? heroRating;
    String? heroVotes;
    for (final el in doc.querySelectorAll('.rat-rating')) {
      if (relRoot != null && _isDescendantOf(el, relRoot)) continue;
      heroRating = double.tryParse(_textNumber(el.text));
      break;
    }
    for (final el in doc.querySelectorAll('.rat-vote')) {
      if (relRoot != null && _isDescendantOf(el, relRoot)) continue;
      heroVotes = el.text.trim().replaceAll(RegExp(r'[^A-Z0-9.,]'), '');
      break;
    }

    // Similar items.
    final items = <BSItem>[];
    if (relRoot != null) {
      for (final node in relRoot.querySelectorAll('.item.item-movie')) {
        final dataId = int.tryParse(node.attributes['data-id'] ?? '');
        if (dataId == null) continue;
        final nameAnchor = node.querySelector('a.name');
        if (nameAnchor == null) continue;
        final href = nameAnchor.attributes['href'] ?? '';
        final slug = href.replaceFirst('/movies/', '');
        final label = nameAnchor.text.trim();
        final ymItem = RegExp(r'\((\d{4})\)\s*$').firstMatch(label);
        final itemYear = ymItem != null ? int.tryParse(ymItem.group(1)!) : null;
        final itemTitle = label.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();

        final ratingTxt = node.querySelector('.rat-rating')?.text ?? '';
        final voteTxt = node.querySelector('.rat-vote')?.text ?? '';
        final imgSrc = node.querySelector('img')?.attributes['src'] ?? '';
        final thumb = imgSrc.startsWith('http')
            ? imgSrc
            : '${BestSimilarScraper.baseUrl}$imgSrc';
        final smt = node.querySelector('.smt-value')?.text ?? '';
        final simPct = int.tryParse(smt.replaceAll('%', '').trim());

        final attrMap = <String, String>{};
        final tagMap = <String, List<String>>{};
        for (final at in node.querySelectorAll('.attr')) {
          final entry = at.querySelector('.entry')?.text.trim() ?? '';
          final value = at.querySelector('.value');
          if (entry.isEmpty || value == null) continue;
          final key = entry.replaceAll(':', '').trim().toLowerCase();
          if (at.classes.contains('attr-tag')) {
            tagMap[key] = value.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty && t != '...')
                .toList();
          } else {
            attrMap[key] = value.text.trim();
          }
        }

        items.add(BSItem(
          id: dataId,
          slug: slug,
          title: itemTitle,
          year: itemYear,
          rating: double.tryParse(_textNumber(ratingTxt)),
          voteCount: voteTxt.trim().replaceAll(RegExp(r'[^A-Z0-9.,]'), '').isEmpty
              ? null
              : voteTxt.trim().replaceAll(RegExp(r'[^A-Z0-9.,]'), ''),
          thumbUrl: thumb,
          similarityPercent: simPct,
          genre: attrMap['genre'],
          country: attrMap['country'],
          duration: attrMap['duration'],
          story: attrMap['story'],
          styleTags: tagMap['style'] ?? const [],
          plotTags: tagMap['plot'] ?? const [],
          audienceTags: tagMap['audience'] ?? const [],
          timeTags: tagMap['time'] ?? const [],
          placeTags: tagMap['place'] ?? const [],
        ));
      }
    }

    // Sort by similarity % descending; items without a percent go last.
    items.sort((a, b) {
      final av = a.similarityPercent ?? -1;
      final bv = b.similarityPercent ?? -1;
      return bv.compareTo(av);
    });

    return BSDetails(
      id: input.id,
      slug: input.slug,
      title: title,
      year: year,
      rating: heroRating,
      voteCount: heroVotes,
      thumbUrl: heroThumb,
      story: heroAttrs['story'],
      genre: heroAttrs['genre'],
      country: heroAttrs['country'],
      duration: heroAttrs['duration'],
      styleTags: heroTags['style'] ?? const [],
      plotTags: heroTags['plot'] ?? const [],
      audienceTags: heroTags['audience'] ?? const [],
      timeTags: heroTags['time'] ?? const [],
      placeTags: heroTags['place'] ?? const [],
      blurb: infoBlock,
      similar: items,
    );
  } catch (e) {
    debugPrint('[BestSimilar] parse failed: $e');
    return null;
  }
}

bool _isDescendantOf(dynamic node, dynamic ancestor) {
  var p = node.parent;
  while (p != null) {
    if (identical(p, ancestor)) return true;
    p = p.parent;
  }
  return false;
}

String _textNumber(String s) {
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
  return m?.group(1) ?? '';
}
