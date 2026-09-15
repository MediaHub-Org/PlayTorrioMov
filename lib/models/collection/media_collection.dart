// lib/models/collection/media_collection.dart
import '../my_list/my_list_item.dart';

/// A user-made, user-named list of titles.
///
/// Deliberately *not* the same thing as Liked / Watchlist / Watched. Those are
/// **states** on `MyListService`: one flat list where each title carries one
/// state, Watchlist and Watched are mutually exclusive, and all three sync to
/// Trakt and Simkl — where "watched" is scrobble history rather than a list,
/// so removing from it means "mark un-watched", not "remove from collection".
///
/// A collection has none of those constraints: any number of them, a title can
/// be in many at once, the order is the user's, and nothing syncs upstream.
/// The Library shows both side by side as cards, the way Spotify pins "Liked
/// Songs" beside real playlists — same visual language, different semantics
/// underneath.
///
/// Named *collection* rather than *playlist* because Live TV already has
/// playlists: `M3uPlaylist` is a source of channels, and the portals screen has
/// an "M3U Playlists" tab. Two meanings one tap apart would be worse than a
/// slightly longer word.
///
/// Entries are [MyListItem] rather than a parallel type. That model already
/// resolves an identity across four providers — `uniqueKey` prefers IMDb, then
/// TMDB, then Trakt, then Simkl, then a cleaned title+year — and carries the
/// factories that build one from a Movie, a MovieDetail, or a Trakt/Simkl
/// payload. A second model would have to duplicate all of it to answer "is
/// this the same title?". Its `isLiked`/`isWatchlist`/`isWatched` flags are
/// simply not meaningful in here and are left at their defaults.
class MediaCollection {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// In the user's order, not sorted. Reordering is a feature of the list.
  final List<MyListItem> items;

  const MediaCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  int get count => items.length;

  bool get isEmpty => items.isEmpty;

  /// The artwork the card shows: the first entry that has any. A collection of
  /// titles whose posters have not loaded yet still gets a card, just a blank
  /// one, rather than being hidden.
  String? get coverPoster {
    for (final item in items) {
      final poster = item.poster;
      if (poster != null && poster.isNotEmpty) return poster;
    }
    return null;
  }

  /// Up to four posters, for the tiled cover a collection with several titles
  /// gets. Fewer than four is fine; the card lays out what it is given.
  List<String> get mosaicPosters => [
    for (final item in items)
      if (item.poster != null && item.poster!.isNotEmpty) item.poster!,
  ].take(4).toList();

  bool contains(MyListItem item) =>
      items.any((existing) => existing.uniqueKey == item.uniqueKey);

  MediaCollection copyWith({
    String? name,
    DateTime? updatedAt,
    List<MyListItem>? items,
  }) {
    return MediaCollection(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  /// Never throws. A collection whose stored shape has drifted — a missing id,
  /// a timestamp that will not parse, an `items` value that is not a list —
  /// still loads, because losing one field should not lose the collection. An
  /// entry that will not parse is skipped rather than emptying the list.
  factory MediaCollection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <MyListItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is! Map) continue;
        try {
          items.add(MyListItem.fromJson(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // One unreadable entry is dropped; the rest of the collection is
          // still worth having.
        }
      }
    }

    DateTime parseDate(dynamic value) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return MediaCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled',
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      items: items,
    );
  }
}
