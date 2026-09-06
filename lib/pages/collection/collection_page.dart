import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/download/download_task_model.dart';
import '../../models/movie/movie.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/download/download_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/my_list/my_list_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import '../../widgets/movie/movie_card.dart';
import '../details/details_page.dart';
import '../iptv/iptv_channel_sheet.dart';

class CollectionPage extends StatefulWidget {
  final int initialTabIndex;

  const CollectionPage({super.key, this.initialTabIndex = 0});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  String _filterType = 'all'; // 'all', 'movie', 'series', 'anime'
  String _sortBy = 'recent'; // 'recent', 'title', 'year'

  /// Narrows Saved to items flagged as "watch later". This used to be its own
  /// tab, but a watchlist item is just a My List item with `isWatchlist` set,
  /// so it belongs beside the type chips rather than duplicating the whole
  /// grid, its filter bar and its empty state one tab over.
  bool _watchlistOnly = false;

  /// Narrows Saved to items already marked watched (`MyListItem.isWatched`).
  bool _watchedOnly = false;

  @override
  void initState() {
    super.initState();
    AnimeLibraryService.instance.init();
  }

  List<MyListItem> _getFilteredAndSortedItems(List<MyListItem> allItems) {
    var filtered = allItems.where((item) {
      if (_watchlistOnly && !item.isWatchlist) return false;
      if (_watchedOnly && !item.isWatched) return false;
      if (_filterType == 'movie' && item.type != 'movie') return false;
      if (_filterType == 'series' &&
          item.type != 'series' &&
          item.type != 'anime')
        return false;
      if (_filterType == 'anime' && item.type != 'anime') return false;

      return true;
    }).toList();

    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'title':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'year':
        filtered.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
    }
    return filtered;
  }

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

  void _navigateToDetail(MyListItem item) {
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: _toMovie(item)),
        tapPosition: null,
      ),
    );
  }

  Future<void> _confirmRemove(MyListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove from Library?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Text(
          'Remove "${item.title}" from your library?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      MyListService.remove(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LibraryTabs(
      title: 'Library',
      titleIcon: Icons.video_library_rounded,
      initialIndex: widget.initialTabIndex,
      tabs: [
        for (final section in LibrarySection.values)
          LibraryTab(
            label: section.label,
            icon: section.icon,
            builder: (context) => switch (section) {
              LibrarySection.saved => _buildSavedTab(),
              LibrarySection.inProgress => _buildInProgressTab(),
              LibrarySection.downloads => _buildDownloadsTab(),
            },
          ),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (_filterType == 'livetv') {
      return ValueListenableBuilder<List<FavoriteChannel>>(
        valueListenable: FavoriteChannelsService.items,
        builder: (context, favorites, _) {
          final channels = _sortedFavoriteChannels(favorites);
          return Column(
            children: [
              _buildFilterBar(favorites.length),
              Expanded(
                child: channels.isEmpty
                    ? const LibraryEmptyState(
                        icon: Icons.live_tv_rounded,
                        title: 'No favorite channels yet',
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
      builder: (context, allItems, _) {
        final items = _getFilteredAndSortedItems(allItems);

        return Column(
          children: [
            _buildFilterBar(allItems.length),
            Expanded(
              child: items.isEmpty
                  ? LibraryEmptyState(
                      icon: _watchlistOnly
                          ? Icons.bookmark_border_rounded
                          : _watchedOnly
                              ? Icons.check_circle_outline_rounded
                              : Icons.video_library_rounded,
                      title: allItems.isEmpty
                          ? 'Nothing saved yet'
                          : (_watchlistOnly
                                ? 'Nothing on your watchlist'
                                : _watchedOnly
                                    ? 'Nothing marked watched yet'
                                    : 'No matching items'),
                      subtitle: allItems.isEmpty
                          ? 'Add movies, series or anime to access them quickly.'
                          : (_watchlistOnly
                                ? 'Bookmark something to watch later and it lands here.'
                                : _watchedOnly
                                    ? 'Mark something watched and it lands here.'
                                    : 'Try adjusting your filters.'),
                    )
                  : _buildGrid(items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInProgressTab() {
    return ValueListenableBuilder<List<ContinueWatchingItem>>(
      valueListenable: ContinueWatchingService.activeItems,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: 'Nothing in progress',
            subtitle: 'Start a movie or episode and it will wait for you here.',
          );
        }
        return _progressList(items);
      },
    );
  }

  Widget _progressList(List<ContinueWatchingItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final progressPercent = (item.progressPercent * 100).toInt();

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          // Rows had no tap handler at all -- clicking one did nothing.
          onTap: () => Navigator.push(
            context,
            LiquidRevealRoute(
              page: DetailsPage(
                movie: Movie(
                  id: item.id,
                  name: item.title,
                  poster: item.posterUrl,
                  year: item.year,
                  type: item.type,
                  addonBaseUrl: 'https://v3-cinemeta.strem.io',
                ),
              ),
              tapPosition: null,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 50,
                            height: 75,
                            color: Colors.white10,
                            child: const Icon(
                              Icons.movie_rounded,
                              color: Colors.white30,
                            ),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 75,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.movie_rounded,
                            color: Colors.white30,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.episodeTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'S${item.season ?? 1} E${item.episode ?? 1} \u2022 ${item.episodeTitle!}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: item.progressPercent,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C5CFF),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$progressPercent% completed',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsTab() {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadService.instance.tasksNotifier,
      builder: (context, allDownloads, _) {
        final downloads = allDownloads
            .where(
              (t) =>
                  t.type == 'movie' || t.type == 'series' || t.type == 'anime',
            )
            .toList();
        if (downloads.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.download_done_rounded,
            title: 'No Downloads',
            subtitle:
                'Downloaded movies and episodes will appear here for offline viewing.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: downloads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = downloads[index];
            final progress = item.totalBytes > 0
                ? item.receivedBytes / item.totalBytes
                : 0.0;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              // Rows had no tap handler at all -- clicking one did nothing.
              onTap: () => Navigator.push(
                context,
                LiquidRevealRoute(
                  page: DetailsPage(
                    movie: Movie(
                      id: item.mediaId,
                      name: item.title,
                      poster: item.posterUrl,
                      year: item.year,
                      type: item.type,
                      addonBaseUrl: 'https://v3-cinemeta.strem.io',
                    ),
                  ),
                  tapPosition: null,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.posterUrl!,
                              width: 50,
                              height: 75,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 50,
                                height: 75,
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.movie_rounded,
                                  color: Colors.white30,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 75,
                              color: Colors.white10,
                              child: const Icon(
                                Icons.movie_rounded,
                                color: Colors.white30,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.episodeTitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.episodeTitle!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C5CFF),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.status.name.toUpperCase()} • ${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () =>
                          DownloadService.instance.deleteDownload(item.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar(int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildChoiceChip('All', 'all'),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Movies', 'movie'),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Series', 'series'),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Anime', 'anime'),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Live TV', 'livetv'),
                      if (_filterType != 'livetv') ...[
                        const SizedBox(width: 12),
                        _ToggleChip(
                          label: 'Watchlist',
                          icon: Icons.bookmark_border_rounded,
                          selectedIcon: Icons.bookmark_rounded,
                          selected: _watchlistOnly,
                          onTap: () =>
                              setState(() => _watchlistOnly = !_watchlistOnly),
                        ),
                        const SizedBox(width: 6),
                        _ToggleChip(
                          label: 'Watched',
                          icon: Icons.check_circle_outline_rounded,
                          selectedIcon: Icons.check_circle_rounded,
                          selected: _watchedOnly,
                          onTap: () =>
                              setState(() => _watchedOnly = !_watchedOnly),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                tooltip: 'Sort by',
                onSelected: (val) => setState(() => _sortBy = val),
                color: const Color(0xFF151822),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'recent',
                    child: Text('Recently Added'),
                  ),
                  const PopupMenuItem(
                    value: 'title',
                    child: Text('Title (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: 'year',
                    child: Text('Release Year'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C5CFF) : const Color(0xFF141824),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  // Same crossAxisCount/childAspectRatio scheme as Movies & Series' own
  // filtered grid (type_catalog_page.dart) and MovieCard itself -- Saved
  // used to hand-roll its own bigger cards via a percentage-of-screen
  // column count instead of MovieCardSizing's fixed pixel widths, so
  // posters here were visibly larger than everywhere else in the app.
  Widget _buildGrid(List<MyListItem> items) {
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
          onLongPress: () => _confirmRemove(item),
          child: MovieCard(
            movie: _toMovie(item),
            onTap: () => _navigateToDetail(item),
          ),
        );
      },
    );
  }

  /// Favorited channels newest-first ("recent") or alphabetically ("title");
  /// "year" doesn't apply to a channel, so it falls back to recent.
  List<HardcodedChannel> _sortedFavoriteChannels(List<FavoriteChannel> favorites) {
    final sorted = List<FavoriteChannel>.from(favorites);
    if (_sortBy == 'title') {
      final byId = {for (final f in sorted) f.channelId: f};
      final resolved = byId.values
          .map((f) => HardcodedChannels.byId(f.channelId))
          .whereType<HardcodedChannel>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return resolved;
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
        // favorited channel looks the same size and shape here as it does
        // in Live TV's own rows.
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

/// A toggle chip for a boolean filter on the Saved tab (Watchlist, Watched)
/// -- same shape as the type chips but its own on/off state instead of a
/// mutually-exclusive selection.
class _ToggleChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _ToggleChip({
    required this.selected,
    required this.onTap,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? 'Showing $label only' : '$label only',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7C5CFF) : const Color(0xFF141824),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 14,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
