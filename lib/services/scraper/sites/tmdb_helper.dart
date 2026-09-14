import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user_agent.dart';
import '../../tmdb/tmdb_settings.dart';

class TmdbHelper {
  /// The key TMDB's own API is called with: the user's, else the build's.
  ///
  /// This used to be a constant committed here, duplicated in `videasy.dart`.
  /// A TMDB key in a public repository gets found and revoked -- which is what
  /// happened to the one in `TmdbSettings`, and the reason cast photos were
  /// dead on v1.6.2. The same key sitting in two scrapers was the same bet
  /// twice.
  ///
  /// Null is an ordinary case, not an error: every call site below already
  /// had a keyless path, because TMDB Direct was never the only route.
  static String? get _apiKey => TmdbSettings.effectiveApiKey;
  static const _tmdbDirect = 'https://api.themoviedb.org/3';
  static const _tmdbProxy = 'https://db.speedracelight.com/3';

  static const _headers = {
    'User-Agent':
        kDefaultUA,
    'Accept': 'application/json',
  };

  static final Map<String, int> _cache = {};

  static String _cleanString(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static Future<int?> resolveTmdbId({
    String? imdbId,
    required String title,
    required String type,
    int? year,
  }) async {
    final cacheKey = '${imdbId ?? ""}|$title|$type|${year ?? ""}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    String cleanId = (imdbId ?? '').trim();
    cleanId = cleanId.replaceAll(RegExp(r'^(tmdb|movie|tv|imdb):', caseSensitive: false), '');
    if (cleanId.contains(':')) {
      cleanId = cleanId.split(':')[0];
    }

    final isTv = (type == 'tv' || type == 'series');
    final endpoint = isTv ? 'tv' : 'movie';

    if (cleanId.isNotEmpty) {
      // 1. Direct numeric ID
      if (RegExp(r'^\d+$').hasMatch(cleanId)) {
        final id = int.parse(cleanId);
        _cache[cacheKey] = id;
        return id;
      }

      // 2. Query TMDB Find API for tt IMDB IDs
      if (cleanId.startsWith('tt')) {
        final key = _apiKey;
        if (key != null) {
          try {
            final uri = Uri.parse('$_tmdbDirect/find/$cleanId?api_key=$key&external_source=imdb_id');
            final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 7));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              final results = isTv ? (data['tv_results'] as List?) : (data['movie_results'] as List?);
              if (results != null && results.isNotEmpty) {
                final id = results.first['id'] as int?;
                if (id != null) {
                  _cache[cacheKey] = id;
                  return id;
                }
              }
            }
          } catch (_) {
            // A failed lookup leaves the id unresolved; the caller searches by
            // title instead.
          }
        }

        // Backup find query via Speedrace proxy
        try {
          final uri = Uri.parse('$_tmdbProxy/find/$cleanId?external_source=imdb_id');
          final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final results = isTv ? (data['tv_results'] as List?) : (data['movie_results'] as List?);
            if (results != null && results.isNotEmpty) {
              final id = results.first['id'] as int?;
              if (id != null) {
                _cache[cacheKey] = id;
                return id;
              }
            }
          }
        } catch (_) {
          // Same lookup, other endpoint shape.
        }
      }
    }

    // 3. Search by title, type, and year matching
    if (title.isNotEmpty) {
      final targetCleanTitle = _cleanString(title);

      // Search via official TMDB API with user's key, when there is one.
      final key = _apiKey;
      if (key != null) {
        try {
          final uri = Uri.parse('$_tmdbDirect/search/$endpoint?api_key=$key&query=${Uri.encodeComponent(title)}');
          final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 7));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              int? bestMatchId;

              for (final item in results) {
                final itemTitle = (item['title'] ?? item['name'] ?? item['original_title'] ?? item['original_name'] ?? '').toString();
                final itemCleanTitle = _cleanString(itemTitle);
                final dateStr = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
                final itemYear = dateStr.length >= 4 ? int.tryParse(dateStr.substring(0, 4)) : null;

                final titleMatch = itemCleanTitle == targetCleanTitle ||
                    itemCleanTitle.contains(targetCleanTitle) ||
                    targetCleanTitle.contains(itemCleanTitle);

                if (titleMatch) {
                  if (year != null && itemYear != null) {
                    if (itemYear == year || (itemYear - year).abs() <= 1) {
                      final id = item['id'] as int?;
                      if (id != null) {
                        _cache[cacheKey] = id;
                        return id;
                      }
                    }
                  } else {
                    bestMatchId ??= item['id'] as int?;
                  }
                }
              }

              if (bestMatchId != null) {
                _cache[cacheKey] = bestMatchId;
                return bestMatchId;
              }

              // Fallback to first result if available
              final fallbackId = results.first['id'] as int?;
              if (fallbackId != null) {
                _cache[cacheKey] = fallbackId;
                return fallbackId;
              }
            }
          }
        } catch (_) {
          // The fallback search failed too, so there is no id for this title.
        }
      }

      // Backup search via Speedrace Proxy
      try {
        final uri = Uri.parse('$_tmdbProxy/search/$endpoint?query=${Uri.encodeComponent(title)}');
        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            for (final item in results) {
              final itemTitle = (item['title'] ?? item['name'] ?? item['original_title'] ?? item['original_name'] ?? '').toString();
              final itemCleanTitle = _cleanString(itemTitle);
              final dateStr = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
              final itemYear = dateStr.length >= 4 ? int.tryParse(dateStr.substring(0, 4)) : null;

              if (itemCleanTitle == targetCleanTitle || itemCleanTitle.contains(targetCleanTitle)) {
                if (year == null || itemYear == null || itemYear == year || (itemYear - year).abs() <= 1) {
                  final id = item['id'] as int?;
                  if (id != null) {
                    _cache[cacheKey] = id;
                    return id;
                  }
                }
              }
            }

            final fallbackId = results.first['id'] as int?;
            if (fallbackId != null) {
              _cache[cacheKey] = fallbackId;
              return fallbackId;
            }
          }
        }
      } catch (_) {
        // Last fallback. Returning null means the scraper works from the title
        // alone.
      }
    }

    return null;
  }
}
