import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hardcoded_channels.dart';

/// A channel the user has favorited, so it can appear in Library.
///
/// Deliberately separate from [HardcodedChannel] (`iconUrl`/`gradient`/
/// `keywords` etc. are all static catalog data, re-looked-up by id when
/// needed) -- this only carries what a favorite actually needs to persist:
/// which channel, and when it was added.
class FavoriteChannel {
  final String channelId;
  final DateTime addedAt;

  const FavoriteChannel({required this.channelId, required this.addedAt});

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteChannel.fromJson(Map<String, dynamic> j) => FavoriteChannel(
        channelId: j['channelId'] as String? ?? '',
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Favorited Live TV channels, shown in Library's "Live TV" filter.
///
/// Kept fully separate from [MyListService]/`MyListItem`: that model syncs
/// to Trakt/Simkl, which have no concept of a live channel, so channels
/// never enter that pipeline. This is its own small, local-only store,
/// mirroring the pattern `IptvStore.saveFavorites`/`loadFavorites` already
/// uses for favorite portals.
abstract final class FavoriteChannelsService {
  static const _storageKey = 'pt_favorite_channels_v1';

  static final ValueNotifier<List<FavoriteChannel>> items =
      ValueNotifier<List<FavoriteChannel>>([]);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => FavoriteChannel.fromJson(e as Map<String, dynamic>))
          .toList();
      items.value = list;
    } catch (_) {
      items.value = [];
    }
  }

  static bool isFavorite(String channelId) =>
      items.value.any((f) => f.channelId == channelId);

  static Future<void> toggle(String channelId) async {
    final current = List<FavoriteChannel>.from(items.value);
    final existing = current.indexWhere((f) => f.channelId == channelId);
    if (existing >= 0) {
      current.removeAt(existing);
    } else {
      current.add(FavoriteChannel(channelId: channelId, addedAt: DateTime.now()));
    }
    items.value = current;
    await _save(current);
  }

  static Future<void> _save(List<FavoriteChannel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(list.map((f) => f.toJson()).toList()),
    );
  }

  /// Favorited channels resolved against the current [HardcodedChannels]
  /// catalog, newest first. A favorite whose channel id no longer exists in
  /// the catalog (removed upstream) is silently dropped from the result.
  static List<HardcodedChannel> get resolvedChannels {
    final sorted = List<FavoriteChannel>.from(items.value)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted
        .map((f) => HardcodedChannels.byId(f.channelId))
        .whereType<HardcodedChannel>()
        .toList();
  }
}
