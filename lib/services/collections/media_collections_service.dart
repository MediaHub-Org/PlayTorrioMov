// lib/services/collections/media_collections_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/collection/media_collection.dart';
import '../../models/my_list/my_list_item.dart';

/// Create, read, update and delete for the user's own collections.
///
/// Local only, on purpose. Liked / Watchlist / Watched sync to Trakt and Simkl
/// because those services define them; a collection is the user's own idea and
/// has no upstream equivalent to reconcile with. That also means no conflict
/// resolution, no partial-sync states, and no reason for a write to fail.
///
/// Persistence is a single SharedPreferences key holding the whole list as
/// JSON. `BackupService` dumps every preferences key, so collections are
/// exported and restored with everything else without it needing to know they
/// exist.
abstract final class MediaCollectionsService {
  /// Versioned because the shape may change. A future v2 reader can migrate
  /// from this key rather than guessing what it is looking at.
  @visibleForTesting
  static const storageKey = 'media_collections_v1';

  /// The collections, most recently updated first. Widgets listen to this.
  static final ValueNotifier<List<MediaCollection>> collections =
      ValueNotifier<List<MediaCollection>>([]);

  static bool _loaded = false;

  static Future<void> initialize() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        collections.value = decode(raw);
      }
    } catch (e) {
      // Unreadable storage leaves the user with no collections rather than a
      // crash at startup, and the next write repairs it.
      debugPrint('[MediaCollections] Could not load: $e');
    }
    _loaded = true;
  }

  /// Parses the stored payload. Never throws: a corrupt blob yields no
  /// collections, and one unreadable entry does not discard the others.
  @visibleForTesting
  static List<MediaCollection> decode(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return [];
      final out = <MediaCollection>[];
      for (final entry in parsed) {
        if (entry is! Map) continue;
        final collection = MediaCollection.fromJson(
          Map<String, dynamic>.from(entry),
        );
        // An entry with no id cannot be addressed by any of the methods
        // below, so keeping it would only produce a row nothing can edit.
        if (collection.id.isEmpty) continue;
        out.add(collection);
      }
      return _sorted(out);
    } catch (_) {
      // Not JSON at all. Treated as "no collections yet".
      return [];
    }
  }

  static String encode(List<MediaCollection> value) =>
      jsonEncode(value.map((c) => c.toJson()).toList());

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, encode(collections.value));
    } catch (e) {
      // The in-memory list has already changed, so the UI shows a collection
      // that will be gone at next launch. Worth saying so.
      debugPrint('[MediaCollections] Could not save: $e');
    }
  }

  /// Most recently touched first — the order a Library grid wants, and the
  /// reason `updatedAt` moves on every mutation.
  static List<MediaCollection> _sorted(List<MediaCollection> value) {
    final copy = [...value]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  static void _commit(List<MediaCollection> next) {
    collections.value = _sorted(next);
    _persist();
  }

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a collection and returns it, or null if [name] is blank.
  ///
  /// Duplicate names are allowed: two collections called "Weekend" are the
  /// user's business, and the id is what addresses them. Blank is refused
  /// because a card with no label is unusable.
  static MediaCollection? create(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final now = DateTime.now();
    final collection = MediaCollection(
      id: '${now.microsecondsSinceEpoch}-${collections.value.length}',
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    _commit([...collections.value, collection]);
    return collection;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  static MediaCollection? byId(String id) {
    for (final c in collections.value) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Which collections already hold [item]. Drives the checkmarks in the
  /// "add to collection" sheet, so it has to use the same identity test the
  /// add path does.
  static List<MediaCollection> containing(MyListItem item) =>
      collections.value.where((c) => c.contains(item)).toList();

  // ── Update ────────────────────────────────────────────────────────────────

  /// Returns false if the id is unknown or the new name is blank.
  static bool rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final existing = byId(id);
    if (existing == null) return false;

    _commit([
      for (final c in collections.value)
        if (c.id == id)
          c.copyWith(name: trimmed, updatedAt: DateTime.now())
        else
          c,
    ]);
    return true;
  }

  /// Adds [item] to the collection, or does nothing if it is already there.
  ///
  /// Returns false for an unknown id or a duplicate, so a caller can tell the
  /// difference between "added" and "was already in it" without re-reading.
  static bool addItem(String id, MyListItem item) {
    final existing = byId(id);
    if (existing == null || existing.contains(item)) return false;

    _commit([
      for (final c in collections.value)
        if (c.id == id)
          c.copyWith(items: [...c.items, item], updatedAt: DateTime.now())
        else
          c,
    ]);
    return true;
  }

  static bool removeItem(String id, MyListItem item) {
    final existing = byId(id);
    if (existing == null || !existing.contains(item)) return false;

    _commit([
      for (final c in collections.value)
        if (c.id == id)
          c.copyWith(
            items: c.items
                .where((i) => i.uniqueKey != item.uniqueKey)
                .toList(),
            updatedAt: DateTime.now(),
          )
        else
          c,
    ]);
    return true;
  }

  /// Moves the entry at [from] to [to]. Out-of-range indices are ignored
  /// rather than throwing: a drag that ends outside the list is a no-op, not
  /// an error the user has to see.
  static bool reorder(String id, int from, int to) {
    final existing = byId(id);
    if (existing == null) return false;
    final items = [...existing.items];
    if (from < 0 || from >= items.length) return false;
    if (to < 0 || to >= items.length) return false;
    if (from == to) return false;

    final moved = items.removeAt(from);
    items.insert(to, moved);

    _commit([
      for (final c in collections.value)
        if (c.id == id)
          c.copyWith(items: items, updatedAt: DateTime.now())
        else
          c,
    ]);
    return true;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deleting a collection does not touch the titles in it — they keep
  /// whatever Liked/Watchlist/Watched state they had, because those live on
  /// `MyListService` and were never owned by this.
  static bool delete(String id) {
    if (byId(id) == null) return false;
    _commit(collections.value.where((c) => c.id != id).toList());
    return true;
  }

  /// Removes [item] from every collection holding it. For the case where a
  /// title is gone for good rather than just leaving one list.
  static int removeItemEverywhere(MyListItem item) {
    final affected = containing(item);
    if (affected.isEmpty) return 0;
    final now = DateTime.now();

    _commit([
      for (final c in collections.value)
        if (c.contains(item))
          c.copyWith(
            items: c.items
                .where((i) => i.uniqueKey != item.uniqueKey)
                .toList(),
            updatedAt: now,
          )
        else
          c,
    ]);
    return affected.length;
  }

  @visibleForTesting
  static void resetForTest() {
    collections.value = [];
    _loaded = false;
  }
}
