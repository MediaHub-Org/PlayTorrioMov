import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/anime/anime_media.dart';

class AnimeLibraryService extends ChangeNotifier {
  static final AnimeLibraryService instance = AnimeLibraryService._internal();
  AnimeLibraryService._internal();

  static const String _watchlistKey = 'playtorrio_anime_watchlist_v1';

  final List<AnimeWatchlistItem> _watchlist = [];

  bool _isInitialized = false;

  List<AnimeWatchlistItem> get watchlist => List.unmodifiable(_watchlist);
  List<AnimeWatchlistItem> get watchingList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.watching)
      .toList();
  List<AnimeWatchlistItem> get planToWatchList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.planToWatch)
      .toList();
  List<AnimeWatchlistItem> get completedList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.completed)
      .toList();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final rawWatchlist = prefs.getStringList(_watchlistKey) ?? [];
      _watchlist.clear();
      for (final str in rawWatchlist) {
        try {
          final json = jsonDecode(str) as Map<String, dynamic>;
          _watchlist.add(AnimeWatchlistItem.fromJson(json));
        } catch (_) {}
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AnimeLibraryService init error: $e');
    }
  }

  bool isAnimeInWatchlist(int anilistId) {
    return _watchlist.any((i) => i.anime.id == anilistId);
  }

  AnimeWatchlistItem? getWatchlistItem(int anilistId) {
    try {
      return _watchlist.firstWhere((i) => i.anime.id == anilistId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setWatchlistStatus(
    AnimeMedia anime,
    AnimeWatchStatus status,
  ) async {
    final idx = _watchlist.indexWhere((i) => i.anime.id == anime.id);
    final currentProgress = idx >= 0 ? _watchlist[idx] : null;

    final newItem = AnimeWatchlistItem(
      anime: anime,
      status: status,
      lastWatchedEpisode: currentProgress?.lastWatchedEpisode ?? 0,
      lastWatchedPositionSeconds:
          currentProgress?.lastWatchedPositionSeconds ?? 0,
      totalDurationSeconds: currentProgress?.totalDurationSeconds ?? 0,
      updatedAt: DateTime.now(),
    );

    if (idx >= 0) {
      _watchlist[idx] = newItem;
    } else {
      _watchlist.insert(0, newItem);
    }

    notifyListeners();
    await _saveWatchlist();
  }

  /// Whether this anime has playback progress worth resuming.
  ///
  /// The watchlist entry does two jobs at once: it records a list status
  /// *and* it is the only carrier of `lastWatchedEpisode` /
  /// `lastWatchedPositionSeconds`. Dropping it to clear a status would take
  /// the resume point with it, which is why [clearListStatus] exists.
  ///
  /// Note that no current code path writes those progress fields -- anime
  /// plays through the shared player, which records position in
  /// `ContinueWatchingService` instead, and that is what the details page
  /// reads. This guard is therefore defensive today: it exists so the
  /// clear-status path stays correct for entries restored from older
  /// installs, and if progress is ever written here again.
  bool hasResumableProgress(int anilistId) {
    final item = getWatchlistItem(anilistId);
    if (item == null) return false;
    return item.lastWatchedEpisode > 0 || item.lastWatchedPositionSeconds > 0;
  }

  /// Removes [anilistId] from the list *unless* it carries playback
  /// progress, in which case the entry is kept so Play still resumes where
  /// the user left off.
  ///
  /// Use this when the user clears a library status, rather than
  /// [removeFromWatchlist]: taking a show off your watchlist means "I am
  /// not planning to watch this", not "forget that I watched 12 episodes
  /// of it".
  Future<void> clearListStatus(int anilistId) async {
    if (hasResumableProgress(anilistId)) return;
    await removeFromWatchlist(anilistId);
  }

  /// Gives an existing entry playback progress, for tests.
  ///
  /// Exists because no production code path writes these fields today (see
  /// [hasResumableProgress]), so a test otherwise cannot build the state
  /// [clearListStatus] is meant to protect.
  @visibleForTesting
  void seedProgressForTest(int anilistId, {required int episode}) {
    final idx = _watchlist.indexWhere((i) => i.anime.id == anilistId);
    if (idx < 0) return;
    final current = _watchlist[idx];
    _watchlist[idx] = AnimeWatchlistItem(
      anime: current.anime,
      status: current.status,
      lastWatchedEpisode: episode,
      lastWatchedPositionSeconds: current.lastWatchedPositionSeconds,
      totalDurationSeconds: current.totalDurationSeconds,
      updatedAt: current.updatedAt,
    );
  }

  Future<void> removeFromWatchlist(int anilistId) async {
    _watchlist.removeWhere((i) => i.anime.id == anilistId);
    notifyListeners();
    await _saveWatchlist();
  }

  Future<void> _saveWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _watchlist.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_watchlistKey, list);
    } catch (_) {}
  }
}
