// lib/pages/collection/library_shelf_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/collection/media_collection.dart';
import '../../models/movie/movie.dart';
import '../../models/my_list/my_list_item.dart';
import '../../l10n/l10n.dart';
import '../../services/collections/media_collections_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/theme/app_colors.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import '../../widgets/movie/movie_card.dart';
import '../details/details_page.dart';
import '../iptv/iptv_channel_sheet.dart';

/// One shelf of the Library, opened from its card.
///
/// Both kinds of shelf land here -- the three built-in states and a user
/// collection -- because from the user's side they are the same screen: a
/// grid of titles with a name on it. What differs is underneath, and it is
/// exactly two things.
///
/// **Order.** A built-in state has no inherent one, so it offers sort (recent
/// / title / year) and a type filter, the way the Library tabs always did. A
/// collection's order *is* the user's, so sorting it would throw away the
/// thing they arranged; it gets a reorder mode instead.
///
/// **What removing means.** Out of a built-in state it is a library edit --
/// un-liking something, taking it off the watchlist -- and it syncs upstream,
/// so it asks first. Out of a collection it only leaves that one list; the
/// title keeps every other state it had, which is why [MediaCollection] does
/// not own those flags.
class LibraryShelfPage extends StatefulWidget {
  /// Set for a built-in state. Mutually exclusive with [collectionId].
  final LibraryShelf? shelf;

  /// Set for a user collection, by id rather than by value so a rename or an
  /// edit made while this page is open is picked up from the service.
  final String? collectionId;

  const LibraryShelfPage.builtIn(LibraryShelf this.shelf, {super.key})
    : collectionId = null;

  const LibraryShelfPage.collection(String this.collectionId, {super.key})
    : shelf = null;

  bool get isCollection => collectionId != null;

  /// Translates [ReorderableListView]'s destination index into the one
  /// [MediaCollectionsService.reorder] wants.
  ///
  /// The widget reports `newIndex` as an insertion point in the list *before*
  /// the dragged row is taken out, so every downward move arrives one too
  /// high; the service removes first and then inserts. Off by one here would
  /// silently mis-place every drag towards the end of the list, which is the
  /// half of the drags nobody checks.
  @visibleForTesting
  static int reorderTarget(int from, int to) => to > from ? to - 1 : to;

  @override
  State<LibraryShelfPage> createState() => _LibraryShelfPageState();
}

class _LibraryShelfPageState extends State<LibraryShelfPage> {
  String _filterType = 'all';
  String _sortBy = 'recent';
  bool _reordering = false;

  // ── Titles ────────────────────────────────────────────────────────────────

  Movie _toMovie(MyListItem item) {
    final effectiveId =
        item.imdbId ??
        (item.tmdbId != null ? 'tmdb:${item.tmdbId}' : null) ??
        item.traktId?.toString() ??
        '';

    return Movie(
      id: effectiveId,
      name: item.title,
      poster: item.poster,
      year: item.year?.toString(),
      type: item.type,
      addonBaseUrl: 'https://v3-cinemeta.strem.io',
    );
  }

  void _openDetails(MyListItem item) {
    pushPage(context, DetailsPage(movie: _toMovie(item)));
  }

  List<MyListItem> _filteredAndSorted(List<MyListItem> all) {
    final shelf = widget.shelf!;
    final type = _typeFor(shelf);
    final filtered = all.where((item) {
      switch (shelf) {
        case LibraryShelf.liked:
          if (!item.isLiked) return false;
        case LibraryShelf.watchlist:
          if (!item.isWatchlist) return false;
        case LibraryShelf.watched:
          if (!item.isWatched) return false;
      }
      if (type == 'movie' && item.type != 'movie') return false;
      if (type == 'series' && item.type != 'series' && item.type != 'anime') {
        return false;
      }
      if (type == 'anime' && item.type != 'anime') return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'title':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'year':
        filtered.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      default:
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return filtered;
  }

  /// Live TV is only offered under Liked -- a channel cannot be watchlisted
  /// or marked watched -- so elsewhere a leftover 'livetv' reads as
  /// "everything" rather than leaving the chip row with nothing highlighted.
  String _typeFor(LibraryShelf shelf) =>
      (_filterType == 'livetv' && shelf != LibraryShelf.liked)
      ? 'all'
      : _filterType;

  // ── Editing ───────────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String message, String action) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.inkAlpha(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.libraryCancel,
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return answer == true;
  }

  Future<void> _removeTitle(MyListItem item, MediaCollection? collection) async {
    final l10n = context.l10n;
    if (collection != null) {
      // Leaving one list, not the library: no upstream sync, and every other
      // state the title carries is untouched. Still confirmed, because the
      // gesture that gets here is a long press and those are easy to trigger
      // by accident on a phone.
      if (await _confirm(
        'Remove from ${collection.name}?',
        '"${item.title}" stays in your library and in any other collection '
            'holding it.',
        l10n.libraryRemove,
      )) {
        MediaCollectionsService.removeItem(collection.id, item);
      }
      return;
    }

    if (await _confirm(
      'Remove from Library?',
      'Remove "${item.title}" from your library?',
      l10n.libraryRemove,
    )) {
      MyListService.remove(item);
    }
  }

  Future<void> _rename(MediaCollection collection) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.libraryRenameCollection,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value),
          style: TextStyle(color: AppColors.ink),
          decoration: InputDecoration(hintText: l10n.libraryCollectionNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.libraryCancel,
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.librarySave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) MediaCollectionsService.rename(collection.id, name);
  }

  Future<void> _delete(MediaCollection collection) async {
    final message = collection.isEmpty
        ? 'This collection is empty.'
        : 'The ${collection.count} titles in it stay in your library.';
    if (!await _confirm(
      context.l10n.libraryDeleteCollectionConfirm(collection.name),
      message,
      context.l10n.libraryDelete,
    )) {
      return;
    }
    MediaCollectionsService.delete(collection.id);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return widget.isCollection ? _buildCollection() : _buildBuiltIn();
  }

  Widget _buildCollection() {
    return ValueListenableBuilder<List<MediaCollection>>(
      valueListenable: MediaCollectionsService.collections,
      builder: (context, _, __) {
        final collection = MediaCollectionsService.byId(widget.collectionId!);
        // Deleted from somewhere else while this page was open. An empty
        // frame beats a crash, and the pop below leaves the Library showing.
        if (collection == null) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(backgroundColor: AppColors.bar),
            body: LibraryEmptyState(
              icon: Icons.playlist_remove_rounded,
              title: context.l10n.libraryCollectionGoneTitle,
              subtitle: context.l10n.libraryCollectionGoneHint,
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            backgroundColor: AppColors.bar,
            surfaceTintColor: Colors.transparent,
            title: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            actions: [
              if (collection.count > 1)
                IconButton(
                  icon: Icon(
                    _reordering
                        ? Icons.done_rounded
                        : Icons.swap_vert_rounded,
                  ),
                  tooltip: _reordering
                      ? context.l10n.libraryReorderDone
                      : context.l10n.libraryReorder,
                  onPressed: () => setState(() => _reordering = !_reordering),
                ),
              PopupMenuButton<String>(
                tooltip: context.l10n.libraryCollectionOptions,
                color: AppColors.raised,
                onSelected: (value) {
                  if (value == 'rename') _rename(collection);
                  if (value == 'delete') _delete(collection);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(context.l10n.libraryRename),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.libraryDelete),
                  ),
                ],
              ),
            ],
          ),
          body: collection.isEmpty
              ? LibraryEmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: context.l10n.libraryEmptyCollectionTitle,
                  subtitle: context.l10n.libraryEmptyCollectionHint,
                )
              : _reordering
              ? _buildReorderList(collection)
              : _buildGrid(collection.items, collection),
        );
      },
    );
  }

  Widget _buildBuiltIn() {
    final shelf = widget.shelf!;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(shelf.icon, color: shelf.color, size: 20),
            const SizedBox(width: 10),
            Text(
              shelf.localizedLabel(context),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
          ],
        ),
        actions: [_buildSortButton(), const SizedBox(width: 8)],
      ),
      body: _buildBuiltInBody(shelf),
    );
  }

  Widget _buildBuiltInBody(LibraryShelf shelf) {
    // Live TV's likes live in FavoriteChannelsService, not MyListService, so
    // this is a different store rather than a different filter over the same
    // one.
    if (_filterType == 'livetv' && shelf == LibraryShelf.liked) {
      return ValueListenableBuilder<List<FavoriteChannel>>(
        valueListenable: FavoriteChannelsService.items,
        builder: (context, favorites, _) {
          final channels = _sortedFavoriteChannels(favorites);
          return Column(
            children: [
              _buildFilterBar(shelf),
              Expanded(
                child: channels.isEmpty
                    ? LibraryEmptyState(
                        icon: Icons.live_tv_rounded,
                        title: context.l10n
                            .libraryNoLikedChannelsTitle,
                        subtitle:
                            'Tap the heart on a channel in Live TV to save it here.',
                      )
                    : _buildChannelsGrid(channels),
              ),
            ],
          );
        },
      );
    }

    return ValueListenableBuilder<List<MyListItem>>(
      valueListenable: MyListService.items,
      builder: (context, all, _) {
        final items = _filteredAndSorted(all);
        final anyInShelf = all.any(
          (i) => switch (shelf) {
            LibraryShelf.liked => i.isLiked,
            LibraryShelf.watchlist => i.isWatchlist,
            LibraryShelf.watched => i.isWatched,
          },
        );

        return Column(
          children: [
            _buildFilterBar(shelf),
            Expanded(
              child: items.isEmpty
                  ? LibraryEmptyState(
                      icon: shelf.icon,
                      // Distinguishes "this shelf is empty" from "your filter
                      // hid everything", which otherwise read the same.
                      title: anyInShelf
                          ? context.l10n.libraryNoMatchingItems
                          : shelf.localizedEmptyTitle(context),
                      subtitle: anyInShelf
                          ? 'Try adjusting your filters.'
                          : shelf.localizedEmptySubtitle(context),
                    )
                  : _buildGrid(items, null),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(List<MyListItem> items, MediaCollection? collection) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600
        ? 3
        : width < 900
        ? 4
        : width < 1200
        ? 5
        : width < 1600
        ? 6
        : 7;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onLongPress: () => _removeTitle(item, collection),
          child: MovieCard(
            movie: _toMovie(item),
            onTap: () => _openDetails(item),
          ),
        );
      },
    );
  }

  /// Reordering happens in a list, not the grid, because a drag handle on a
  /// row is the affordance Flutter ships and every phone user already knows.
  /// The grid is for browsing; this is for arranging, and they are different
  /// enough jobs to be different views of the same list.
  Widget _buildReorderList(MediaCollection collection) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: collection.items.length,
      onReorder: (from, to) {
        // ReorderableListView reports the destination as an insertion index
        // in the *pre-removal* list, so a downward move is one too high.
        MediaCollectionsService.reorder(
          collection.id,
          from,
          LibraryShelfPage.reorderTarget(from, to),
        );
      },
      itemBuilder: (context, index) {
        final item = collection.items[index];
        return Padding(
          key: ValueKey(item.uniqueKey),
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inkAlpha(0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 60,
                    child: item.poster != null && item.poster!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.poster!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF15171F)),
                          )
                        : const ColoredBox(color: Color(0xFF15171F)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.ink, fontSize: 14),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Filter and sort, built-in shelves only ────────────────────────────────

  Widget _buildFilterBar(LibraryShelf shelf) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildChoiceChip('All', 'all', shelf),
            const SizedBox(width: 6),
            _buildChoiceChip(l10n.libraryFilterMovies, 'movie', shelf),
            const SizedBox(width: 6),
            _buildChoiceChip(l10n.libraryFilterSeries, 'series', shelf),
            const SizedBox(width: 6),
            _buildChoiceChip(l10n.libraryFilterAnime, 'anime', shelf),
            // Only under Liked: a channel cannot be watchlisted or marked
            // watched, so offering the chip elsewhere would promise a filter
            // with nothing behind it.
            if (shelf == LibraryShelf.liked) ...[
              const SizedBox(width: 6),
              _buildChoiceChip(l10n.libraryFilterLiveTv, 'livetv', shelf),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, LibraryShelf shelf) {
    final isSelected = _typeFor(shelf) == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.raised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.ink : AppColors.inkAlpha(0.60),
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      initialValue: _sortBy,
      tooltip: l10n.librarySortBy,
      onSelected: (val) => setState(() => _sortBy = val),
      color: AppColors.raised,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.inkAlpha(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 14, color: AppColors.inkMuted),
            const SizedBox(width: 4),
            Text(
              _sortBy.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'recent', child: Text(l10n.librarySortRecent)),
        PopupMenuItem(value: 'title', child: Text(l10n.librarySortTitle)),
        PopupMenuItem(value: 'year', child: Text(l10n.librarySortYear)),
      ],
    );
  }

  // ── Live TV ───────────────────────────────────────────────────────────────

  /// Favourited channels newest-first ("recent") or alphabetically ("title");
  /// "year" does not apply to a channel, so it falls back to recent.
  List<HardcodedChannel> _sortedFavoriteChannels(
    List<FavoriteChannel> favorites,
  ) {
    final sorted = List<FavoriteChannel>.from(favorites);
    if (_sortBy == 'title') {
      final byId = {for (final f in sorted) f.channelId: f};
      return byId.values
          .map((f) => HardcodedChannels.byId(f.channelId))
          .whereType<HardcodedChannel>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted
        .map((f) => HardcodedChannels.byId(f.channelId))
        .whereType<HardcodedChannel>()
        .toList();
  }

  Widget _buildChannelsGrid(List<HardcodedChannel> channels) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600
        ? 2
        : width < 900
        ? 3
        : width < 1200
        ? 4
        : width < 1600
        ? 5
        : 6;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // Matches IptvCardSizing's own cardWidth/totalHeight ratio, so a
        // favourited channel looks the same size and shape here as it does in
        // Live TV's own rows.
        childAspectRatio: 0.58,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return IptvChannelCard(
          channel: channel,
          onTap: () => IptvChannelSheet.show(context, channel),
        );
      },
    );
  }
}
