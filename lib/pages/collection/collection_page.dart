import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/download/download_task_model.dart';
import '../../models/movie/movie.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anime_library_service.dart';
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
import '../../services/theme/app_colors.dart';

class CollectionPage extends StatefulWidget {
  final int initialTabIndex;

  const CollectionPage({super.key, this.initialTabIndex = 0});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  String _filterType = 'all'; // 'all', 'movie', 'series', 'anime', 'livetv'
  String _sortBy = 'recent'; // 'recent', 'title', 'year'

  @override
  void initState() {
    super.initState();
    AnimeLibraryService.instance.init();
  }

  List<MyListItem> _getFilteredAndSortedItems(
    List<MyListItem> allItems,
    LibrarySection section,
  ) {
    final type = _typeFor(section);
    var filtered = allItems.where((item) {
      switch (section) {
        case LibrarySection.liked:
          if (!item.isLiked) return false;
        case LibrarySection.watchlist:
          if (!item.isWatchlist) return false;
        case LibrarySection.watched:
          if (!item.isWatched) return false;
        case LibrarySection.downloads:
          break; // Not a My List view; see _buildDownloadsTab.
      }
      if (type == 'movie' && item.type != 'movie') return false;
      if (type == 'series' &&
          item.type != 'series' &&
          item.type != 'anime') {
        return false;
      }
      if (type == 'anime' && item.type != 'anime') return false;

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
    pushPage(context, DetailsPage(movie: _toMovie(item)));
  }

  Future<void> _confirmRemove(MyListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove from Library?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Text(
          'Remove "${item.title}" from your library?',
          style: TextStyle(color: AppColors.inkAlpha(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
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
              'Remove',
              style: TextStyle(
                color: AppColors.ink,
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
            builder: (context) => section == LibrarySection.downloads
                ? _buildDownloadsTab()
                : _buildStateTab(section),
          ),
      ],
    );
  }

  /// One of the three library-state tabs. Live TV appears under Liked only:
  /// a channel cannot be on a watchlist or marked watched, and its likes live
  /// in [FavoriteChannelsService] rather than [MyListService].
  /// The type filter as it applies to [section]. Live TV is only selectable
  /// under Liked, so elsewhere a leftover 'livetv' reads as "everything"
  /// rather than leaving the chip row with nothing highlighted.
  String _typeFor(LibrarySection section) =>
      (_filterType == 'livetv' && section != LibrarySection.liked)
      ? 'all'
      : _filterType;

  Widget _buildStateTab(LibrarySection section) {
    // The type filter is shared across tabs, so a Live TV selection made
    // under Liked would otherwise follow the user into Watchlist and show
    // channels in a tab that does not offer the chip at all.
    if (_filterType == 'livetv' && section == LibrarySection.liked) {
      return ValueListenableBuilder<List<FavoriteChannel>>(
        valueListenable: FavoriteChannelsService.items,
        builder: (context, favorites, _) {
          final channels = _sortedFavoriteChannels(favorites);
          return Column(
            children: [
              _buildFilterBar(favorites.length, section),
              Expanded(
                child: channels.isEmpty
                    ? const LibraryEmptyState(
                        icon: Icons.live_tv_rounded,
                        title: 'No liked channels yet',
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
        final items = _getFilteredAndSortedItems(allItems, section);
        final anyInSection = allItems.any(
          (i) => switch (section) {
            LibrarySection.liked => i.isLiked,
            LibrarySection.watchlist => i.isWatchlist,
            LibrarySection.watched => i.isWatched,
            LibrarySection.downloads => false,
          },
        );

        return Column(
          children: [
            _buildFilterBar(allItems.length, section),
            Expanded(
              child: items.isEmpty
                  ? LibraryEmptyState(
                      icon: section.icon,
                      // Distinguishes "this tab is empty" from "your filter
                      // hid everything", which otherwise read the same.
                      title: anyInSection
                          ? 'No matching items'
                          : switch (section) {
                              LibrarySection.liked => 'Nothing liked yet',
                              LibrarySection.watchlist =>
                                'Nothing on your watchlist',
                              LibrarySection.watched =>
                                'Nothing marked watched yet',
                              LibrarySection.downloads => '',
                            },
                      subtitle: anyInSection
                          ? 'Try adjusting your filters.'
                          : switch (section) {
                              LibrarySection.liked =>
                                'Tap the heart on anything and it lands here.',
                              LibrarySection.watchlist =>
                                'Add something to watch later and it lands here.',
                              LibrarySection.watched =>
                                'Mark something watched and it lands here.',
                              LibrarySection.downloads => '',
                            },
                    )
                  : _buildGrid(items),
            ),
          ],
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
              onTap: () => pushPage(
                context,
                DetailsPage(
                  movie: Movie(
                    id: item.mediaId,
                    name: item.title,
                    poster: item.posterUrl,
                    year: item.year,
                    type: item.type,
                    addonBaseUrl: 'https://v3-cinemeta.strem.io',
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.inkAlpha(0.08),
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
                                color: AppColors.inkAlpha(0.10),
                                child: Icon(
                                  Icons.movie_rounded,
                                  color: AppColors.inkAlpha(0.30),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 75,
                              color: AppColors.inkAlpha(0.10),
                              child: Icon(
                                Icons.movie_rounded,
                                color: AppColors.inkAlpha(0.30),
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
                              style: TextStyle(
                                color: AppColors.inkSubtle,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            backgroundColor: AppColors.inkAlpha(0.10),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C5CFF),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.status.name.toUpperCase()} • ${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: AppColors.inkDisabled,
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

  Widget _buildFilterBar(int totalCount, LibrarySection section) {
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
                      _buildChoiceChip('All', 'all', section),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Movies', 'movie', section),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Series', 'series', section),
                      const SizedBox(width: 6),
                      _buildChoiceChip('Anime', 'anime', section),
                      // Only under Liked: a channel cannot be watchlisted or
                      // marked watched, so offering the chip in those tabs
                      // would promise a filter with nothing behind it.
                      if (section == LibrarySection.liked) ...[
                        const SizedBox(width: 6),
                        _buildChoiceChip('Live TV', 'livetv', section),
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
                color: AppColors.raised,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.inkAlpha(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 14,
                        color: AppColors.inkMuted,
                      ),
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

  Widget _buildChoiceChip(String label, String value, LibrarySection section) {
    final isSelected = _typeFor(section) == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C5CFF) : AppColors.raised,
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
