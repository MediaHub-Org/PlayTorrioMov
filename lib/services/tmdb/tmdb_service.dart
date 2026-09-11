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
    if (key == null || tmdbId.isEmpty) return TmdbCredits.empty;

    final kind = isTvShow ? 'tv' : 'movie';
    final uri = Uri.parse('$_baseUrl/$kind/$tmdbId/credits')
        .replace(queryParameters: {'api_key': key});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return TmdbCredits.empty;

      return parseCredits(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[TmdbService] fetchCredits failed: $e');
      return TmdbCredits.empty;
    }
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
}
