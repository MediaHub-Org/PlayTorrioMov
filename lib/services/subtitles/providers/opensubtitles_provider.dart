import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../models/subtitle/subtitle_model.dart';
import '../subtitle_provider.dart';
import '../subtitle_extractor.dart';
import '../subtitle_languages.dart';
import '../subtitle_response.dart';

class OpenSubtitlesProvider extends SubtitleProvider {
  @override
  String get name => 'OpenSubtitles';

  static const List<String> _endpoints = [
    'https://opensubtitles.stremio.homes',
    'https://opensubtitles-v3.strem.io',
    'https://opensubtitles.strem.io',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };


  @override
  Future<List<SubtitleVariant>> search(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) async {
    if (imdbId == null || imdbId.isEmpty) {
      return [];
    }

    final cleanImdbId = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
    final isEpisode = season != null && episode != null;
    final type = isEpisode ? 'series' : 'movie';
    final id = isEpisode ? '$cleanImdbId:$season:$episode' : cleanImdbId;

    final List<SubtitleVariant> results = [];
    final Set<String> seenUrls = {};

    for (final base in _endpoints) {
      try {
        final url = '$base/subtitles/$type/$id.json';
        final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          results.addAll(parseBody(utf8.decode(res.bodyBytes), seenUrls));

          if (results.isNotEmpty) {
            break; // First responding endpoint with subs is enough
          }
        }
      } catch (e) {
        // Fallback to next endpoint
      }
    }

    return results;
  }

  /// Reads one endpoint's response into variants.
  ///
  /// [seenUrls] carries across endpoints: the three hosts below are mirrors of
  /// each other, so the same subtitle can come back twice, and the numbering
  /// in the titles should not count it twice either.
  @visibleForTesting
  static List<SubtitleVariant> parseBody(String body, Set<String> seenUrls) {
    final results = <SubtitleVariant>[];
    var idx = 0;
    for (final map in StremioSubtitlesBody.entries(body)) {
      final subUrl = map['url']!.toString();
      if (!seenUrls.add(subUrl)) continue;
      idx++;

      final rawLang = (map['lang'] ?? 'en').toString().toLowerCase();
      results.add(
        SubtitleVariant(
          providerName: 'OpenSubtitles',
          language: subtitleLanguageName(rawLang),
          title: 'OpenSubtitles #$idx',
          downloadUrl: subUrl,
          format: (map['SubFormat']?.toString() ?? 'srt').toLowerCase(),
          extraData: {
            'id': map['id'],
            'fps': map['fps'],
          },
        ),
      );
    }
    return results;
  }

  @override
  Future<String?> download(SubtitleVariant variant) async {
    return SubtitleExtractor.downloadAndExtract(
      variant.downloadUrl,
      headers: _headers,
      providerName: name,
    );
  }
}
