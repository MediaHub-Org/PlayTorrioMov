import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../models/subtitle/subtitle_model.dart';
import '../subtitle_extractor.dart';
import '../subtitle_provider.dart';
import '../subtitle_languages.dart';
import 'package:flutter/foundation.dart';

class WyzieProvider extends SubtitleProvider {
  @override
  String get name => 'Wyzie';

  static const String _endpoint = 'https://sub.wyzie.io/search';
  static const String _apiKey = 'wyzie-2q1gc0ypd8mkisqcw0ijt1b9zjytj7ex';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'x-api-key': _apiKey,
    'Authorization': 'Bearer $_apiKey',
  };


  @override
  Future<List<SubtitleVariant>> search(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) async {
    final List<SubtitleVariant> results = [];

    try {
      final queryParams = <String, String>{
        'source': 'all',
        'key': _apiKey,
      };

      if (imdbId != null && imdbId.isNotEmpty) {
        queryParams['id'] = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
      } else {
        queryParams['query'] = movieName;
      }

      if (season != null) queryParams['season'] = season.toString();
      if (episode != null) queryParams['episode'] = episode.toString();

      final uri = Uri.parse(_endpoint).replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return [];

      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      final list = data is List ? data : [];

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final url = map['url']?.toString();
        if (url == null || url.isEmpty) continue;

        final rawLang = (map['language'] ?? map['lang'] ?? 'en').toString().toLowerCase();
        final display = map['display']?.toString();
        final language = display?.isNotEmpty == true
            ? display!
            : subtitleLanguageName(rawLang);

        final release = map['release']?.toString();
        final format = (map['format']?.toString() ?? 'srt').toLowerCase();
        final isHi = map['isHearingImpaired'] == true || map['hi'] == true;

        String title = release?.isNotEmpty == true ? release! : 'Wyzie Subtitle';
        if (isHi) {
          title = '$title [CC]';
        }

        results.add(
          SubtitleVariant(
            providerName: name,
            language: language,
            title: title,
            downloadUrl: url,
            format: format,
            extraData: {
              'encoding': map['encoding'],
              'fps': map['fps'],
              'downloads': map['downloads'],
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[WyzieProvider] search error: $e');
    }

    return results;
  }

  @override
  Future<String?> download(SubtitleVariant variant) async {
    // The same path every other provider uses. This was a hand-rolled
    // request that wrote response bytes straight to a file, which meant a
    // Wyzie subtitle arriving zipped, gzipped, or in anything but UTF-8
    // failed here while the identical file succeeded from OpenSubtitles,
    // Stremio or SubDL -- those go through the extractor, which unpacks
    // archives and normalises the encoding.
    return SubtitleExtractor.downloadAndExtract(
      variant.downloadUrl,
      headers: _headers,
      providerName: name,
    );
  }
}
