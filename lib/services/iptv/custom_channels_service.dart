import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hardcoded_channels.dart';

/// Live TV channels the user made from a stream they found in a portal.
///
/// A [HardcodedChannel] is `{name, category, keywords[], exclude[]}` plus
/// presentation, and a channel tile is really a *saved search*: it matches
/// portal streams by keyword rather than pointing at one URL. So a
/// user-defined channel is not a new concept — it is the same record with
/// the stream's own name as its keyword, which is why it can be liked,
/// listed and matched by everything that already handles the built-ins.
///
/// Without this, a portal carrying something the built-in catalog has no
/// entry for could only be reached by browsing that portal again from
/// scratch: no tile, no like, no way back.
abstract final class CustomChannelsService {
  static const _storageKey = 'pt_custom_channels_v1';

  /// The id prefix is what tells a user channel from a built-in one at a
  /// glance, and keeps the two id spaces from ever colliding.
  static const idPrefix = 'custom:';

  static final ValueNotifier<List<HardcodedChannel>> items =
      ValueNotifier<List<HardcodedChannel>>([]);

  static bool isCustom(String channelId) => channelId.startsWith(idPrefix);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _publish(const []);
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .whereType<HardcodedChannel>()
          .toList();
      _publish(list);
    } catch (_) {
      // A corrupt store is not worth losing the Live TV page over; the
      // built-in catalog still stands on its own.
      _publish(const []);
    }
  }

  /// Builds a channel from a portal stream's name.
  ///
  /// The stream name becomes both the channel's name and its single
  /// keyword, so the tile finds that stream again — and any other stream
  /// named like it, across portals, which is the point of a tile being a
  /// saved search rather than a bookmark.
  static Future<HardcodedChannel?> addFromStream({
    required String streamName,
    String category = 'Custom',
  }) async {
    final name = streamName.trim();
    if (name.isEmpty) return null;

    final id = '$idPrefix${_slug(name)}';
    // Same stream twice is a no-op rather than a duplicate tile.
    final existing = items.value.where((c) => c.id == id).toList();
    if (existing.isNotEmpty) return existing.first;

    final channel = HardcodedChannel(
      id: id,
      name: name,
      short: _short(name),
      category: category.trim().isEmpty ? 'Custom' : category.trim(),
      keywords: [name.toLowerCase()],
      // A tile gradient stored on the channel, alongside the built-in
      // channels' own broadcaster brand colors -- data, not app chrome,
      // so it does not move when the theme or the palette does.
      gradient: const [Color(0xFF7C5CFF), Color(0xFF1A1A2E)],
    );

    final next = [...items.value, channel];
    _publish(next);
    await _save(next);
    return channel;
  }

  static Future<void> remove(String channelId) async {
    final next = items.value.where((c) => c.id != channelId).toList();
    if (next.length == items.value.length) return;
    _publish(next);
    await _save(next);
  }

  /// Every category a user channel has been filed under, so the Live TV
  /// page can list them without hard-coding "Custom".
  static List<String> get categories {
    final seen = <String>{};
    final out = <String>[];
    for (final channel in items.value) {
      if (seen.add(channel.category)) out.add(channel.category);
    }
    return out;
  }

  static void _publish(List<HardcodedChannel> list) {
    items.value = list;
    // The registry is the single place anything looks a channel up, so it
    // has to learn about these before the first lookup -- otherwise a
    // liked custom channel resolves to null and quietly vanishes.
    HardcodedChannels.custom = list;
  }

  static Future<void> _save(List<HardcodedChannel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(list.map(_toJson).toList()),
    );
  }

  static Map<String, dynamic> _toJson(HardcodedChannel c) => {
    'id': c.id,
    'name': c.name,
    'short': c.short,
    'category': c.category,
    'keywords': c.keywords,
    'exclude': c.exclude,
    'iconUrl': c.iconUrl,
  };

  static HardcodedChannel? _fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final name = j['name'] as String? ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    final keywords = (j['keywords'] as List?)?.whereType<String>().toList();
    return HardcodedChannel(
      id: id,
      name: name,
      short: j['short'] as String? ?? _short(name),
      category: j['category'] as String? ?? 'Custom',
      // A channel with no keywords matches nothing, so fall back to its own
      // name -- which is what it was built from in the first place.
      keywords: (keywords == null || keywords.isEmpty)
          ? [name.toLowerCase()]
          : keywords,
      exclude: (j['exclude'] as List?)?.whereType<String>().toList() ?? const [],
      // A tile gradient stored on the channel, alongside the built-in
      // channels' own broadcaster brand colors -- data, not app chrome,
      // so it does not move when the theme or the palette does.
      gradient: const [Color(0xFF7C5CFF), Color(0xFF1A1A2E)],
      iconUrl: j['iconUrl'] as String?,
    );
  }

  /// A stable id from the name. Two streams whose names differ only by case
  /// or punctuation are the same channel to a viewer, so they get the same
  /// id and the second one does not make a duplicate tile.
  static String _slug(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'channel' : cleaned;
  }

  /// The slug rule, for tests -- [_slug] is private and the id scheme is
  /// the part worth pinning down.
  @visibleForTesting
  static String slugForTest(String name) => _slug(name);

  /// The short badge on the tile: initials for a multi-word name, the first
  /// few letters otherwise.
  static String _short(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return words.take(3).map((w) => w[0].toUpperCase()).join();
    }
    final word = words.isEmpty ? name : words.first;
    return word.substring(0, word.length < 4 ? word.length : 4).toUpperCase();
  }
}
