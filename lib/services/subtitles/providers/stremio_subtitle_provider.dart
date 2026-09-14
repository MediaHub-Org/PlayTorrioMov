import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../models/subtitle/subtitle_model.dart';
import '../../addon/addon_manager.dart';
import '../subtitle_provider.dart';
import '../subtitle_extractor.dart';
import '../subtitle_languages.dart';
import '../subtitle_response.dart';
import 'package:flutter/foundation.dart';

class StremioSubtitleProvider extends SubtitleProvider {
  @override
  String get name => 'Stremio Addon';

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
    String? cleanImdbId = imdbId;
    if (cleanImdbId == null || cleanImdbId.isEmpty) {
      final match = RegExp(r'\b(tt\d{7,8})\b').firstMatch(movieName);
      if (match != null) cleanImdbId = match.group(1);
    }

    if (cleanImdbId == null || cleanImdbId.isEmpty) {
      return [];
    }

    if (!cleanImdbId.startsWith('tt')) {
      cleanImdbId = 'tt$cleanImdbId';
    }

    final isEpisode = season != null && episode != null;
    final type = isEpisode ? 'series' : 'movie';
    final id = isEpisode ? '$cleanImdbId:$season:$episode' : cleanImdbId;

    final List<SubtitleVariant> results = [];
    final activeAddons = AddonManager.instance.activeSubtitleAddons;

    for (final addon in activeAddons) {
      try {
        final url = '${addon.baseUrl}/subtitles/$type/$id.json';
        debugPrint('[StremioSubtitleProvider] Querying ${addon.manifest.name}: $url');
        final res = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final parsed = parseBody(
            utf8.decode(res.bodyBytes),
            addon.manifest.name,
          );
          results.addAll(parsed);
          debugPrint('[StremioSubtitleProvider] ${addon.manifest.name} returned ${parsed.length} subtitles');
        }
      } catch (e) {
        debugPrint('[StremioSubtitleProvider] Error querying ${addon.manifest.name}: $e');
      }
    }

    return results;
  }

  /// Reads one addon's response into variants.
  ///
  /// Unlike OpenSubtitles this keeps whatever name the addon gave the file --
  /// addons are written by strangers and a real release name is more use than
  /// a number. The numbered fallback is for the ones that send no name at all.
  @visibleForTesting
  static List<SubtitleVariant> parseBody(String body, String addonName) {
    final results = <SubtitleVariant>[];
    var idx = 0;
    for (final map in StremioSubtitlesBody.entries(body)) {
      idx++;
      final rawLang = (map['lang'] ?? 'en').toString().toLowerCase();

      final fileTitle = map['subtitleFileName']?.toString() ??
          map['movieReleaseName']?.toString() ??
          map['title']?.toString();
      final title =
          fileTitle?.isNotEmpty == true ? fileTitle! : '$addonName #$idx';

      // An addon that does not declare SubFormat usually named the file, so
      // the extension is the next best evidence of what it sent.
      final format = (map['SubFormat']?.toString() ??
              (title.toLowerCase().endsWith('.vtt') ? 'vtt' : 'srt'))
          .toLowerCase();

      results.add(
        SubtitleVariant(
          providerName: addonName,
          language: subtitleLanguageName(rawLang),
          title: title,
          downloadUrl: map['url']!.toString(),
          format: format,
          extraData: {
            'id': map['id'],
            'subEncoding': map['SubEncoding'],
            'fpsMilli': map['fpsMilli'],
            'releaseGroup': map['releaseGroup'],
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
      providerName: variant.providerName,
    );
  }
}
