import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/stream/stream_model.dart';
import '../stream/stream_health_checker.dart';
import '../p2p/p2p_settings_service.dart';
import 'builtin_providers_service.dart';

abstract class StreamScraper {
  String get name;

  /// Stable identity for this provider, used as the persistence key in
  /// [BuiltinProvidersService] and to de-duplicate registration.
  ///
  /// Deliberately **not** [name]: `name` is the label stamped onto every
  /// source a scraper yields ("PlayTorrioHTTP"), which 46 of the built-in
  /// scrapers share -- it identifies the delivery path shown in the source
  /// list, not the site the source came from. `runtimeType` is what
  /// [ScraperManager.registerScraper] has always de-duplicated on, so it is
  /// already the app's real notion of "which scraper is this".
  String get id => runtimeType.toString();

  /// Human-readable provider name for settings UI: the class name with its
  /// `Scraper` suffix dropped (`VidSrcScraper` -> `VidSrc`). Override when
  /// the class name is not what the site calls itself.
  String get displayName {
    final raw = id;
    return raw.endsWith('Scraper')
        ? raw.substring(0, raw.length - 'Scraper'.length)
        : raw;
  }

  /// Whether this scraper reaches a torrent swarm rather than an HTTP host.
  /// The P2P master switch in Settings turns these off as a group, so the
  /// per-provider list marks them and defers to it.
  bool get isTorrent => false;

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

  /// How long one scraper may take before the search stops waiting on it.
  ///
  /// Generous on purpose: the slowest built-in scrapers chain three or four
  /// requests with their own 4-15s timeouts, and cutting a scraper off that
  /// would have answered costs a source. What this is really for is the
  /// scraper that never answers at all.
  static const Duration _scraperDeadline = Duration(seconds: 30);

  final List<StreamScraper> _scrapers = [];
  bool get hasScrapers => _scrapers.isNotEmpty;

  /// Every built-in scraper that has been registered, in registration order.
  ///
  /// This is the list the Built-in Providers settings page renders. It is
  /// generated from what the app actually registered rather than a
  /// hand-maintained roster, so a scraper added to or dropped from
  /// `StreamService.registerBuiltInScrapers` shows up in (or disappears
  /// from) Settings with no second list to update.
  List<StreamScraper> get scrapers => List.unmodifiable(_scrapers);

  void registerScraper(StreamScraper scraper) {
    if (!_scrapers.any((s) => s.runtimeType == scraper.runtimeType)) {
      _scrapers.add(scraper);
    }
  }

  void unregisterTorrentScrapers() {
    _scrapers.removeWhere((s) => s.name == 'PlayTorrio');
  }

  /// Empties the roster. The manager is a singleton, so a test that
  /// registers a fake scraper would otherwise leak it into every test that
  /// runs after it.
  @visibleForTesting
  void resetForTest() => _scrapers.clear();

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
      // Per-provider opt-out. The P2P master switch above still wins for
      // torrent scrapers: turning P2P off silences them whatever this says.
      return BuiltinProvidersService.isEnabled(s.id);
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
    final subscriptions = <StreamSubscription<StreamSource>>[];
    final deadlines = <Timer>[];

    void checkClose() {
      if (pendingScrapers == 0 && inFlightChecks == 0 && !controller.isClosed) {
        controller.close();
      }
    }

    // Nothing downstream is listening any more -- the user closed the source
    // sheet or picked something. Stop the remaining scrapers rather than
    // letting forty-odd HTTP requests finish into a dead controller.
    controller.onCancel = () {
      for (final timer in deadlines) {
        timer.cancel();
      }
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    for (final scraper in activeScrapers) {
      // Each scraper gets a deadline of its own. `pendingScrapers` only fell
      // when a scraper's stream completed, and most scrapers issue HTTP
      // requests with no timeout, so a single host that accepted a
      // connection and then went quiet held `checkClose` off forever: the
      // controller never closed and the picker sat on a spinner even though
      // the other forty-odd scrapers had long since answered.
      var finished = false;
      Timer? deadline;

      void finish() {
        if (finished) return;
        finished = true;
        deadline?.cancel();
        pendingScrapers--;
        checkClose();
      }

      final subscription = scraper
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
        onError: (_) => finish(),
        onDone: finish,
      );

      subscriptions.add(subscription);

      // Only if it is still running: a stream that completed while we were
      // still wiring it up needs no deadline, and arming one would hold a
      // closure alive for thirty seconds to do nothing.
      if (finished) {
        continue;
      }
      deadline = Timer(_scraperDeadline, () {
        if (finished) return;
        debugPrint(
          '[ScraperManager] ${scraper.runtimeType} passed '
          '${_scraperDeadline.inSeconds}s with no result -- dropping it so '
          'the search can finish.',
        );
        subscription.cancel();
        finish();
      });
      deadlines.add(deadline);
    }

    return controller.stream;
  }
}
