import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/my_list/my_list_item.dart';
import '../trakt/trakt_service.dart';
import '../simkl/simkl_service.dart';

abstract final class MyListService {
  static const _storageKey = 'my_list_v1';
  static const int maxItems = 500;

  static final ValueNotifier<List<MyListItem>> items =
      ValueNotifier<List<MyListItem>>([]);
  static final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final list = (jsonDecode(stored) as List)
            .map((e) => MyListItem.fromJson(e as Map<String, dynamic>))
            .toList();
        items.value = list;
      } catch (_) {
        items.value = [];
      }
    }
    await syncAll();
  }

  static Future<void> syncAll() async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    try {
      await Future.wait([syncWithTrakt(), syncWithSimkl()]);
    } finally {
      isSyncing.value = false;
    }
  }

  static Future<void> syncWithTrakt() async {
    try {
      if (!await TraktService.instance.isAuthenticated()) return;
      final movieItems = await TraktService.instance.fetchList(
        'watchlist',
        'movies',
      );
      final showItems = await TraktService.instance.fetchList(
        'watchlist',
        'shows',
      );

      final combined = [...movieItems, ...showItems];
      if (combined.isEmpty) return;

      final current = List<MyListItem>.from(items.value);
      for (final raw in combined) {
        if (raw is! Map<String, dynamic>) continue;
        final item = MyListItem.fromTraktJson(raw);
        final idx = current.indexWhere(
          (i) => i.uniqueKey == item.uniqueKey || i.matches(item),
        );
        if (idx == -1) {
          current.insert(0, item);
        } else {
          current[idx] = current[idx].mergeWith(item);
        }
      }
      current.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      items.value = current.take(maxItems).toList();
      await _persist();
    } catch (e) {
      debugPrint('MyListService: Trakt sync error: $e');
    }
  }

  static Future<void> syncWithSimkl() async {
    try {
      if (!await SimklService.instance.isAuthenticated()) return;
      final lib = await SimklService.instance.fetchLibrarySnapshotOrNull();
      if (lib == null) return;

      final current = List<MyListItem>.from(items.value);
      for (final bucket in ['movies', 'shows', 'anime']) {
        final list = lib[bucket];
        if (list is! List) continue;
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          final status = raw['status'];
          if (status == 'plantowatch' || status == 'watching') {
            final item = MyListItem.fromSimklJson(raw, bucketType: bucket);
            final idx = current.indexWhere(
              (i) => i.uniqueKey == item.uniqueKey || i.matches(item),
            );
            if (idx == -1) {
              current.insert(0, item);
            } else {
              current[idx] = current[idx].mergeWith(item);
            }
          }
        }
      }
      current.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      items.value = current.take(maxItems).toList();
      await _persist();
    } catch (e) {
      debugPrint('MyListService: Simkl sync error: $e');
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(items.value.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  static bool isInList(MyListItem item) {
    return items.value.any(
      (i) => i.uniqueKey == item.uniqueKey || i.matches(item),
    );
  }

  static void add(MyListItem item) {
    if (isInList(item)) return;

    final newList = <MyListItem>[...items.value, item];
    newList.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (newList.length > maxItems) {
      newList.removeRange(maxItems, newList.length);
    }

    items.value = newList;
    _persist();

    // Push to cloud services if logged in
    _syncCloudAdd(item);
  }

  static void _syncCloudAdd(MyListItem item) async {
    final imdb = item.imdbId;
    final tmdb = item.tmdbId;
    final trakt = item.traktId;
    final simkl = item.simklId;

    try {
      if (await TraktService.instance.isAuthenticated()) {
        TraktService.instance.addToWatchlist(
          imdb ?? '',
          item.type,
          tmdbId: tmdb,
          traktId: trakt,
        );
      }
    } catch (e) {
      debugPrint('MyListService: Trakt sync error: $e');
    }
    try {
      if (await SimklService.instance.isAuthenticated()) {
        SimklService.instance.addToList(
          imdb ?? '',
          item.type,
          'plantowatch',
          tmdbId: tmdb,
          simklId: simkl,
        );
      }
    } catch (e) {
      debugPrint('MyListService: Simkl sync error: $e');
    }
  }

  static void remove(MyListItem item) {
    items.value = items.value
        .where((i) => i.uniqueKey != item.uniqueKey && !i.matches(item))
        .toList();
    _persist();

    _syncCloudRemove(item);
  }

  static void _syncCloudRemove(MyListItem item) async {
    final imdb = item.imdbId;
    final tmdb = item.tmdbId;
    final trakt = item.traktId;
    final simkl = item.simklId;

    try {
      if (await TraktService.instance.isAuthenticated()) {
        TraktService.instance.removeFromWatchlist(
          imdb ?? '',
          item.type,
          tmdbId: tmdb,
          traktId: trakt,
        );
      }
    } catch (e) {
      debugPrint('MyListService: Trakt sync error: $e');
    }
    try {
      if (await SimklService.instance.isAuthenticated()) {
        SimklService.instance.addToList(
          imdb ?? '',
          item.type,
          'dropped',
          tmdbId: tmdb,
          simklId: simkl,
        );
      }
    } catch (e) {
      debugPrint('MyListService: Simkl sync error: $e');
    }
  }

  static void toggle(MyListItem item) {
    if (isInList(item)) {
      remove(item);
    } else {
      add(item);
    }
  }

  static MyListItem? _find(MyListItem item) {
    for (final i in items.value) {
      if (i.uniqueKey == item.uniqueKey || i.matches(item)) return i;
    }
    return null;
  }

  static void _setLocal(MyListItem item) {
    final newList = <MyListItem>[
      item,
      ...items.value.where(
        (i) => i.uniqueKey != item.uniqueKey && !i.matches(item),
      ),
    ];
    newList.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (newList.length > maxItems)
      newList.removeRange(maxItems, newList.length);
    items.value = newList;
    _persist();
  }

  /// Applies [updated] to the list, or removes the entry entirely if
  /// Watchlist, Watched and Liked would all end up false -- there's nothing
  /// left to justify keeping a purely-local entry around. Also used by
  /// [setWatchlist]/[setWatched] un-toggling, so unmarking one no longer
  /// wipes out the other two the way a blanket [remove] call used to.
  static void _applyOrRemove(MyListItem original, MyListItem updated) {
    if (!updated.isWatchlist && !updated.isWatched && !updated.isLiked) {
      remove(original);
    } else {
      _setLocal(updated);
    }
  }

  /// Marks [item] Watchlist ("want to watch"), clearing Watched if it was
  /// set -- the two are mutually exclusive. Liked is untouched, since it's
  /// independent of both. Syncs to Trakt/Simkl the same way [add] already
  /// did, since a local Watchlist entry is exactly what those services call
  /// a watchlist entry.
  static void setWatchlist(MyListItem item) {
    final existing = _find(item);
    final wasNew = existing == null;
    final base = existing ?? item;
    if (base.isWatchlist) {
      _applyOrRemove(base, base.copyWith(isWatchlist: false));
      return;
    }
    _applyOrRemove(base, base.copyWith(isWatchlist: true, isWatched: false));
    if (wasNew) _syncCloudAdd(item);
  }

  /// Marks [item] Watched, clearing Watchlist if it was set. Liked is
  /// untouched. Syncs to Trakt's `/sync/history` and Simkl's own history
  /// endpoint -- each provider's real "mark as watched" call, distinct from
  /// the watchlist add/remove `setWatchlist` uses.
  static void setWatched(MyListItem item) {
    final existing = _find(item);
    final base = existing ?? item;
    if (base.isWatched) {
      _applyOrRemove(base, base.copyWith(isWatched: false));
      _syncCloudUnmarkWatched(base);
      return;
    }
    _applyOrRemove(base, base.copyWith(isWatched: true, isWatchlist: false));
    _syncCloudMarkWatched(base);
  }

  static void _syncCloudMarkWatched(MyListItem item) async {
    final imdb = item.imdbId;
    if (imdb == null || imdb.isEmpty) return;
    try {
      if (await TraktService.instance.isAuthenticated()) {
        TraktService.instance.addToHistory(imdb, item.type);
      }
    } catch (e) {
      debugPrint('MyListService: Trakt history sync error: $e');
    }
    try {
      if (await SimklService.instance.isAuthenticated()) {
        SimklService.instance.markWatched(imdb, item.type);
      }
    } catch (e) {
      debugPrint('MyListService: Simkl history sync error: $e');
    }
  }

  static void _syncCloudUnmarkWatched(MyListItem item) async {
    final imdb = item.imdbId;
    if (imdb == null || imdb.isEmpty) return;
    try {
      if (await TraktService.instance.isAuthenticated()) {
        TraktService.instance.removeFromHistory(imdb, item.type);
      }
    } catch (e) {
      debugPrint('MyListService: Trakt history sync error: $e');
    }
    try {
      if (await SimklService.instance.isAuthenticated()) {
        SimklService.instance.markUnwatched(imdb, item.type);
      }
    } catch (e) {
      debugPrint('MyListService: Simkl history sync error: $e');
    }
  }

  /// Toggles Liked, independent of Watchlist/Watched -- something can be
  /// Watched and Liked at once, unlike Watchlist/Watched which are mutually
  /// exclusive. Local-only: neither Trakt nor Simkl has a "liked" concept.
  static void toggleLiked(MyListItem item) {
    final existing = _find(item);
    final base = existing ?? item;
    _applyOrRemove(base, base.copyWith(isLiked: !base.isLiked));
  }
}
