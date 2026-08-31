import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/addon/addon.dart';
import '../../models/stream/stream_model.dart';
import '../addon/addon_manager.dart';
import '../scraper/stream_scraper.dart';
import '../scraper/sites/knaben.dart';
import '../scraper/sites/torrent_galaxy.dart';
import '../scraper/sites/fourkhdhub.dart';
import '../scraper/sites/xdownloader.dart';
import '../scraper/sites/videasy.dart';
import '../scraper/sites/vidsrc.dart';
import '../scraper/sites/multiembed.dart';
import '../scraper/sites/vidcore.dart';
import '../scraper/sites/flystream.dart';
import '../scraper/sites/movienight.dart';
import '../scraper/sites/downloadeverything.dart';
import '../scraper/sites/movy.dart';
import '../scraper/sites/vuflix.dart';
import '../scraper/sites/rivestream.dart';
import '../scraper/sites/cinejoy.dart';
import '../scraper/sites/a111477.dart';
import '../scraper/sites/vadapav.dart';
import '../anime/anime_scraper_service.dart';
import '../anime_arabic/anime_arabic_service.dart';
import '../anime_arabic/anime_arabic_extractor.dart';
import '../p2p/p2p_settings_service.dart';

/// Service that fetches playback streams from all installed Stremio addons
/// and built-in scrapers.
class StreamService {
  StreamService._();

  static void _registerBuiltInScrapers() {
    if (P2pSettingsService.isP2pEnabled.value) {
      ScraperManager.instance.registerScraper(KnabenScraper());
      ScraperManager.instance.registerScraper(TorrentGalaxyScraper());
    } else {
      ScraperManager.instance.unregisterTorrentScrapers();
    }
    ScraperManager.instance.registerScraper(A111477Scraper());
    ScraperManager.instance.registerScraper(VadapavScraper());
    ScraperManager.instance.registerScraper(FourKHDHubScraper());
    ScraperManager.instance.registerScraper(XDownloaderScraper());
    ScraperManager.instance.registerScraper(VideasyScraper());
    ScraperManager.instance.registerScraper(VidSrcScraper());
    ScraperManager.instance.registerScraper(MultiEmbedScraper());
    ScraperManager.instance.registerScraper(VidCoreScraper());
    ScraperManager.instance.registerScraper(FlyStreamScraper());
    ScraperManager.instance.registerScraper(MovieNightScraper());
    ScraperManager.instance.registerScraper(DownloadEverythingScraper());
    ScraperManager.instance.registerScraper(MovyScraper());
    ScraperManager.instance.registerScraper(VuflixScraper());
    ScraperManager.instance.registerScraper(RiveStreamScraper());
    ScraperManager.instance.registerScraper(CinejoyScraper());
  }

  /// Fetches streams from all active stream-capable addons for the given
  /// content type and ID.
  static Stream<StreamSource> fetchStreams({
    required String type,
    required String id,
    required String title,
    int? year,
    int? season,
    int? episode,
  }) {
    final controller = StreamController<StreamSource>();

    final addons = AddonManager.instance.activeStreamAddons;

    _registerBuiltInScrapers();

    int pending = addons.length + 1; // addons + local scrapers

    // Local scrapers
    final isImdb = id.startsWith('tt');
    final cleanImdbId = isImdb ? id.split(':')[0] : null;

    ScraperManager.instance.scrapeAll(
      type: type,
      title: title,
      year: year,
      season: season,
      episode: episode,
      imdbId: cleanImdbId,
    ).listen((source) {
      if (!controller.isClosed) controller.add(source);
    }, onDone: () {
      pending--;
      if (pending == 0 && !controller.isClosed) controller.close();
    });

    for (final addon in addons) {
      _fetchFromAddon(addon, type, id).then((sources) {
        if (!controller.isClosed) {
          for (final source in sources) {
            controller.add(source);
          }
        }
      }).catchError((_) {}).whenComplete(() {
        pending--;
        if (pending == 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    return controller.stream;
  }

  /// Fetches streams specifically for a targeted provider/addon that was previously used by the user.
  ///
  /// - If [targetAddonName] == 'PlayTorrioHTTP': Only scrapes built-in alive HTTP scrapers.
  /// - If [targetAddonName] == 'PlayTorrio': Only scrapes built-in torrent scrapers.
  /// - If [targetAddonName] matches a Stremio addon (e.g. 'Torrentio', 'CyberFlix'): Only calls that specific addon.
  static Stream<StreamSource> fetchStreamsForTargetAddon({
    required String targetAddonName,
    required String type,
    required String id,
    required String title,
    int? year,
    int? season,
    int? episode,
  }) {
    final controller = StreamController<StreamSource>();
    final normalizedTarget = targetAddonName.trim().toLowerCase();

    final isArabicAnime = id.startsWith('arabic_anime:') ||
        normalizedTarget == 'arabicanime' ||
        normalizedTarget.contains('arabic');

    if (isArabicAnime) {
      () async {
        try {
          String slug = '';
          if (id.startsWith('arabic_anime:')) {
            final parts = id.split(':');
            if (parts.length >= 2) slug = parts[1];
          } else if (id.isNotEmpty) {
            slug = id;
          }
          if (slug.isEmpty && title.isNotEmpty) {
            final searchResults = await AnimeArabicService.instance.search(title);
            if (searchResults.isNotEmpty) {
              slug = searchResults.first.slug;
            }
          }
          final epNum = episode ?? 1;
          if (slug.isNotEmpty) {
            final details = await AnimeArabicService.instance.getDetails(slug);
            final targetEp = details.episodes.firstWhere(
              (e) => e.number == epNum,
              orElse: () => ArabicEpisode(
                number: epNum,
                title: 'الحلقة $epNum',
                encodedHref: '',
                watchPath: '/e/$slug-$epNum#tok',
              ),
            );
            final hits = await AnimeArabicExtractor.instance.resolveEpisode(targetEp);
            final sources = AnimeArabicExtractor.toSources(
              hits,
              animeTitle: details.title,
              episodeNumber: epNum,
            );
            for (final s in sources) {
              if (!controller.isClosed) controller.add(s);
            }
          }
        } catch (_) {}
        if (!controller.isClosed) controller.close();
      }();
      return controller.stream;
    }

    // Check if targeting general anime providers
    final isAnime = type == 'anime' ||
        id.startsWith('anilist:') ||
        normalizedTarget == 'megaplay' ||
        normalizedTarget == 'anidb' ||
        normalizedTarget == 'watchhentai' ||
        normalizedTarget == 'hentaini' ||
        normalizedTarget == 'anime';

    if (isAnime) {
      int? anilistId;
      if (id.startsWith('anilist:')) {
        final parts = id.split(':');
        if (parts.length >= 2) {
          anilistId = int.tryParse(parts[1]);
        }
      }
      return AnimeScraperService.instance.scrapeStreamsByDetails(
        title: title,
        anilistId: anilistId,
        episodeNumber: episode ?? 1,
      );
    }

    // Check if targeting built-in PlayTorrioHTTP / PlayTorrio
    final isLocalPlayTorrio = normalizedTarget == 'playtorriohttp' ||
        normalizedTarget == 'playtorrio' ||
        normalizedTarget.contains('playtorrio');

    if (isLocalPlayTorrio) {
      _registerBuiltInScrapers();

      final isImdb = id.startsWith('tt');
      final cleanImdbId = isImdb ? id.split(':')[0] : null;

      ScraperManager.instance.scrapeAll(
        type: type,
        title: title,
        year: year,
        season: season,
        episode: episode,
        imdbId: cleanImdbId,
      ).listen(
        (source) {
          if (!controller.isClosed) {
            // If target was specifically PlayTorrioHTTP, only yield HTTP streams
            if (normalizedTarget == 'playtorriohttp' &&
                (source.infoHash != null && source.infoHash!.isNotEmpty)) {
              return;
            }
            // If target was specifically PlayTorrio (torrent), only yield torrent streams
            if (normalizedTarget == 'playtorrio' &&
                (source.infoHash == null || source.infoHash!.isEmpty)) {
              return;
            }
            controller.add(source);
          }
        },
        onError: (_) {},
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );

      return controller.stream;
    }

    // Otherwise, find the matching Stremio addon
    final matchingAddons = AddonManager.instance.activeStreamAddons.where(
      (a) =>
          a.manifest.name.toLowerCase() == normalizedTarget ||
          a.manifest.name.toLowerCase().contains(normalizedTarget) ||
          normalizedTarget.contains(a.manifest.name.toLowerCase()),
    ).toList();

    if (matchingAddons.isNotEmpty) {
      final matchingAddon = matchingAddons.first;
      _fetchFromAddon(matchingAddon, type, id).then((sources) {
        if (!controller.isClosed) {
          for (final source in sources) {
            controller.add(source);
          }
        }
      }).catchError((_) {}).whenComplete(() {
        if (!controller.isClosed) controller.close();
      });
    } else {
      // Fallback: If no exact addon match found, run general fetch
      return fetchStreams(
        type: type,
        id: id,
        title: title,
        year: year,
        season: season,
        episode: episode,
      );
    }

    return controller.stream;
  }

  static Future<List<StreamSource>> _fetchFromAddon(
    InstalledAddon addon,
    String type,
    String id,
  ) async {
    try {
      // Check idPrefixes filtering if declared by addon
      if (addon.manifest.idPrefixes.isNotEmpty) {
        final matchesPrefix = addon.manifest.idPrefixes.any((p) => id.startsWith(p));
        if (!matchesPrefix) return [];
      }

      // Check types filtering if declared by addon
      if (addon.manifest.types.isNotEmpty) {
        final matchesType = addon.manifest.types.contains(type);
        if (!matchesType) return [];
      }

      final pathId = Uri.encodeComponent(id);
      final url = '${addon.baseUrl}/stream/$type/$pathId.json';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final streams = data['streams'] as List<dynamic>?;

      if (streams == null || streams.isEmpty) return [];

      return streams
          .whereType<Map>()
          .map((json) => StreamSource.fromJson(Map<String, dynamic>.from(json), addon.manifest.name))
          .where((s) => s.url != null || s.infoHash != null || s.externalUrl != null)
          .toList();
    } catch (e, st) {
      debugPrint('Addon ${addon.manifest.name} failed: $e\n$st');
      return [];
    }
  }
}
