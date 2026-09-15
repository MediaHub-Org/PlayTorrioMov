import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/collection/media_collection.dart';
import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/download/download_task_model.dart';
import '../../models/movie/movie.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/collections/media_collections_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/download/download_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/collection/collection_card.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../details/details_page.dart';
import 'library_shelf_page.dart';
import '../../services/theme/app_colors.dart';

/// The Library: everything you saved, everything you started, everything on
/// the device.
///
/// The three library states used to be three of its four tabs. They are cards
/// in [LibrarySection.collections] now, beside the user's own collections --
/// see [LibrarySection] for why. This page is the shelf of shelves; opening
/// any card lands in [LibraryShelfPage], which is where titles are actually
/// listed, filtered and sorted.
class CollectionPage extends StatefulWidget {
  final int initialTabIndex;

  const CollectionPage({super.key, this.initialTabIndex = 0});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  @override
  void initState() {
    super.initState();
    AnimeLibraryService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
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
              LibrarySection.collections => _buildCollectionsTab(),
              LibrarySection.continueWatching => _buildContinueTab(),
              LibrarySection.downloads => _buildDownloadsTab(),
            },
          ),
      ],
    );
  }

  // ── Collections ───────────────────────────────────────────────────────────

  /// Built-in shelves first, then the user's collections, then the card that
  /// makes a new one.
  ///
  /// The three built-ins are always drawn, empty or not. They are where
  /// anything saved from a details page goes, so hiding an empty one would
  /// hide the answer to "where did my watchlist go?" from exactly the person
  /// who has not used it yet. A user collection is only empty because they
  /// just made it, and it has a name they chose, so the same argument applies.
  Widget _buildCollectionsTab() {
    return ValueListenableBuilder<List<MediaCollection>>(
      valueListenable: MediaCollectionsService.collections,
      builder: (context, collections, _) {
        // Counts come from MyListService, so the cards restate whatever the
        // details-page buttons last wrote without this page tracking it.
        return ValueListenableBuilder<List<MyListItem>>(
          valueListenable: MyListService.items,
          builder: (context, items, __) {
            final cards = <Widget>[
              for (final shelf in LibraryShelf.values)
                CollectionCard(
                  title: shelf.label,
                  subtitle: _countLabel(
                    items.where((i) => switch (shelf) {
                      LibraryShelf.liked => i.isLiked,
                      LibraryShelf.watchlist => i.isWatchlist,
                      LibraryShelf.watched => i.isWatched,
                    }).length,
                  ),
                  icon: shelf.icon,
                  accent: shelf.color,
                  alwaysUseIcon: true,
                  onTap: () => pushPage(
                    context,
                    LibraryShelfPage.builtIn(shelf),
                  ),
                ),
              for (final collection in collections)
                CollectionCard(
                  title: collection.name,
                  subtitle: _countLabel(collection.count),
                  posters: collection.mosaicPosters,
                  icon: Icons.playlist_play_rounded,
                  accent: AppColors.accent,
                  onTap: () => pushPage(
                    context,
                    LibraryShelfPage.collection(collection.id),
                  ),
                ),
              _NewCollectionCard(onTap: _createCollection),
            ];

            return _buildCardGrid(cards);
          },
        );
      },
    );
  }

  String _countLabel(int count) => count == 1 ? '1 title' : '$count titles';

  /// Sized from the width it actually gets rather than the screen's, so the
  /// grid is right inside a desktop side panel too. `mainAxisExtent` rather
  /// than an aspect ratio because the label under a square is a fixed height,
  /// not a fixed fraction -- with a ratio the text would grow with the card
  /// on a wide window and clip on a narrow one.
  Widget _buildCardGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        const padding = 16.0;
        // Two single lines and the gap above them, scaled the way they will
        // actually be drawn: at 200% system text a fixed 46 would overflow
        // the cell, and a grid cell has no slack to absorb it.
        final labelHeight = 8 + MediaQuery.textScalerOf(context).scale(38.0);
        final width = constraints.maxWidth;
        final crossAxisCount = width < 420
            ? 2
            : width < 700
            ? 3
            : width < 1000
            ? 4
            : width < 1400
            ? 5
            : 6;
        final tile =
            (width - padding * 2 - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(padding, 16, padding, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 18,
            mainAxisExtent: tile + labelHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New collection',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value),
          style: TextStyle(color: AppColors.ink),
          decoration: const InputDecoration(hintText: 'Collection name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final created = MediaCollectionsService.create(name);
    if (created == null) return; // Blank name.
    if (!mounted) return;
    // Straight into the new collection: it is empty, and the next thing
    // anyone wants is to see where titles will land.
    pushPage(context, LibraryShelfPage.collection(created.id));
  }

  // ── Continue ──────────────────────────────────────────────────────────────

  /// The same cards the home row shows, off one shelf instead of a strip.
  /// Dropped as a tab on 2026-09-13 for duplicating that row; back because
  /// the home row only holds what fits on screen, and this is where you look
  /// for the thing that has scrolled off it.
  Widget _buildContinueTab() {
    return ValueListenableBuilder<List<ContinueWatchingItem>>(
      valueListenable: ContinueWatchingService.activeItems,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: 'Nothing in progress',
            subtitle: 'Start something and it will wait for you here.',
          );
        }

        final palette = AppThemeService.currentPalette.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 14.0;
            const padding = 16.0;
            final width = constraints.maxWidth;
            final crossAxisCount = width < 520
                ? 1
                : width < 820
                ? 2
                : width < 1200
                ? 3
                : 4;
            final cardWidth =
                (width - padding * 2 - spacing * (crossAxisCount - 1)) /
                crossAxisCount;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(padding, 16, padding, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 16,
                // The card's own art ratio plus its text block, straight off
                // the slider, so a card is the same shape in both places.
                mainAxisExtent: cardWidth * 0.62 + 60,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ContinueWatchingCard(
                  item: item,
                  width: cardWidth,
                  palette: palette,
                  onTap: () =>
                      ContinueWatchingService.resumePlayback(context, item),
                  onRemove: () => ContinueWatchingService.removeItem(item),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
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
}

/// The last card in the grid. A card rather than a floating action button so
/// it sits in the flow after the collections it will join, which is where
/// someone scrolling to the end of their collections is already looking.
class _NewCollectionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NewCollectionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inkAlpha(0.20)),
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New collection',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
