import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/movie/cast_member.dart';
import 'tmdb_settings.dart';

/// Fetches cast (photos, character names) from TMDB to fill in what most
/// Stremio addons don't provide -- they typically send `cast` as plain name
/// strings, no photos. No-ops when the user hasn't configured their own
/// TMDB API key (Settings > TMDB): everything that calls this degrades
/// gracefully to the addon's own name-only cast list.
abstract final class TmdbService {
  static const _baseUrl = 'https://api.themoviedb.org/3';

  /// Fetches the cast for a movie or TV show by its TMDB id. Returns an
  /// empty list if no API key is configured, the id is invalid, or the
  /// request fails -- callers should keep whatever cast data they already
  /// have in that case.
  static Future<List<CastMember>> fetchCast(
    String tmdbId, {
    required bool isTvShow,
  }) async {
    final key = TmdbSettings.apiKey.value;
    if (key == null || tmdbId.isEmpty) return const [];

    final kind = isTvShow ? 'tv' : 'movie';
    final uri = Uri.parse('$_baseUrl/$kind/$tmdbId/credits')
        .replace(queryParameters: {'api_key': key});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body);
      final cast = body is Map ? body['cast'] : null;
      if (cast is! List) return const [];

      return cast
          .whereType<Map>()
          .map((c) => CastMember.fromJson(c.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[TmdbService] fetchCast failed: $e');
      return const [];
    }
  }
}
