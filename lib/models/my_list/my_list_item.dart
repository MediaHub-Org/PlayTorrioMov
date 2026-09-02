enum MyListSource { local, trakt, simkl }

class MyListItem {
  final int? traktId;
  final int? simklId;
  final String? imdbId;
  final int? tmdbId;
  final String title;
  final int? year;
  final String type;
  final String? poster;
  final DateTime addedAt;
  final MyListSource source;
  final bool isWatchlist;
  final bool isWatched;

  /// Favourited, independent of watch progress -- unlike Watchlist/Watched,
  /// which are mutually exclusive, something can be both Watched and Liked
  /// at once. Local-only: neither Trakt nor Simkl has a "liked" concept to
  /// sync against.
  final bool isLiked;

  const MyListItem({
    this.traktId,
    this.simklId,
    this.imdbId,
    this.tmdbId,
    required this.title,
    this.year,
    required this.type,
    this.poster,
    required this.addedAt,
    this.source = MyListSource.local,
    this.isWatchlist = false,
    this.isWatched = false,
    this.isLiked = false,
  });

  /// Identity key used for de-duplication and for [==]/[hashCode].
  ///
  /// Only IMDb ids are globally unique; every other provider numbers movies
  /// and shows in separate namespaces, so Trakt/Simkl/TMDB keys are all
  /// qualified by [type]. Without that, Trakt movie 1 and Trakt show 1
  /// collide and one silently shadows the other in My List.
  ///
  /// This is in-memory only -- it is never serialized, so the format is free
  /// to change without migrating stored lists.
  String get uniqueKey {
    if (imdbId != null && imdbId!.isNotEmpty) return 'imdb:$imdbId';
    if (tmdbId != null) return 'tmdb:$type:$tmdbId';
    if (traktId != null) return 'trakt:$type:$traktId';
    if (simklId != null) return 'simkl:$type:$simklId';
    final clean = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    return 'title:$type:$clean:${year ?? 0}';
  }

  bool matches(MyListItem other) {
    if (imdbId != null &&
        other.imdbId != null &&
        imdbId!.isNotEmpty &&
        other.imdbId!.isNotEmpty) {
      return imdbId == other.imdbId;
    }
    if (tmdbId != null && other.tmdbId != null) {
      return tmdbId == other.tmdbId && type == other.type;
    }
    if (traktId != null && other.traktId != null) {
      return traktId == other.traktId && type == other.type;
    }
    if (simklId != null && other.simklId != null) {
      return simklId == other.simklId && type == other.type;
    }

    // Don't fallback to title if there are conflicting IDs of the same authority
    final hasConflictingIds =
        (imdbId != null && other.imdbId != null && imdbId != other.imdbId) ||
        (tmdbId != null && other.tmdbId != null && tmdbId != other.tmdbId) ||
        (traktId != null &&
            other.traktId != null &&
            traktId != other.traktId) ||
        (simklId != null && other.simklId != null && simklId != other.simklId);

    if (hasConflictingIds) return false;

    final cleanA = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    final cleanB = other.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    if (cleanA.isNotEmpty &&
        cleanA == cleanB &&
        (year == null ||
            other.year == null ||
            (year! - other.year!).abs() <= 1)) {
      return type == other.type;
    }
    return false;
  }

  MyListItem mergeWith(MyListItem other) {
    return copyWith(
      traktId: other.traktId ?? traktId,
      simklId: other.simklId ?? simklId,
      imdbId: (other.imdbId != null && other.imdbId!.isNotEmpty)
          ? other.imdbId
          : imdbId,
      tmdbId: other.tmdbId ?? tmdbId,
      poster: poster ?? other.poster,
      source: other.source != MyListSource.local ? other.source : source,
      // OR, not overwrite: a re-sync merging in a fresh watchlist entry
      // shouldn't be able to silently clear a status the other side set.
      isWatchlist: isWatchlist || other.isWatchlist,
      isWatched: isWatched || other.isWatched,
      isLiked: isLiked || other.isLiked,
    );
  }

  factory MyListItem.fromMovie({
    required String id,
    required String name,
    String? poster,
    String? year,
    required String type,
    String? imdbId,
    int? tmdbId,
    int? traktId,
    int? simklId,
  }) {
    return MyListItem(
      imdbId: id.startsWith('tt') ? id : imdbId,
      tmdbId:
          tmdbId ??
          (int.tryParse(id) != null && !id.startsWith('tt')
              ? int.tryParse(id)
              : null),
      traktId: traktId,
      simklId: simklId,
      title: name,
      poster: poster,
      year: year != null
          ? int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), ''))
          : null,
      type: type == 'series' || type == 'anime' ? 'series' : 'movie',
      addedAt: DateTime.now(),
      source: MyListSource.local,
    );
  }

  factory MyListItem.fromMovieDetail({
    required String id,
    required String name,
    String? poster,
    String? year,
    required String type,
    String? imdbId,
    int? tmdbId,
    int? traktId,
    int? simklId,
  }) {
    return MyListItem(
      imdbId: id.startsWith('tt') ? id : imdbId,
      tmdbId:
          tmdbId ??
          (int.tryParse(id) != null && !id.startsWith('tt')
              ? int.tryParse(id)
              : null),
      traktId: traktId,
      simklId: simklId,
      title: name,
      poster: poster,
      year: year != null
          ? int.tryParse(year.replaceAll(RegExp(r'[^0-9]'), ''))
          : null,
      type: type == 'series' || type == 'anime' ? 'series' : 'movie',
      addedAt: DateTime.now(),
      source: MyListSource.local,
    );
  }

  /// Only ever called with items from Trakt's own `watchlist` list
  /// (`MyListService.syncWithTrakt`), so [isWatchlist] is always true here --
  /// previously left false, meaning a synced item never actually showed as
  /// "Watchlist" in the Saved tab's own Watchlist filter or the detail
  /// page's status picker despite genuinely being one.
  factory MyListItem.fromTraktJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final media = movie ?? show ?? json;
    final ids = media['ids'] as Map<String, dynamic>? ?? {};
    final imdbId = ids['imdb']?.toString();
    return MyListItem(
      traktId: ids['trakt'] as int?,
      imdbId: imdbId,
      tmdbId: ids['tmdb'] as int?,
      title: media['title']?.toString() ?? 'Unknown',
      year: media['year'] as int?,
      type: (media['type']?.toString() == 'show' || show != null)
          ? 'series'
          : 'movie',
      poster: imdbId != null
          ? 'https://images.metahub.space/poster/medium/$imdbId/img'
          : null,
      addedAt: json['listed_at'] != null
          ? DateTime.tryParse(json['listed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: MyListSource.trakt,
      isWatchlist: true,
    );
  }

  /// [bucketType] is which of Simkl's own movies/shows/anime buckets this
  /// item was fetched from (see `MyListService.syncWithSimkl`) -- ground
  /// truth for the anime split, unlike guessing from the item's own shape
  /// (anime is wrapped exactly like a show, `{"show": {...}}` or
  /// `{"anime": {...}}` depending on endpoint, so shape alone can't tell
  /// a TV show from an anime series).
  factory MyListItem.fromSimklJson(
    Map<String, dynamic> json, {
    String? bucketType,
  }) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show =
        json['show'] as Map<String, dynamic>? ??
        json['anime'] as Map<String, dynamic>?;
    final media = movie ?? show ?? json;
    final ids = media['ids'] as Map<String, dynamic>? ?? {};
    final imdbId = ids['imdb']?.toString();
    final posterPath = media['poster'] as String?;
    final posterUrl = posterPath != null
        ? 'https://simkl.in/posters/${posterPath}_m.jpg'
        : (imdbId != null
              ? 'https://images.metahub.space/poster/medium/$imdbId/img'
              : null);

    final type = bucketType == 'anime'
        ? 'anime'
        : (movie != null ? 'movie' : 'series');

    return MyListItem(
      simklId: ids['simkl'] as int?,
      imdbId: imdbId,
      tmdbId: ids['tmdb'] as int?,
      title: media['title']?.toString() ?? 'Unknown',
      year: media['year'] as int?,
      type: type,
      poster: posterUrl,
      addedAt: json['last_watched_at'] != null
          ? DateTime.tryParse(json['last_watched_at'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      source: MyListSource.simkl,
      // Only ever called for plantowatch/watching Simkl items
      // (MyListService.syncWithSimkl) -- previously left false, same gap as
      // fromTraktJson above.
      isWatchlist: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'traktId': traktId,
      'simklId': simklId,
      'imdbId': imdbId,
      'tmdbId': tmdbId,
      'title': title,
      'year': year,
      'type': type,
      'poster': poster,
      'addedAt': addedAt.toIso8601String(),
      'source': source.name,
      'isWatchlist': isWatchlist,
      'isWatched': isWatched,
      'isLiked': isLiked,
    };
  }

  factory MyListItem.fromJson(Map<String, dynamic> json) {
    MyListSource src = MyListSource.local;
    if (json['source'] == 'trakt') {
      src = MyListSource.trakt;
    } else if (json['source'] == 'simkl') {
      src = MyListSource.simkl;
    }
    return MyListItem(
      traktId: json['traktId'] as int?,
      simklId: json['simklId'] as int?,
      imdbId: json['imdbId']?.toString(),
      tmdbId: json['tmdbId'] as int?,
      title: json['title']?.toString() ?? 'Unknown',
      year: json['year'] as int?,
      type: json['type']?.toString() ?? 'movie',
      poster: json['poster']?.toString(),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: src,
      isWatchlist: json['isWatchlist'] as bool? ?? false,
      isWatched: json['isWatched'] as bool? ?? false,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  MyListItem copyWith({
    int? traktId,
    int? simklId,
    String? imdbId,
    int? tmdbId,
    String? title,
    int? year,
    String? type,
    String? poster,
    DateTime? addedAt,
    MyListSource? source,
    bool? isWatchlist,
    bool? isWatched,
    bool? isLiked,
  }) {
    return MyListItem(
      traktId: traktId ?? this.traktId,
      simklId: simklId ?? this.simklId,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      year: year ?? this.year,
      type: type ?? this.type,
      poster: poster ?? this.poster,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
      isWatchlist: isWatchlist ?? this.isWatchlist,
      isWatched: isWatched ?? this.isWatched,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyListItem && uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}
