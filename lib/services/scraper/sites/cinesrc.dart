import 'dart:async';
import 'package:flutter/foundation.dart';
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import 'tmdb_helper.dart';
import '../user_agent.dart';
import 'glendale_master_url.dart';

/// Pure-Dart CineSrc Stream Scraper for PlayTorrioHTTP.
///
/// Ported 1-to-1 from Vyla CineSrc provider.
/// Generates direct master HLS playlists and fetches bright67 subtitles.
class CineSrcScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';

  static const _ua =
      kDefaultUA;

  @override
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    final isTv = (type == 'tv' || type == 'series');
    final mediaType = isTv ? 'tv' : 'movie';

    try {
      final tmdbId = await TmdbHelper.resolveTmdbId(
        imdbId: imdbId,
        title: title,
        type: mediaType,
        year: year,
      );

      if (tmdbId == null) {
        if (kDebugMode) debugPrint('[CineSrcScraper] Could not resolve TMDB ID for "$title"');
        return;
      }

      final streamUrl =
          '${glendaleMasterUrl(tmdbId, season, episode)}?$glendaleVersionParam';

      final headers = {
        'User-Agent': _ua,
        'Referer': 'https://cinesrc.st/',
        'Origin': 'https://cinesrc.st',
      };

      yield StreamSource(
        name: 'PlayTorrioHTTP',
        addonName: 'PlayTorrioHTTP',
        title: 'CineSrc · Direct Master · 1080p',
        description: 'CineSrc Direct Master HLS Stream',
        url: streamUrl,
        headers: headers,
        behaviorHints: {
          'notWebReady': false,
          'proxyHeaders': {
            'request': headers,
          },
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CineSrcScraper] error: $e');
    }
  }
}
