import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../scraper/sites/dulo_client.dart';

class DuloAnimeResult {
  final String url;
  final String title;
  final String quality;
  final Map<String, String> headers;

  DuloAnimeResult({
    required this.url,
    required this.title,
    required this.quality,
    required this.headers,
  });
}

/// Anime stream extractor utilizing Dulo's native AniList source endpoint.
class DuloExtractor {
  static final DuloExtractor instance = DuloExtractor._internal();
  DuloExtractor._internal();

  /// Extracts all active HLS streams from Dulo for an AniList Anime ID and Episode.
  Future<List<DuloAnimeResult>> extract({
    required int anilistId,
    required int episodeNumber,
  }) async {
    final results = <DuloAnimeResult>[];

    try {
      final stream = DuloClient.instance.getAnimeStreams(anilistId, episodeNumber);
      await for (final s in stream) {
        if (s.url.isNotEmpty && s.url.startsWith('http')) {
          results.add(DuloAnimeResult(
            url: s.url,
            title: s.title.isNotEmpty ? s.title : 'Source',
            quality: s.quality.isNotEmpty && s.quality != 'Auto' ? s.quality : '1080p',
            headers: DuloClient.instance.playbackHeaders,
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DuloExtractor] extraction error: $e');
    }

    return results;
  }
}
