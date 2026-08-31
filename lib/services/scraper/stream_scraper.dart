import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/stream/stream_model.dart';
import '../stream/stream_health_checker.dart';
import '../p2p/p2p_settings_service.dart';

abstract class StreamScraper {
  String get name;

  /// Yields sources progressively one-by-one as they are resolved.
  Stream<StreamSource> scrapeStream({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async* {
    final list = await scrape(
      type: type,
      title: title,
      year: year,
      season: season,
      episode: episode,
      imdbId: imdbId,
    );
    for (final s in list) {
      yield s;
    }
  }

  /// Bulk scrape fallback.
  Future<List<StreamSource>> scrape({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async {
    return [];
  }
}

class ScraperManager {
  ScraperManager._internal();
  static final ScraperManager instance = ScraperManager._internal();

  final List<StreamScraper> _scrapers = [];
  bool get hasScrapers => _scrapers.isNotEmpty;

  void registerScraper(StreamScraper scraper) {
    if (!_scrapers.any((s) => s.runtimeType == scraper.runtimeType)) {
      _scrapers.add(scraper);
    }
  }

  void unregisterTorrentScrapers() {
    _scrapers.removeWhere((s) => s.name == 'PlayTorrio');
  }

  Stream<StreamSource> scrapeAll({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) {
    final controller = StreamController<StreamSource>();

    final p2pAllowed = P2pSettingsService.isP2pEnabled.value;
    final activeScrapers = _scrapers.where((s) {
      if (!p2pAllowed && s.name == 'PlayTorrio') {
        return false;
      }
      return true;
    }).toList();

    if (activeScrapers.isEmpty) {
      controller.close();
      return controller.stream;
    }

    debugPrint('[ScraperManager] Scraping across ${activeScrapers.length} active scrapers (${activeScrapers.map((s) => s.runtimeType).join(", ")}) for "$title" (P2P enabled: $p2pAllowed)...');

    int pendingScrapers = activeScrapers.length;
    int inFlightChecks = 0;
    final seenHashes = <String>{};
    final seenUrls = <String>{};

    void checkClose() {
      if (pendingScrapers == 0 && inFlightChecks == 0 && !controller.isClosed) {
        controller.close();
      }
    }

    for (final scraper in activeScrapers) {
      scraper
          .scrapeStream(
        type: type,
        title: title,
        year: year,
        season: season,
        episode: episode,
        imdbId: imdbId,
      )
          .listen(
        (source) {
          if (controller.isClosed) return;

          // If P2P is disabled, strictly discard any torrent source
          if (!p2pAllowed &&
              (source.addonName == 'PlayTorrio' ||
                  (source.infoHash != null && source.infoHash!.isNotEmpty))) {
            return;
          }

          // Torrent sources pass directly with deduplication
          if (source.infoHash != null && source.infoHash!.isNotEmpty) {
            final hashLower = source.infoHash!.toLowerCase();
            if (seenHashes.contains(hashLower)) return;
            seenHashes.add(hashLower);
            controller.add(source);
            return;
          }

          final rawUrl = source.url ?? source.externalUrl;
          if (rawUrl != null && rawUrl.startsWith('http')) {
            if (seenUrls.contains(rawUrl)) return;
            seenUrls.add(rawUrl);

            // Automatically check HTTP/HLS stream health in background
            inFlightChecks++;
            StreamHealthChecker.isAlive(source).then((alive) {
              if (alive && !controller.isClosed) {
                controller.add(source);
              } else if (!alive) {
                debugPrint('[PlayTorrioHTTP] Omitted dead stream: ${source.title} ($rawUrl)');
              }
            }).catchError((_) {
              // Silently drop on error
            }).whenComplete(() {
              inFlightChecks--;
              checkClose();
            });
          } else {
            controller.add(source);
          }
        },
        onError: (_) {},
        onDone: () {
          pendingScrapers--;
          checkClose();
        },
      );
    }

    return controller.stream;
  }
}
