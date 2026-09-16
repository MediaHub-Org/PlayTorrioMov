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

      results.addAll(parseBody(utf8.decode(res.bodyBytes)));
    } catch (e) {
      debugPrint('[WyzieProvider] search error: $e');
    }

    return results;
  }

  /// Reads Wyzie's response into variants.
  ///
  /// Wyzie answers with a bare JSON array rather than the Stremio object, and
  /// spells several fields two ways -- `language`/`lang`, and hearing-impaired
  /// as either `isHearingImpaired` or `hi` -- so both are read. A `display`
  /// string, when it sends one, is already a human-readable language name and
  /// beats looking the code up.
  @visibleForTesting
  static List<SubtitleVariant> parseBody(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      // Not JSON at all; the caller reports an empty search rather than
      // an error the user has to clear.
      return const [];
    }
    if (decoded is! List) return const [];

    final results = <SubtitleVariant>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final url = map['url']?.toString();
      if (url == null || url.isEmpty) continue;

      final rawLang =
          (map['language'] ?? map['lang'] ?? 'en').toString().toLowerCase();
      final display = map['display']?.toString();
      final language = display?.isNotEmpty == true
          ? display!
          : subtitleLanguageName(rawLang);

      final release = map['release']?.toString();
      final isHi = map['isHearingImpaired'] == true || map['hi'] == true;

      var title = release?.isNotEmpty == true ? release! : 'Wyzie Subtitle';
      if (isHi) {
        title = '$title [CC]';
      }

      results.add(
        SubtitleVariant(
          providerName: 'Wyzie',
          language: language,
          title: title,
          downloadUrl: url,
          format: (map['format']?.toString() ?? 'srt').toLowerCase(),
          // The provider's own flag, not a word in the title -- Wyzie is the
          // one provider that says this directly, so it is the one whose
          // answer is trusted over title sniffing.
          isHearingImpaired: isHi,
          extraData: {
            'encoding': map['encoding'],
            'fps': map['fps'],
            'downloads': map['downloads'],
          },
        ),
      );
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
