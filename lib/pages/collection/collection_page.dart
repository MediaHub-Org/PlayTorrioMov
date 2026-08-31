import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/download/download_task_model.dart';
import '../../models/movie/movie.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/download/download_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../details/details_page.dart';

class CollectionPage extends StatefulWidget {
  final int initialTabIndex;

  const CollectionPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final TextEditingController _searchController = TextEditingController();

  String _filterType = 'all'; // 'all', 'movie', 'series', 'anime'
  String _sortBy = 'recent'; // 'recent', 'title', 'year'
  String _searchQuery = '';

  /// Narrows Saved to items flagged as "watch later". This used to be its own
  /// tab, but a watchlist item is just a My List item with `isWatchlist` set,
  /// so it belongs beside the type chips rather than duplicating the whole
  /// grid, its filter bar and its empty state one tab over.
  bool _watchlistOnly = false;

  @override
  void initState() {
    super.initState();
    AnimeLibraryService.instance.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MyListItem> _getFilteredAndSortedItems(List<MyListItem> allItems) {
    var filtered = allItems.where((item) {
      if (_watchlistOnly && !item.isWatchlist) return false;
      if (_filterType == 'movie' && item.type != 'movie') return false;
      if (_filterType == 'series' && item.type != 'series' && item.type != 'anime') return false;
      if (_filterType == 'anime' && item.type != 'anime') return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final title = item.title.toLowerCase();
        if (!title.contains(query)) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'title':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'year':
        filtered.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
    }
    return filtered;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  void _navigateToDetail(MyListItem item) {
    final effectiveId = item.imdbId ??
        (item.tmdbId != null ? 'tmdb:${item.tmdbId}' : null) ??
        item.traktId?.toString() ??
        '';

    final movie = Movie(
      id: effectiveId,
      name: item.title,
      poster: item.poster,
      year: item.year?.toString(),
      type: item.type,
      addonBaseUrl: 'https://v3-cinemeta.strem.io',
    );

    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: movie),
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
        title: const Text('Remove from Library?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          'Remove "${item.title}" from your library?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              LibrarySection.history => _buildHistoryTab(),
              LibrarySection.downloads => _buildDownloadsTab(),
            },
          ),
      ],
    );
  }

  Widget _buildSavedTab() {
    return ValueListenableBuilder<List<MyListItem>>(
      valueListenable: MyListService.items,
      builder: (context, allItems, _) {
        final items = _getFilteredAndSortedItems(allItems);

        return Column(
          children: [
            _buildFilterAndSearchBar(allItems.length),
            Expanded(
              child: items.isEmpty
                  ? LibraryEmptyState(
                      icon: _watchlistOnly
                          ? Icons.bookmark_border_rounded
                          : Icons.video_library_rounded,
                      title: allItems.isEmpty
                          ? 'Nothing saved yet'
                          : (_watchlistOnly
                              ? 'Nothing on your watchlist'
                              : 'No matching items'),
                      subtitle: allItems.isEmpty
                          ? 'Add movies, series or anime to access them quickly.'
                          : (_watchlistOnly
                              ? 'Bookmark something to watch later and it lands here.'
                              : 'Try adjusting your search or filters.'),
                    )
                  : _buildGrid(items),
            ),
          ],
        );
      },
    );
  }

  /// Partway through and resumable. Reads `activeItems`, which the service
  /// purges once something is finished -- unlike History below, which keeps
  /// the full log.
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
        return _progressList(items, onRemove: null);
      },
    );
  }

  Widget _buildHistoryTab() {
    return ValueListenableBuilder<List<ContinueWatchingItem>>(
      valueListenable: ContinueWatchingService.historyItems,
      builder: (context, historyItems, _) {
        if (historyItems.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.history_rounded,
            title: 'No playback history',
            subtitle: 'Everything you watch is logged here, finished or not.',
          );
        }
        return _progressList(
          historyItems,
          onRemove: ContinueWatchingService.removeHistoryItem,
        );
      },
    );
  }

  /// The row list shared by Continue and History. They differ only in which
  /// store they read and whether a row can be dismissed, so drawing them from
  /// one builder is what stops the two drifting apart visually.
  Widget _progressList(
    List<ContinueWatchingItem> items, {
    required void Function(ContinueWatchingItem)? onRemove,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final progressPercent = (item.progressPercent * 100).toInt();

        return Container(
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
                          child: const Icon(Icons.movie_rounded,
                              color: Colors.white30),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 75,
                        color: Colors.white10,
                        child: const Icon(Icons.movie_rounded,
                            color: Colors.white30),
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
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.episodeTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'S${item.season ?? 1} E${item.episode ?? 1} \u2022 ${item.episodeTitle!}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.progressPercent,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C5CFF)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$progressPercent% completed',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: () => onRemove(item),
                ),
            ],
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
            .where((t) => t.type == 'movie' || t.type == 'series' || t.type == 'anime')
            .toList();
        if (downloads.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.download_done_rounded,
            title: 'No Downloads',
            subtitle: 'Downloaded movies and episodes will appear here for offline viewing.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: downloads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = downloads[index];
            final progress = item.totalBytes > 0 ? item.receivedBytes / item.totalBytes : 0.0;
            return Container(
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
                              child: const Icon(Icons.movie_rounded, color: Colors.white30),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 75,
                            color: Colors.white10,
                            child: const Icon(Icons.movie_rounded, color: Colors.white30),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.episodeTitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.episodeTitle!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C5CFF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.status.name.toUpperCase()} • ${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => DownloadService.instance.deleteDownload(item.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterAndSearchBar(int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search library...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildChoiceChip('All', 'all'),
              const SizedBox(width: 6),
              _buildChoiceChip('Movies', 'movie'),
              const SizedBox(width: 6),
              _buildChoiceChip('Series', 'series'),
              const SizedBox(width: 6),
              _buildChoiceChip('Anime', 'anime'),
              const SizedBox(width: 12),
              _WatchlistChip(
                selected: _watchlistOnly,
                onTap: () => setState(() => _watchlistOnly = !_watchlistOnly),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                tooltip: 'Sort by',
                onSelected: (val) => setState(() => _sortBy = val),
                color: const Color(0xFF151822),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'recent', child: Text('Recently Added')),
                  const PopupMenuItem(value: 'title', child: Text('Title (A-Z)')),
                  const PopupMenuItem(value: 'year', child: Text('Release Year')),
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

  Widget _buildGrid(List<MyListItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _navigateToDetail(item),
          onLongPress: () => _confirmRemove(item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.poster != null && item.poster!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: item.poster!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: const Color(0xFF141824)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF141824),
                      child: const Icon(Icons.movie_rounded, color: Colors.white24),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF141824),
                    child: const Icon(Icons.movie_rounded, color: Colors.white24),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

}

/// The "watch later" toggle beside the type chips.
///
/// Distinct from the type chips because it composes with them -- "Series I
/// bookmarked" is a real filter, and it would not be expressible if watchlist
/// were just a fifth mutually-exclusive chip.
class _WatchlistChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _WatchlistChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? 'Showing watchlist only' : 'Watchlist only',
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
                selected
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 14,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                'Watchlist',
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
