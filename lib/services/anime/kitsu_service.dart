import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/anime/anime_media.dart';

/// The anime catalog from Kitsu, a free JSON:API that needs no key.
///
/// AniList switches its API off now and then (every request answers 403), and
/// the anime tab used to be empty for as long as that lasted. While AniList is
/// down, browse, search, details and episode titles come from here.
///
/// The ids this hands out are negative (`-kitsuId`). AniList ids are positive,
/// so a Kitsu title can never be confused with an AniList one in the library or
/// the continue-watching list. The stream sites are keyed by AniList id, so
/// [anilistIdFor] asks Kitsu's own mapping for the AniList id of the same show.
class KitsuService {
  static final KitsuService instance = KitsuService._internal();
  KitsuService._internal();

  static const String _base = 'https://kitsu.io/api/edge';
  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.api+json',
  };
  static const String _anilistSite = 'anilist/anime';

  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<int, int?> _anilistIds = {};

  /// Whether [id] was issued by this service rather than by AniList.
  static bool isKitsuId(int id) => id < 0;

  /// The Kitsu id behind a Kitsu-issued [id].
  static int kitsuIdOf(int id) => -id;

  Future<List<AnimeMedia>> trending({int perPage = 20}) =>
      _list('/anime?sort=-userCount&page[limit]=$perPage&include=categories');

  Future<List<AnimeMedia>> popularThisSeason({int perPage = 20}) => _list(
        '/anime?filter[status]=current&sort=-userCount'
        '&page[limit]=$perPage&include=categories',
      );

  Future<List<AnimeMedia>> upcoming({int perPage = 20}) => _list(
        '/anime?filter[status]=upcoming&sort=-userCount'
        '&page[limit]=$perPage&include=categories',
      );

  Future<List<AnimeMedia>> topRated({int perPage = 20}) =>
      _list('/anime?sort=-averageRating&page[limit]=$perPage&include=categories');

  /// Kitsu files genres as lowercase, hyphenated categories ("slice-of-life").
  Future<List<AnimeMedia>> byGenre(String genre, {int perPage = 20}) {
    final slug = genre.trim().toLowerCase().replaceAll(' ', '-');
    return _list(
      '/anime?filter[categories]=${Uri.encodeQueryComponent(slug)}'
      '&sort=-userCount&page[limit]=$perPage&include=categories',
    );
  }

  Future<List<AnimeMedia>> search(String text, {int perPage = 20}) => _list(
        '/anime?filter[text]=${Uri.encodeQueryComponent(text.trim())}'
        '&page[limit]=$perPage&include=categories',
      );

  /// One title with its genres and its first episodes' titles and art.
  Future<AnimeMedia?> details(int kitsuId) async {
    final body = await _get('/anime/$kitsuId?include=categories');
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return null;
    final categories = _categoryTitles(body);
    final episodes = await episodesOf(kitsuId);
    return _toMedia(data, categories, episodes: episodes);
  }

  /// The first page of episodes: titles and thumbnails, in order.
  Future<List<AnimeStreamingEpisode>> episodesOf(int kitsuId) async {
    final body = await _get(
      '/anime/$kitsuId/episodes?sort=number&page[limit]=20',
    );
    final data = body?['data'];
    if (data is! List) return const [];
    final episodes = <AnimeStreamingEpisode>[];
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final attrs = _map(item['attributes']);
      final number = attrs['number'];
      final title = attrs['canonicalTitle']?.toString() ??
          _map(attrs['titles'])['en']?.toString() ??
          '';
      final thumb = _map(attrs['thumbnail'])['original']?.toString();
      episodes.add(
        AnimeStreamingEpisode(
          number: number is int ? number : int.tryParse('$number'),
          title: title,
          thumbnail: thumb,
        ),
      );
    }
    return episodes;
  }

  /// The AniList id of the show Kitsu has as [kitsuId], or null when Kitsu has
  /// no mapping for it. Cached, including the misses.
  Future<int?> anilistIdFor(int kitsuId) async {
    if (_anilistIds.containsKey(kitsuId)) return _anilistIds[kitsuId];
    final body = await _get('/anime/$kitsuId/mappings?page[limit]=20');
    // A failed request says nothing about the mapping, so it is not cached.
    if (body == null) return null;
    int? found;
    final data = body['data'];
    if (data is List) {
      for (final item in data.whereType<Map<String, dynamic>>()) {
        final attrs = _map(item['attributes']);
        if (attrs['externalSite'] == _anilistSite) {
          found = int.tryParse('${attrs['externalId']}');
          break;
        }
      }
    }
    _anilistIds[kitsuId] = found;
    return found;
  }

  Future<List<AnimeMedia>> _list(String path) async {
    final body = await _get(path);
    final data = body?['data'];
    if (data is! List) return const [];
    final categories = _categoryTitles(body);
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => _toMedia(item, categories))
        .toList();
  }

  /// GET on the Kitsu API, cached per URL. Null on any failure, which the
  /// callers treat as an empty answer, as the AniList reads do.
  Future<Map<String, dynamic>?> _get(String path) async {
    final url = '$_base$path';
    if (_cache.containsKey(url)) return _cache[url];
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('Kitsu API error ${res.statusCode} for $path');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      _cache[url] = decoded;
      return decoded;
    } catch (e) {
      debugPrint('Kitsu API request failed for $path: $e');
      return null;
    }
  }

  /// Category id to its name, from the response's `included` section.
  static Map<String, String> _categoryTitles(Map<String, dynamic>? body) {
    final included = body?['included'];
    if (included is! List) return const {};
    final titles = <String, String>{};
    for (final item in included.whereType<Map<String, dynamic>>()) {
      if (item['type'] != 'categories') continue;
      final title = _map(item['attributes'])['title']?.toString();
      if (title != null && item['id'] != null) {
        titles[item['id'].toString()] = title;
      }
    }
    return titles;
  }

  static AnimeMedia _toMedia(
    Map<String, dynamic> item,
    Map<String, String> categoryTitles, {
    List<AnimeStreamingEpisode> episodes = const [],
  }) {
    final kitsuId = int.parse(item['id'].toString());
    final attrs = _map(item['attributes']);
    final titles = _map(attrs['titles']);
    final poster = _map(attrs['posterImage']);
    final cover = _map(attrs['coverImage']);
    final canonical = attrs['canonicalTitle']?.toString() ?? '';
    final startDate = attrs['startDate']?.toString() ?? '';
    final rating = double.tryParse(attrs['averageRating']?.toString() ?? '');
    final score = rating == null ? 0 : rating.round();

    return AnimeMedia(
      // Negative on purpose: see the class comment.
      id: -kitsuId,
      titleRomaji: canonical,
      titleEnglish: titles['en']?.toString() ?? '',
      titleNative: titles['ja_jp']?.toString() ?? '',
      titleUserPreferred: canonical,
      coverImageExtraLarge: poster['original']?.toString() ?? '',
      coverImageLarge: poster['large']?.toString() ?? poster['original']?.toString() ?? '',
      coverImageMedium: poster['medium']?.toString() ?? poster['small']?.toString() ?? '',
      bannerImage: cover['original']?.toString() ?? '',
      format: (attrs['subtype']?.toString() ?? 'TV').toUpperCase(),
      status: _status(attrs['status']?.toString()),
      totalEpisodes: _int(attrs['episodeCount']),
      durationMinutes: _int(attrs['episodeLength'], fallback: 24),
      genres: _genres(item, categoryTitles),
      averageScore: score,
      meanScore: score,
      seasonYear: startDate.length >= 4 ? (int.tryParse(startDate.substring(0, 4)) ?? 0) : 0,
      description: attrs['synopsis']?.toString() ?? '',
      slug: attrs['slug']?.toString(),
      streamingEpisodes: episodes,
    );
  }

  static List<String> _genres(
    Map<String, dynamic> item,
    Map<String, String> categoryTitles,
  ) {
    final relationships = _map(item['relationships']);
    final categories = _map(relationships['categories'])['data'];
    if (categories is! List) return const [];
    return [
      for (final ref in categories.whereType<Map<String, dynamic>>())
        if (categoryTitles[ref['id']?.toString()] case final title?) title,
    ];
  }

  /// Kitsu's status words, in the words AniList uses for the same states.
  static String _status(String? status) => switch (status) {
        'current' => 'RELEASING',
        'upcoming' || 'unreleased' || 'tba' => 'NOT_YET_RELEASED',
        _ => 'FINISHED',
      };

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }
}
