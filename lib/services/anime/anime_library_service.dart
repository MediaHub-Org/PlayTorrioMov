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
