import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../models/subtitle/subtitle_model.dart';
import '../subtitle_provider.dart';
import '../subtitle_extractor.dart';

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

  static const Map<String, String> _iso3ToLangName = {
    'ara': 'Arabic',
    'ar': 'Arabic',
    'eng': 'English',
    'en': 'English',
    'spa': 'Spanish',
    'es': 'Spanish',
    'fre': 'French',
    'fra': 'French',
    'fr': 'French',
    'ger': 'German',
    'deu': 'German',
    'de': 'German',
    'ita': 'Italian',
    'it': 'Italian',
    'jpn': 'Japanese',
    'ja': 'Japanese',
    'kor': 'Korean',
    'ko': 'Korean',
    'rus': 'Russian',
    'ru': 'Russian',
    'por': 'Portuguese',
    'pt': 'Portuguese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'zh': 'Chinese',
    'hin': 'Hindi',
    'hi': 'Hindi',
    'tur': 'Turkish',
    'tr': 'Turkish',
    'ind': 'Indonesian',
    'id': 'Indonesian',
    'vie': 'Vietnamese',
    'vi': 'Vietnamese',
    'tha': 'Thai',
    'th': 'Thai',
    'pol': 'Polish',
    'pl': 'Polish',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'nl': 'Dutch',
    'swe': 'Swedish',
    'sv': 'Swedish',
    'nor': 'Norwegian',
    'no': 'Norwegian',
    'dan': 'Danish',
    'da': 'Danish',
    'fin': 'Finnish',
    'fi': 'Finnish',
    'heb': 'Hebrew',
    'he': 'Hebrew',
    'ces': 'Czech',
    'cs': 'Czech',
    'ell': 'Greek',
    'el': 'Greek',
    'hun': 'Hungarian',
    'hu': 'Hungarian',
    'ron': 'Romanian',
    'ro': 'Romanian',
    'ukr': 'Ukrainian',
    'uk': 'Ukrainian',
    'per': 'Persian',
    'fas': 'Persian',
    'fa': 'Persian',
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
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final subsList = data['subtitles'] as List?;
          if (subsList == null || subsList.isEmpty) continue;

          int idx = 0;
          for (final item in subsList) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final subUrl = map['url']?.toString();
            if (subUrl == null || subUrl.isEmpty || seenUrls.contains(subUrl)) continue;

            seenUrls.add(subUrl);
            idx++;

            final rawLang = (map['lang'] ?? 'en').toString().toLowerCase();
            final language = _iso3ToLangName[rawLang] ?? (rawLang.length <= 3 ? rawLang.toUpperCase() : rawLang);
            final format = (map['SubFormat']?.toString() ?? 'srt').toLowerCase();

            results.add(
              SubtitleVariant(
                providerName: name,
                language: language,
                title: 'OpenSubtitles #$idx',
                downloadUrl: subUrl,
                format: format,
                extraData: {
                  'id': map['id'],
                  'fps': map['fps'],
                },
              ),
            );
          }

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

  @override
  Future<String?> download(SubtitleVariant variant) async {
    return SubtitleExtractor.downloadAndExtract(
      variant.downloadUrl,
      headers: _headers,
      providerName: name,
    );
  }
}
