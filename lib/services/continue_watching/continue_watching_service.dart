import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/anime/anime_media.dart';
import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';
import '../../models/stream/stream_model.dart';
import '../../pages/anime/anime_stream_sheet.dart';
import '../../pages/anime_arabic/anime_arabic_details_page.dart';
import '../../pages/player/player_screen.dart';
import '../../pages/player/watch_screen.dart';
import '../../services/anime/anime_scraper_service.dart';
import '../../services/anime_arabic/anime_arabic_service.dart';
import '../../services/anime_arabic/anime_arabic_extractor.dart';
import '../../services/stream/stream_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../trakt/trakt_service.dart';
import '../trakt/trakt_continue_watching_service.dart';
import '../simkl/simkl_service.dart';
import '../simkl/simkl_continue_watching_service.dart';

class ContinueWatchingService {
  static const _storageKey = 'continue_watching_sessions_v1';
  static const _historyStorageKey = 'continue_watching_history_v1';
  static const int _maxHistoryItems = 100;

  static final ValueNotifier<List<ContinueWatchingItem>> activeItems =
      ValueNotifier<List<ContinueWatchingItem>>([]);

  /// Every saved session, keyed per-episode (not deduped per-show) and never
  /// purged when finished -- a full watch log, unlike [activeItems] which is
  /// "pick up where you left off" only. Powers the Watch hub Library's
  /// History tab.
  static final ValueNotifier<List<ContinueWatchingItem>> historyItems =
      ValueNotifier<List<ContinueWatchingItem>>([]);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final list = jsonDecode(rawJson) as List<dynamic>;
        final rawItems = list
            .whereType<Map<String, dynamic>>()
            .map((j) => ContinueWatchingItem.fromJson(j))
            .where((item) => !item.isCompleted && item.positionSeconds > 10)
            .toList();

        // Sort by most recent
        rawItems.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

        // Deduplicate by show/movie ID (keep only the latest episode per show)
        final deduped = <String, ContinueWatchingItem>{};
        for (final item in rawItems) {
          final existing = deduped[item.sessionKey];
          if (existing == null) {
            deduped[item.sessionKey] = item;
          } else if (item.episodeIndex > existing.episodeIndex) {
            deduped[item.sessionKey] = item;
          }
        }

        final items = deduped.values.toList();
        items.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
        activeItems.value = items;
      }

      final rawHistoryJson = prefs.getString(_historyStorageKey);
      if (rawHistoryJson != null && rawHistoryJson.isNotEmpty) {
        final list = jsonDecode(rawHistoryJson) as List<dynamic>;
        final items = list
            .whereType<Map<String, dynamic>>()
            .map((j) => ContinueWatchingItem.fromJson(j))
            .toList();
        items.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
        historyItems.value = items;
      }
    } catch (e) {
      debugPrint('[ContinueWatchingService] Failed to load sessions: $e');
    }

    // Sync cloud items in background
    syncCloudSessions();
  }

  /// Unique per-episode key for the full history log (as opposed to
  /// [ContinueWatchingItem.sessionKey], which is per-show).
  static String _historyKeyOf(ContinueWatchingItem item) => item.episodeId ?? item.id;

  static Future<void> _saveHistoryItem(ContinueWatchingItem item) async {
    if (item.positionSeconds < 5) return;
    final current = List<ContinueWatchingItem>.from(historyItems.value);
    current.removeWhere((i) => _historyKeyOf(i) == _historyKeyOf(item));
    current.insert(0, item);
    current.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    final trimmed = current.take(_maxHistoryItems).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      historyItems.value = trimmed;
    });
    WidgetsBinding.instance.scheduleFrame();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = trimmed.map((e) => e.toJson()).toList();
      await prefs.setString(_historyStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ContinueWatchingService] Failed to persist history: $e');
    }
  }

  /// Looks up a saved position by the same per-episode key [_saveHistoryItem]
  /// stores under -- used to resume playback when opening the player from
  /// any entry point other than the Continue Watching row.
  static ContinueWatchingItem? getHistoryProgress(String itemId) {
    for (final item in historyItems.value) {
      if (_historyKeyOf(item) == itemId) return item;
    }
    return null;
  }

  /// Removes a single entry from the History tab log (does not affect
  /// [activeItems]/the Home page's Continue Watching row).
  static Future<void> removeHistoryItem(ContinueWatchingItem item) async {
    final current = List<ContinueWatchingItem>.from(historyItems.value);
    current.removeWhere((i) => _historyKeyOf(i) == _historyKeyOf(item));
    historyItems.value = current;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = current.map((e) => e.toJson()).toList();
      await prefs.setString(_historyStorageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ContinueWatchingService] Failed to remove history item: $e');
    }
  }

  /// Syncs continue watching entries from Trakt and Simkl
  static Future<void> syncCloudSessions() async {
    try {
      final cloudItems = <ContinueWatchingItem>[];

      // 1. Trakt Continue Watching
      if (await TraktService.instance.isAuthenticated()) {
        try {
          final traktMovies = await TraktContinueWatchingService.instance.fetchMovies();
          for (final tm in traktMovies) {
            final progress = (tm.progress ?? 0) / 100.0;
            final durationSeconds = (tm.runtime != null && tm.runtime! > 0) ? tm.runtime! * 60 : 7200;
            final posSec = (progress * durationSeconds).toInt();
            cloudItems.add(ContinueWatchingItem(
              id: tm.id,
              title: tm.title,
              type: 'movie',
              posterUrl: tm.posterUrl,
              backdropUrl: tm.meta.background,
              year: tm.year,
              positionSeconds: posSec > 0 ? posSec : 1,
              totalDurationSeconds: durationSeconds,
              lastWatchedAt: tm.pausedAtMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(tm.pausedAtMs!)
                  : DateTime.now(),
              isTorrent: false,
            ));
          }

          final traktShows = await TraktContinueWatchingService.instance.fetchShows();
          for (final ts in traktShows) {
            final progress = (ts.progress ?? 0) / 100.0;
            final durationSeconds = (ts.runtime != null && ts.runtime! > 0) ? ts.runtime! * 60 : 2700;
            final posSec = (progress * durationSeconds).toInt();
            cloudItems.add(ContinueWatchingItem(
              id: ts.id,
              title: ts.title,
              type: 'series',
              posterUrl: ts.posterUrl,
              backdropUrl: ts.meta.background,
              year: ts.year,
              season: ts.season,
              episode: ts.episode,
              positionSeconds: posSec > 0 ? posSec : 1,
              totalDurationSeconds: durationSeconds,
              lastWatchedAt: ts.pausedAtMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(ts.pausedAtMs!)
                  : DateTime.now(),
              isTorrent: false,
            ));
          }
        } catch (e) {
          debugPrint('[ContinueWatchingService] Trakt sync error: $e');
        }
      }

      // 2. Simkl Continue Watching
      if (await SimklService.instance.isAuthenticated()) {
        try {
          final simklRes = await SimklContinueWatchingService.instance.fetchItems();
          if (simklRes != null) {
            for (final sm in simklRes.movies) {
              final progress = (sm.progress ?? 0) / 100.0;
              const durationSeconds = 7200;
              final posSec = (progress * durationSeconds).toInt();
              cloudItems.add(ContinueWatchingItem(
                id: sm.id,
                title: sm.meta.name,
                type: 'movie',
                posterUrl: sm.meta.poster,
                backdropUrl: sm.meta.background,
                year: sm.meta.year,
                positionSeconds: posSec > 0 ? posSec : 1,
                totalDurationSeconds: durationSeconds,
                lastWatchedAt: sm.pausedAtMs != null
                    ? DateTime.fromMillisecondsSinceEpoch(sm.pausedAtMs!)
                    : DateTime.now(),
                isTorrent: false,
              ));
            }

            for (final ss in simklRes.shows) {
              final progress = (ss.progress ?? 0) / 100.0;
              const durationSeconds = 2700;
              final posSec = (progress * durationSeconds).toInt();
              cloudItems.add(ContinueWatchingItem(
                id: ss.id,
                title: ss.meta.name,
                type: 'series',
                posterUrl: ss.meta.poster,
                backdropUrl: ss.meta.background,
                year: ss.meta.year,
                season: ss.season,
                episode: ss.episode,
                positionSeconds: posSec > 0 ? posSec : 1,
                totalDurationSeconds: durationSeconds,
                lastWatchedAt: ss.pausedAtMs != null
                    ? DateTime.fromMillisecondsSinceEpoch(ss.pausedAtMs!)
                    : DateTime.now(),
                isTorrent: false,
              ));
            }
          }
        } catch (e) {
          debugPrint('[ContinueWatchingService] Simkl sync error: $e');
        }
      }

      if (cloudItems.isEmpty) return;

      // Merge with local active items
      final existingMap = {for (final item in activeItems.value) item.sessionKey: item};
      for (final cloudItem in cloudItems) {
        final local = existingMap[cloudItem.sessionKey];
        if (local == null) {
          existingMap[cloudItem.sessionKey] = cloudItem;
        } else {
          // If cloud is newer and higher episode, advance to the new episode
          if (cloudItem.episodeIndex > local.episodeIndex ||
              (cloudItem.episodeIndex == local.episodeIndex &&
                  cloudItem.lastWatchedAt.isAfter(local.lastWatchedAt))) {
            existingMap[cloudItem.sessionKey] = cloudItem;
          }
        }
      }

      final merged = existingMap.values.where((i) => !i.isCompleted).toList();
      merged.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        activeItems.value = merged;
      });
      WidgetsBinding.instance.scheduleFrame();
    } catch (e) {
      debugPrint('[ContinueWatchingService] Cloud sync error: $e');
    }
  }

  /// Saves or updates the playback progress for a session.
  /// Automatically purges finished media (>= 90% watched).
  /// Enforces only 1 single card per show, tracking the latest episode.
  static Future<void> saveProgress({
    required MovieDetail detail,
    Video? episode,
    required StreamSource source,
    required int positionSeconds,
    required int totalDurationSeconds,
  }) async {
    if (positionSeconds < 5 || totalDurationSeconds <= 0) return;

    final progress = positionSeconds / totalDurationSeconds;
    final isFinished = progress >= 0.90;

    final isTorrent = (source.infoHash != null && source.infoHash!.isNotEmpty) ||
        (source.url != null && source.url!.startsWith('magnet:'));

    String? magnetUrl;
    if (isTorrent) {
      if (source.url != null && source.url!.startsWith('magnet:')) {
        magnetUrl = source.url;
      } else if (source.infoHash != null && source.infoHash!.isNotEmpty) {
        magnetUrl = 'magnet:?xt=urn:btih:${source.infoHash}';
        if (source.sources != null) {
          for (final tr in source.sources!) {
            if (tr.startsWith('tracker:')) {
              final tracker = tr.replaceFirst('tracker:', '');
              magnetUrl = '$magnetUrl&tr=${Uri.encodeComponent(tracker)}';
            }
          }
        }
      }
    }

    final newItem = ContinueWatchingItem(
      id: detail.id,
      title: detail.name,
      type: detail.type,
      posterUrl: detail.poster,
      backdropUrl: detail.background,
      year: detail.year,
      season: episode?.season,
      episode: episode?.episode,
      episodeTitle: episode?.title,
      episodeId: episode?.id,
      streamName: source.name,
      streamTitle: source.displayTitle,
      addonName: source.addonName,
      quality: source.quality,
      isTorrent: isTorrent,
      rawUrl: source.url,
      infoHash: source.infoHash,
      fileIdx: source.fileIdx,
      positionSeconds: positionSeconds,
      totalDurationSeconds: totalDurationSeconds,
      lastWatchedAt: DateTime.now(),
    );

    // Read current list
    final current = List<ContinueWatchingItem>.from(activeItems.value);

    // Remove any existing entry for this show/movie
    current.removeWhere((i) => i.sessionKey == newItem.sessionKey);

    // Only insert if not finished (>= 90% watched)
    if (!isFinished) {
      current.insert(0, newItem);
    }

    // Sort newest first
    current.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

    // Limit to max 50 stored sessions
    final trimmed = current.take(50).toList();

    // Schedule notification safely after current frame. scheduleFrame() is
    // required alongside addPostFrameCallback -- the callback only runs when
    // a frame actually happens, and nothing guarantees one is already
    // pending at this point (e.g. a static screen with no other rebuilds).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      activeItems.value = trimmed;
    });
    WidgetsBinding.instance.scheduleFrame();

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = trimmed.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ContinueWatchingService] Failed to persist session: $e');
    }

    // Full history log: every episode/movie, never purged when finished --
    // unlike activeItems above, which is deduped per-show and drops
    // finished items.
    _saveHistoryItem(newItem);

    // Push cloud scrobble / history to Trakt and Simkl
    _syncCloudPlayback(
      detail: detail,
      episode: episode,
      progressPercent: (progress * 100.0).clamp(0.0, 100.0),
      isFinished: isFinished,
    );
  }

  static DateTime? _lastCloudScrobbleTime;
  static String? _lastCloudScrobbleKey;

  static void _syncCloudPlayback({
    required MovieDetail detail,
    Video? episode,
    required double progressPercent,
    required bool isFinished,
  }) async {
    final imdbId = detail.id.startsWith('tt') ? detail.id : '';
    final targetId = imdbId.isNotEmpty ? imdbId : (detail.tmdbId ?? detail.id);
    if (targetId.isEmpty) return;

    final season = episode?.season;
    final epNum = episode?.episode;
    final type = detail.type;

    // Rate limit periodic scrobbles to once every 20s unless finished
    final currentKey = '$targetId:$season:$epNum';
    final now = DateTime.now();
    if (!isFinished &&
        _lastCloudScrobbleKey == currentKey &&
        _lastCloudScrobbleTime != null &&
        now.difference(_lastCloudScrobbleTime!) < const Duration(seconds: 20)) {
      return;
    }
    _lastCloudScrobbleTime = now;
    _lastCloudScrobbleKey = currentKey;

    // 1. Trakt Playback Scrobble / History
    if (await TraktService.instance.isAuthenticated()) {
      try {
        if (isFinished) {
          await TraktService.instance.scrobbleStop(
            targetId,
            100.0,
            season: season,
            episode: epNum,
          );
          await TraktService.instance.addToHistory(targetId, type);
        } else {
          await TraktService.instance.scrobblePause(
            targetId,
            progressPercent,
            season: season,
            episode: epNum,
          );
        }
      } catch (e) {
        debugPrint('[ContinueWatchingService] Trakt cloud scrobble error: $e');
      }
    }

    // 2. Simkl Playback Scrobble / History
    if (await SimklService.instance.isAuthenticated()) {
      try {
        if (isFinished) {
          await SimklService.instance.scrobbleStop(
            targetId,
            100.0,
            season: season,
            episode: epNum,
          );
          if (type == 'series' && season != null && epNum != null) {
            await SimklService.instance.markEpisodeWatched(targetId, season, epNum);
          } else {
            await SimklService.instance.markWatched(targetId, type);
          }
        } else {
          await SimklService.instance.scrobblePause(
            targetId,
            progressPercent,
            season: season,
            episode: epNum,
          );
        }
      } catch (e) {
        debugPrint('[ContinueWatchingService] Simkl cloud scrobble error: $e');
      }
    }
  }

  /// Removes an item completely from continue watching locally and removes
  /// its playback session & tracking state from Trakt and Simkl in the background.
  static Future<void> removeItem(ContinueWatchingItem item) async {
    final current = List<ContinueWatchingItem>.from(activeItems.value);
    current.removeWhere((i) => i.sessionKey == item.sessionKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      activeItems.value = current;
    });
    WidgetsBinding.instance.scheduleFrame();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = current.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ContinueWatchingService] Failed to remove session: $e');
    }

    // Cloud Removal (Trakt & Simkl)
    _removeCloudSession(item);
  }

  static void _removeCloudSession(ContinueWatchingItem item) async {
    final rawId = item.id;
    if (rawId.startsWith('anilist:')) return;

    final baseId = rawId.contains(':') ? rawId.split(':').first : rawId;
    if (baseId.isEmpty) return;

    final type = item.type;
    final isSeries = type == 'series' || type == 'show' || type == 'shows';

    // 1. Trakt Cloud Removal
    try {
      if (await TraktService.instance.isAuthenticated()) {
        await TraktService.instance.deletePlaybackForImdb(baseId, type: type);
        if (isSeries) {
          await TraktService.instance.removeFromHistory(baseId, 'series');
        }
        debugPrint('[ContinueWatchingService] Removed $baseId ($type) from Trakt continue watching');
      }
    } catch (e) {
      debugPrint('[ContinueWatchingService] Trakt cloud removal error for $baseId: $e');
    }

    // 2. Simkl Cloud Removal
    try {
      if (await SimklService.instance.isAuthenticated()) {
        await SimklService.instance.deletePlaybackForImdb(baseId);
        if (isSeries) {
          await SimklService.instance.addToList(baseId, 'series', 'hold');
        }
        debugPrint('[ContinueWatchingService] Removed $baseId ($type) from Simkl continue watching');
      }
    } catch (e) {
      debugPrint('[ContinueWatchingService] Simkl cloud removal error for $baseId: $e');
    }
  }

  /// Resumes playback when a continue-watching card is clicked:
  /// - For First Launch from Trakt/Simkl: Opens WatchScreen to let user manually pick source, then auto-seeks.
  /// - For Anime: Rescrapes streams with AnimeScraperService and auto-seeks.
  /// - For Torrents: launches directly using saved magnet and fileIdx (no rescraping).
  /// - For PlayTorrioHTTP & Addons: rescrapes and selects the best matching healthy stream.
  /// - Fallback: opens WatchScreen or AnimeStreamSheet if source died.
  static Future<void> resumePlayback(
    BuildContext context,
    ContinueWatchingItem item,
  ) async {
    final movieDetail = MovieDetail(
      id: item.id,
      name: item.title,
      type: item.type,
      poster: item.posterUrl,
      background: item.backdropUrl,
      year: item.year,
    );

    Video? video;
    if (item.season != null && item.episode != null) {
      video = Video(
        id: item.episodeId ?? '${item.id}:${item.season}:${item.episode}',
        title: item.episodeTitle ?? 'Episode ${item.episode}',
        season: item.season ?? 1,
        episode: item.episode ?? 1,
        thumbnail: item.backdropUrl,
      );
    }

    // 0. First-Launch Trakt/Simkl Cloud Session:
    // If no saved local stream source or magnet exists, open WatchScreen
    // so the user can choose their preferred provider manually, then auto-seek!
    final isFirstLaunchCloudItem = item.addonName == null &&
        (item.magnetUrl == null || item.magnetUrl!.isEmpty) &&
        (item.rawUrl == null || item.rawUrl!.isEmpty);

    if (isFirstLaunchCloudItem) {
      Navigator.push(
        context,
        CinematicSlideRoute(
          page: WatchScreen(
            detail: movieDetail,
            selectedEpisode: video,
            type: item.type,
            initialPosition: Duration(seconds: item.positionSeconds),
          ),
        ),
      );
      return;
    }

    // 1. Arabic Anime Specialized Resume Path
    if (item.id.startsWith('arabic_anime:') || item.addonName == 'ArabicAnime') {
      final slug = item.id.replaceAll('arabic_anime:', '');
      final episodeNum = item.episode ?? 1;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF7C5CFF),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'استئناف ${item.title} الحلقة $episodeNum...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        final details = await AnimeArabicService.instance.getDetails(slug);
        final ep = details.episodes.firstWhere(
          (e) => e.number == episodeNum,
          orElse: () => details.episodes.isNotEmpty
              ? details.episodes.first
              : ArabicEpisode(
                  number: episodeNum,
                  title: 'الحلقة $episodeNum',
                  encodedHref: '',
                  watchPath: '/e/$slug-$episodeNum#tok',
                ),
        );

        final rawStreams = await AnimeArabicExtractor.instance.resolveEpisode(ep);

        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (rawStreams.isNotEmpty) {
          final sources = AnimeArabicExtractor.toSources(
            rawStreams,
            animeTitle: details.title,
            episodeNumber: episodeNum,
          );

          StreamSource targetSource = sources.first;
          if (item.streamName != null) {
            final matched = sources.where((s) => s.name == item.streamName || s.title == item.streamTitle);
            if (matched.isNotEmpty) targetSource = matched.first;
          }

          final movieDetail = details.toMovieDetail();
          final video = movieDetail.videos.firstWhere(
            (v) => v.episode == episodeNum,
            orElse: () => movieDetail.videos.first,
          );

          if (!context.mounted) return;
          Navigator.push(
            context,
            CinematicSlideRoute(
              page: PlayerScreen(
                source: targetSource,
                title: '${details.title} - الحلقة $episodeNum',
                backdropUrl: details.displayBanner,
                detail: movieDetail,
                episode: video,
                initialPosition: Duration(seconds: item.positionSeconds),
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[ContinueWatching] Arabic resume error: $e');
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }

      if (!context.mounted) return;
      final card = ArabicAnimeCard(
        slug: slug,
        title: item.title,
        cover: item.posterUrl ?? item.backdropUrl,
      );
      Navigator.push(
        context,
        CinematicSlideRoute(
          page: AnimeArabicDetailsPage(
            anime: card,
            initialEpisodeNumber: episodeNum,
          ),
        ),
      );
      return;
    }

    // 2. General Anime Specialized Resume Path
    if (item.type == 'anime' || item.id.startsWith('anilist:')) {
      final anilistId = int.tryParse(item.id.replaceAll('anilist:', '')) ?? 0;
      final anime = AnimeMedia(
        id: anilistId,
        titleEnglish: item.title,
        titleRomaji: item.title,
        titleNative: '',
        titleUserPreferred: item.title,
        coverImageLarge: item.posterUrl ?? '',
        coverImageExtraLarge: item.posterUrl ?? '',
        bannerImage: item.backdropUrl ?? '',
        description: '',
        seasonYear: int.tryParse(item.year ?? '') ?? 0,
        averageScore: 0,
        genres: const [],
        format: 'TV',
        status: 'RELEASING',
        totalEpisodes: 0,
      );

      final episodeNum = item.episode ?? 1;

      // Show rescrape loader for Anime HTTP streams
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF7C5CFF),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Resuming ${item.title} Ep $episodeNum...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final animeSources = <StreamSource>[];
      StreamSubscription<StreamSource>? sub;

      try {
        final stream = AnimeScraperService.instance.scrapeStreamsStream(
          anime: anime,
          episodeNumber: episodeNum,
        );

        final completer = Completer<void>();

        sub = stream.listen(
          (source) {
            animeSources.add(source);
            if (source.name == item.streamName || source.addonName == item.addonName) {
              if (!completer.isCompleted) completer.complete();
            }
          },
          onError: (_) {},
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      } catch (_) {} finally {
        sub?.cancel();
      }

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;

      StreamSource? selectedSource;
      if (animeSources.isNotEmpty) {
        selectedSource = animeSources.firstWhere(
          (s) => s.name == item.streamName,
          orElse: () => animeSources.first,
        );
      }

      if (selectedSource != null) {
        final detail = AnimeScraperService.toMovieDetail(anime);
        final video = AnimeScraperService.toVideo(anime, episodeNum);

        final finalSource = selectedSource;
        Navigator.push(
          context,
          CinematicSlideRoute(
            page: PlayerScreen(
              source: finalSource,
              title: finalSource.displayTitle,
              backdropUrl: item.backdropUrl,
              detail: detail,
              episode: video,
              initialPosition: Duration(seconds: item.positionSeconds),
            ),
          ),
        );
      } else {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AnimeStreamSheet(
            anime: anime,
            episodeNumber: episodeNum,
            autoPlay: false,
          ),
        );
      }
      return;
    }

    // 2. Fast-Path Torrent Resume:
    // If we have the saved magnet or infoHash + fileIdx, launch immediately!
    if (item.isTorrent &&
        ((item.magnetUrl != null && item.magnetUrl!.isNotEmpty) ||
         (item.infoHash != null && item.infoHash!.isNotEmpty))) {
      final source = item.toStreamSource();

      Navigator.push(
        context,
        CinematicSlideRoute(
          page: PlayerScreen(
            source: source,
            title: item.streamTitle ?? item.title,
            backdropUrl: item.backdropUrl,
            detail: movieDetail,
            episode: video,
            initialPosition: Duration(seconds: item.positionSeconds),
          ),
        ),
      );
      return;
    }

    // 3. HTTP / Dynamic Stream Rescrape Path
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF7C5CFF),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Resuming ${item.title}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final streamId = item.episodeId ?? (item.type == 'series' && item.season != null && item.episode != null
        ? '${item.id}:${item.season}:${item.episode}'
        : item.id);

    final candidateSources = <StreamSource>[];
    StreamSubscription<StreamSource>? sub;

    try {
      final stream = StreamService.fetchStreams(
        type: item.type,
        id: streamId,
        title: item.title,
        year: int.tryParse(item.year ?? ''),
        season: item.season,
        episode: item.episode,
      );

      final completer = Completer<void>();

      sub = stream.listen(
        (source) {
          candidateSources.add(source);
          if (source.addonName == item.addonName &&
              (source.quality == item.quality || source.name == item.streamName)) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (_) {},
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {} finally {
      sub?.cancel();
    }

    // Close loading dialog
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (!context.mounted) return;

    // Pick best match from rescraped sources
    StreamSource? selectedSource;

    // Rule A: If saved as PlayTorrioHTTP, strictly select from PlayTorrioHTTP
    if (item.addonName == 'PlayTorrioHTTP') {
      final httpSources = candidateSources.where((s) => s.addonName == 'PlayTorrioHTTP').toList();
      if (httpSources.isNotEmpty) {
        selectedSource = httpSources.firstWhere(
          (s) => s.name == item.streamName || s.quality == item.quality,
          orElse: () => httpSources.first,
        );
      }
    } else if (candidateSources.isNotEmpty) {
      selectedSource = candidateSources.firstWhere(
        (s) => s.addonName == item.addonName && (s.name == item.streamName || s.quality == item.quality),
        orElse: () => candidateSources.firstWhere(
          (s) => s.quality == item.quality,
          orElse: () => candidateSources.first,
        ),
      );
    }

    if (selectedSource != null) {
      final finalSource = selectedSource;
      Navigator.push(
        context,
        CinematicSlideRoute(
          page: PlayerScreen(
            source: finalSource,
            title: finalSource.displayTitle,
            backdropUrl: item.backdropUrl,
            detail: movieDetail,
            episode: video,
            initialPosition: Duration(seconds: item.positionSeconds),
          ),
        ),
      );
    } else {
      // Fallback to WatchScreen so the user can choose from all available sources
      Navigator.push(
        context,
        CinematicSlideRoute(
          page: WatchScreen(
            detail: movieDetail,
            selectedEpisode: video,
            type: item.type,
            initialPosition: Duration(seconds: item.positionSeconds),
          ),
        ),
      );
    }
  }
}
