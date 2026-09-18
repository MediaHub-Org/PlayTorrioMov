import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/movie/cast_member.dart';
import 'tmdb_settings.dart';

/// One TMDB `/credits` response: the people in front of the camera and the
/// ones behind it.
///
/// Both halves come back from a single request. The crew half used to be
/// decoded and dropped on the floor, which is why a title with no director
/// in its addon metadata showed an empty Direction section even with a
/// working TMDB key.
class TmdbCredits {
  final List<CastMember> cast;
  final List<CrewMember> crew;

  const TmdbCredits({this.cast = const [], this.crew = const []});

  bool get isEmpty => cast.isEmpty && crew.isEmpty;

  static const TmdbCredits empty = TmdbCredits();
}

/// Fetches cast (photos, character names) and directing crew from TMDB to
/// fill in what most Stremio addons don't provide -- they typically send
/// `cast` as plain name strings, no photos, and no crew at all. No-ops when
/// no key is available at all (see [TmdbSettings]): everything that calls
/// this degrades gracefully to the addon's own name-only cast list.
abstract final class TmdbService {
  static const _baseUrl = 'https://api.themoviedb.org/3';

  /// What happened on the most recent TMDB request, for the Settings page
  /// to show.
  ///
  /// Every failure here is swallowed on purpose -- a dead key or a captive
  /// portal should cost cast photos, not the details page. The cost of that
  /// is a screen that silently shows bare actor names with no way to tell
  /// a rejected key from a title TMDB has never heard of. This is that way:
  /// one line, read straight off the device, no log capture needed.
  static final ValueNotifier<String?> lastStatus = ValueNotifier<String?>(null);

  static void _note(String message) => lastStatus.value = message;

  /// Maps a non-200 into something a person can act on. 401 is the one that
  /// matters: it means the key is wrong or revoked, which is the only
  /// failure the user can actually fix from Settings.
  static String _describeStatus(int code) => switch (code) {
    401 => 'TMDB rejected the API key (401). Add your own key below.',
    404 => 'TMDB has no entry for this title (404).',
    429 => 'TMDB rate-limited this device (429). Try again shortly.',
    _ => 'TMDB returned HTTP $code.',
  };

  /// Crew jobs worth showing under Direction. TMDB's crew array is long --
  /// every gaffer and boom operator on a feature -- and listing all of it
  /// would bury the handful of names anyone actually looks for.
  static const _directingJobs = {
    'Director',
    'Co-Director',
    'Series Director',
    'Creator',
    'Writer',
    'Screenplay',
    'Story',
  };

  /// Fetches the cast for a movie or TV show by its TMDB id. Returns an
  /// empty list if no API key is available, the id is invalid, or the
  /// request fails -- callers should keep whatever cast data they already
  /// have in that case.
  static Future<List<CastMember>> fetchCast(
    String tmdbId, {
    required bool isTvShow,
  }) async {
    return (await fetchCredits(tmdbId, isTvShow: isTvShow)).cast;
  }

  /// Fetches cast *and* directing crew in one request. Prefer this over
  /// [fetchCast]: `/credits` returns both halves whether or not you read
  /// them, so taking the crew costs nothing extra.
  ///
  /// Returns [TmdbCredits.empty] if no API key is available, the id is
  /// invalid, or the request fails.
  static Future<TmdbCredits> fetchCredits(
    String tmdbId, {
    required bool isTvShow,
  }) async {
    // The user's key when they set one, otherwise the key this build
    // ships with.
    final key = TmdbSettings.effectiveApiKey;
    if (key == null || tmdbId.isEmpty) {
      _note('No TMDB API key configured.');
      return TmdbCredits.empty;
    }

    final kind = isTvShow ? 'tv' : 'movie';
    final uri = Uri.parse('$_baseUrl/$kind/$tmdbId/credits')
        .replace(queryParameters: {'api_key': key});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _note(_describeStatus(response.statusCode));
        return TmdbCredits.empty;
      }

      final credits = parseCredits(jsonDecode(response.body));
      _note(
        'Loaded ${credits.cast.length} cast and ${credits.crew.length} crew '
        'from TMDB.',
      );

      // A series' `/credits` is series-level crew, which for most shows is
      // producers and no director at all -- TV directors are credited per
      // episode. That is why a series' Direction half came back empty even
      // with a working id. The showrunner is what a viewer means by "whose
      // show is this", and it lives on the detail response instead.
      if (isTvShow && credits.crew.isEmpty) {
        final creators = await _fetchSeriesCreators(tmdbId, key);
        if (creators.isNotEmpty) {
          return TmdbCredits(cast: credits.cast, crew: creators);
        }
      }

      return credits;
    } catch (e) {
      debugPrint('[TmdbService] fetchCredits failed: $e');
      _note('Could not reach TMDB: $e');
      return TmdbCredits.empty;
    }
  }

  /// The showrunners from `/tv/{id}`'s `created_by`, as crew labeled
  /// "Creator".
  ///
  /// One extra request, and only for a series whose `/credits` had no
  /// directing crew to show -- so a series that already has one costs
  /// nothing. `/tv/{id}/aggregate_credits` is the heavier alternative: a
  /// large payload whose entries carry a `jobs` array instead of a single
  /// `job`, needing a TV-shaped branch in [parseCredits]. Worth reaching
  /// for only if `created_by` proves thin in practice.
  static Future<List<CrewMember>> _fetchSeriesCreators(
    String tmdbId,
    String key,
  ) async {
    final uri = Uri.parse('$_baseUrl/tv/$tmdbId')
        .replace(queryParameters: {'api_key': key});
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      return parseCreators(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[TmdbService] fetchSeriesCreators failed: $e');
      return const [];
    }
  }

  /// Resolved IMDb -> TMDB ids, including negative results.
  ///
  /// A null *value* means "asked TMDB, it has no match" and is deliberately
  /// cached too: without it, every rebuild of a details page for an obscure
  /// title re-issues the same failing lookup.
  static final Map<String, String?> _tmdbIdByImdbId = <String, String?>{};

  /// Finds the TMDB id for an IMDb id (`tt0137523`), or null.
  ///
  /// This is what makes cast enrichment work at all. `MovieDetail.tmdbId` is
  /// read from `moviedb_id`, a field Cinemeta and most Stremio addons simply
  /// do not send -- they send `imdb_id`. So the id was null for essentially
  /// every title, [fetchCredits] was never called, and the details page fell
  /// back to the addon's plain name strings: no photos, no character names,
  /// no crew.
  static Future<String?> resolveTmdbIdFromImdb(
    String imdbId, {
    required bool isTvShow,
  }) async {
    final key = TmdbSettings.effectiveApiKey;
    if (key == null) return null;

    // Ids arrive as `tt0137523` but also as `tt0137523:1:5` for an episode;
    // the lookup wants the title's id.
    final clean = imdbId.split(':').first.trim();
    if (!clean.startsWith('tt')) return null;

    final cacheKey = '$clean|${isTvShow ? 'tv' : 'movie'}';
    if (_tmdbIdByImdbId.containsKey(cacheKey)) return _tmdbIdByImdbId[cacheKey];

    final uri = Uri.parse('$_baseUrl/find/$clean').replace(
      queryParameters: {'api_key': key, 'external_source': 'imdb_id'},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _note(_describeStatus(response.statusCode));
        return null;
      }
      final id = parseFindResponse(
        jsonDecode(response.body),
        isTvShow: isTvShow,
      );
      _tmdbIdByImdbId[cacheKey] = id;
      return id;
    } catch (e) {
      debugPrint('[TmdbService] resolveTmdbIdFromImdb failed: $e');
      _note('Could not reach TMDB: $e');
      // Deliberately not cached: a timeout is not evidence the title is
      // absent, and the next details-page visit should try again.
      return null;
    }
  }

  /// Reads the first match out of a `/find` body. Separate from the request
  /// so it is testable without a network round-trip or an API key.
  @visibleForTesting
  static String? parseFindResponse(dynamic body, {required bool isTvShow}) {
    if (body is! Map) return null;
    // A show reached through an episode id lands in tv_episode_results, whose
    // entries carry `show_id` rather than being the show itself.
    final keys = isTvShow
        ? const ['tv_results', 'tv_episode_results']
        : const ['movie_results'];
    for (final k in keys) {
      final results = body[k];
      if (results is! List || results.isEmpty) continue;
      final first = results.first;
      if (first is! Map) continue;
      final id = k == 'tv_episode_results' ? first['show_id'] : first['id'];
      if (id != null) return id.toString();
    }
    return null;
  }

  /// Turns a decoded TMDB `/credits` body into [TmdbCredits]. Separate from
  /// the request so the filtering rules below are testable without a network
  /// round-trip or an API key.
  @visibleForTesting
  static TmdbCredits parseCredits(dynamic body) {
    if (body is! Map) return TmdbCredits.empty;

    final rawCast = body['cast'];
    final rawCrew = body['crew'];

    final cast = rawCast is List
        ? rawCast
              .whereType<Map>()
              .map((c) => CastMember.fromJson(c.cast<String, dynamic>()))
              .toList()
        : <CastMember>[];

    // One person can hold several jobs on the same title -- writer and
    // director is common -- and TMDB lists each job as its own crew entry.
    // Keep the first job seen per name so they get one card, not three
    // identical ones side by side.
    final crew = <CrewMember>[];
    if (rawCrew is List) {
      final seen = <String>{};
      for (final entry in rawCrew.whereType<Map>()) {
        final job = entry['job']?.toString() ?? '';
        if (!_directingJobs.contains(job)) continue;
        final member = CrewMember.fromJson(entry.cast<String, dynamic>());
        if (!seen.add(member.name)) continue;
        crew.add(member);
      }
    }

    return TmdbCredits(cast: cast, crew: crew);
  }

  /// Reads `created_by` out of a decoded `/tv/{id}` body.
  ///
  /// Entries there carry a name and a `profile_path` but no `job`, so the
  /// label comes from this side. Anything without a usable name is dropped
  /// rather than rendered as an "Unknown" card.
  @visibleForTesting
  static List<CrewMember> parseCreators(dynamic body) {
    if (body is! Map) return const [];
    final raw = body['created_by'];
    if (raw is! List) return const [];

    final creators = <CrewMember>[];
    final seen = <String>{};
    for (final entry in raw.whereType<Map>()) {
      final member = CrewMember.fromJson(
        entry.cast<String, dynamic>(),
        job: 'Creator',
      );
      final name = member.name.trim();
      if (name.isEmpty || name == 'Unknown') continue;
      if (!seen.add(name)) continue;
      creators.add(member);
    }
    return creators;
  }

  /// Clears the IMDb -> TMDB cache and the status line, for tests.
  @visibleForTesting
  static void resetForTest() {
    _tmdbIdByImdbId.clear();
    lastStatus.value = null;
  }

  /// The status text for a given HTTP code, for tests.
  @visibleForTesting
  static String describeStatusForTest(int code) => _describeStatus(code);
}
