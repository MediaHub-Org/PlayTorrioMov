import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/collection/media_collection.dart';
import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/download/download_task_model.dart';
import '../../models/movie/movie_year.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/app_breakpoints.dart';
import '../../services/collections/media_collections_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/download/download_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/subtitles/subtitle_languages.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/collection/collection_card.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../player/player_screen.dart';
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

  /// Type pills for the Continue Watching and Downloads tabs: All, Films,
  /// Series, Anime -- the same three kinds the shelf filter offers, so a
  /// mixed list narrows the same way everywhere in the Library.
  ///
  /// One Sort pill beside them, not a pill per order: five orders as pills
  /// would double the header, and the shelf page already answers this with
  /// one popup. Same five answers here -- recent, title both ways, year
  /// both ways -- so sorting reads the same everywhere in the Library.
  /// Genres are out on purpose: these lists mix kinds, and a genre narrow
  /// belongs to the browse pages that own genres.
  String _continueType = 'all';
  String _downloadType = 'all';
  String _continueSort = 'recent';
  String _downloadSort = 'recent';

  String _sortLabel(String sort) {
    final l10n = context.l10n;
    return switch (sort) {
      'title_az' => l10n.librarySortTitle,
      'title_za' => l10n.librarySortTitleDesc,
      'year_new' => l10n.librarySortYearNewest,
      'year_old' => l10n.librarySortYearOldest,
      _ => l10n.librarySortRecent,
    };
  }

  /// The leading four digits of a year string, or null when it carries
  /// none. Series arrive as ranges (`2022–`, `2020–2023`); sorting only
  /// ever wants the start, which [startYearOf] reads.
  static int? _yearOf(String? year) => startYearOf(year);

  Widget _buildTypePills(String current, ValueChanged<String> onPick) {
    Widget chip(String label, String value) {
      final selected = current == value;
      return GestureDetector(
        onTap: () => onPick(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.ink : AppColors.inkAlpha(0.60),
            ),
          ),
        ),
      );
    }

    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip(l10n.commonAll, 'all'),
          const SizedBox(width: 6),
          chip(l10n.libraryFilterMovies, 'movie'),
          const SizedBox(width: 6),
          chip(l10n.libraryFilterSeries, 'series'),
          const SizedBox(width: 6),
          chip(l10n.libraryFilterAnime, 'anime'),
        ],
      ),
    );
  }

  /// Type pills plus the one Sort pill, on a single header line. The pills
  /// take the room and scroll; the sort pill keeps its width, so it is
  /// always reachable without chasing the row to its end.
  Widget _buildTabHeader({
    required String type,
    required ValueChanged<String> onType,
    required String sort,
    required ValueChanged<String> onSort,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(child: _buildTypePills(type, onType)),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: '${l10n.librarySortBy}: ${_sortLabel(sort)}',
            onSelected: onSort,
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
                  // Capped, not flexed: the name is a label, and at a large
                  // text scale it names its natural width whatever the row
                  // offers. The tooltip carries the full name.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      _sortLabel(sort),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recent',
                child: Text(l10n.librarySortRecent),
              ),
              PopupMenuItem(
                value: 'title_az',
                child: Text(l10n.librarySortTitle),
              ),
              PopupMenuItem(
                value: 'title_za',
                child: Text(l10n.librarySortTitleDesc),
              ),
              PopupMenuItem(
                value: 'year_new',
                child: Text(l10n.librarySortYearNewest),
              ),
              PopupMenuItem(
                value: 'year_old',
                child: Text(l10n.librarySortYearOldest),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ContinueWatchingItem> _sortedContinue(List<ContinueWatchingItem> items) {
    final sorted = List.of(items);
    switch (_continueSort) {
      case 'title_az':
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'title_za':
        sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case 'year_new':
        sorted.sort((a, b) => (_yearOf(b.year) ?? 0).compareTo(_yearOf(a.year) ?? 0));
      case 'year_old':
        sorted.sort(
          (a, b) => (_yearOf(a.year) ?? 99999).compareTo(_yearOf(b.year) ?? 99999),
        );
      default:
        sorted.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    }
    return sorted;
  }

  List<DownloadTask> _sortedDownloads(List<DownloadTask> tasks) {
    final sorted = List.of(tasks);
    switch (_downloadSort) {
      case 'title_az':
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'title_za':
        sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case 'year_new':
        sorted.sort((a, b) => (_yearOf(b.year) ?? 0).compareTo(_yearOf(a.year) ?? 0));
      case 'year_old':
        sorted.sort(
          (a, b) => (_yearOf(a.year) ?? 99999).compareTo(_yearOf(b.year) ?? 99999),
        );
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return LibraryTabs(
      title: context.l10n.navLibrary,
      titleIcon: Icons.video_library_rounded,
      initialIndex: widget.initialTabIndex,
      tabs: [
        for (final section in LibrarySection.values)
          LibraryTab(
            label: section.localizedLabel(context),
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
                  title: shelf.localizedLabel(context),
                  subtitle: _countLabel(
                    context,
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
                  subtitle: _countLabel(context, collection.count),
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

  String _countLabel(BuildContext context, int count) =>
      context.l10n.libraryTitleCount(count);

  /// Sized from the width it actually gets rather than the screen's, so the
  /// grid is right inside a desktop side panel too. `mainAxisExtent` rather
  /// than an aspect ratio because the label under a square is a fixed height,
  /// not a fixed fraction -- with a ratio the text would grow with the card
  /// on a wide window and clip on a narrow one.
  /// How wide Library content may grow before it centers instead. Past
  /// this the grids sprawled across ultrawide windows; capped, the column
  /// counts inside each grid also settle instead of ramping forever.
  static const double _maxContentWidth = 1200;

  Widget _buildCardGrid(List<Widget> cards) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        const padding = 16.0;
        // Two single lines and the gap above them, scaled the way they will
        // actually be drawn: at 200% system text a fixed 46 would overflow
        // the cell, and a grid cell has no slack to absorb it.
        final labelHeight = 8 + MediaQuery.textScalerOf(context).scale(38.0);
        final width = constraints.maxWidth;
        // Ramps on AppBreakpoints' own cutoffs where it can. A grid
        // legitimately wants more steps than the three nav tiers, but the
        // ones it shares with them have to be the same numbers -- 700/750/800
        // are exactly how the app's breakpoints drifted apart before.
        final crossAxisCount = width < 420
            ? 2
            : width < AppBreakpoints.tablet
            ? 3
            : width < AppBreakpoints.desktop
            ? 4
            : width < 1300
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
      ),
    ),
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
          ctx.l10n.libraryNewCollection,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value),
          style: TextStyle(color: AppColors.ink),
          decoration: InputDecoration(hintText: ctx.l10n.libraryCollectionNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ctx.l10n.libraryCancel,
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.l10n.libraryCreate),
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
          return LibraryEmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: context.l10n.libraryNothingInProgress,
            subtitle: context.l10n.libraryNothingInProgressHint,
          );
        }

        final visible = _sortedContinue(
          _continueType == 'all'
              ? items
              : items.where((i) => i.type == _continueType).toList(),
        );
        final palette = AppThemeService.currentPalette.value;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 14.0;
            const padding = 16.0;
            final width = constraints.maxWidth;
            final crossAxisCount = width < AppBreakpoints.tablet
                ? 1
                : width < AppBreakpoints.desktop
                ? 2
                : width < 1300
                ? 3
                : 4;
            final cardWidth =
                (width - padding * 2 - spacing * (crossAxisCount - 1)) /
                crossAxisCount;

            return Column(
              children: [
                _buildTabHeader(
                  type: _continueType,
                  onType: (v) => setState(() => _continueType = v),
                  sort: _continueSort,
                  onSort: (v) => setState(() => _continueSort = v),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(padding, 16, padding, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: 16,
                      // The card's own art ratio plus its text block, straight off
                      // the slider, so a card is the same shape in both places.
                      mainAxisExtent: cardWidth * 0.62 + 60,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ContinueWatchingCard(
                        item: item,
                        width: cardWidth,
                        palette: palette,
                        onTap: () => ContinueWatchingService.resumePlayback(
                          context,
                          item,
                        ),
                        onRemove: () =>
                            ContinueWatchingService.removeItem(item),
                      );
                    },
                  ),
                ),
              ],
            );
            },
          ),
        ),
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
          return LibraryEmptyState(
            icon: Icons.download_done_rounded,
            title: context.l10n.libraryNoDownloads,
            subtitle: context.l10n.libraryNoDownloadsHint,
          );
        }

        final visible = _sortedDownloads(
          _downloadType == 'all'
              ? downloads
              : downloads.where((t) => t.type == _downloadType).toList(),
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                _buildTabHeader(
                  type: _downloadType,
                  onType: (v) => setState(() => _downloadType = v),
                  sort: _downloadSort,
                  onSort: (v) => setState(() => _downloadSort = v),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _DownloadRow(task: visible[index]),
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

/// One download, with what it is, how far along it is, and what can be done
/// with it.
///
/// The row used to be a poster, a title and a progress bar, and the only
/// control was Delete -- so a paused download could not be resumed, a
/// finished one could not be played, and nothing said what the file actually
/// was. Everything here is read off the task, which is why the source's
/// quality and audio languages are captured when the download starts: the
/// source object is gone by the time this is drawn.
class _DownloadRow extends StatelessWidget {
  final DownloadTask task;

  const _DownloadRow({required this.task});

  /// Whether the file is on disk. A completed task whose file was deleted
  /// outside the app would otherwise offer Play and then fail.
  bool get _fileExists {
    if (!task.isCompleted) return false;
    final path = task.targetFilePath;
    if (path.isEmpty) return false;
    return File(path).existsSync();
  }

  String _statusLabel(BuildContext context) => switch (task.status) {
    DownloadStatus.queued => context.l10n.downloadStatusQueued,
    DownloadStatus.downloading => context.l10n.downloadStatusDownloading,
    DownloadStatus.paused => context.l10n.downloadStatusPaused,
    DownloadStatus.completed => context.l10n.downloadStatusCompleted,
    DownloadStatus.failed => context.l10n.downloadStatusFailed,
    DownloadStatus.canceled => context.l10n.downloadStatusCanceled,
  };

  String _sourceLabel(BuildContext context) => switch (task.sourceType) {
    DownloadSourceType.p2p => context.l10n.downloadSourceP2p,
    DownloadSourceType.debrid => context.l10n.downloadSourceDebrid,
    DownloadSourceType.http => context.l10n.downloadSourceHttp,
  };

  /// The audio languages, as display names. `multi` is not a language, so it
  /// is shown as its own word rather than run through the language table.
  List<String> _audioLabels(BuildContext context) => task.audioLanguages
      .map(
        (key) => key == 'multi'
            ? context.l10n.subsAllLanguages
            : subtitleLanguageName(key),
      )
      .where((name) => name.isNotEmpty)
      .toList();

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.downloadDeleteConfirm),
        content: Text(context.l10n.downloadDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.downloadCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.downloadDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DownloadService.instance.deleteDownload(task.id);
    }
  }

  void _play(BuildContext context) {
    pushPage(
      context,
      PlayerScreen(
        title: task.title,
        source: task.toLocalStreamSource(),
        detail: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final progress = task.totalBytes > 0
        ? task.receivedBytes / task.totalBytes
        : 0.0;
    final audio = _audioLabels(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: task.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: task.posterUrl!,
                    width: 50,
                    height: 75,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _posterFallback(),
                  )
                : _posterFallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.episodeTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.episodeTitle!,
                    style: TextStyle(
                      color: AppColors.inkSubtle,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                _facts(context, audio),
                const SizedBox(height: 8),
                if (task.isCompleted && !_fileExists)
                  Text(
                    context.l10n.downloadFileMissingHint,
                    style: TextStyle(
                      color: AppColors.inkDisabled,
                      fontSize: 11,
                    ),
                  )
                else ...[
                  LinearProgressIndicator(
                    value: task.isCompleted
                        ? 1.0
                        : (progress > 0 ? progress : null),
                    backgroundColor: AppColors.inkAlpha(0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.isFailed ? Colors.redAccent : AppColors.accent,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _progressLine(context, progress),
                    style: TextStyle(
                      color: AppColors.inkDisabled,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actions(context),
        ],
      ),
    );
  }

  Widget _posterFallback() => Container(
    width: 50,
    height: 75,
    color: AppColors.inkAlpha(0.10),
    child: Icon(Icons.movie_rounded, color: AppColors.inkAlpha(0.30)),
  );

  /// Quality, source and audio, as one wrapping line of small chips.
  ///
  /// A `Wrap` rather than a `Row`: the audio list is variable-length, and a
  /// file tagged with four languages would otherwise run off the card.
  /// The scraper that produced the source rides along too: the delivery
  /// word (P2P / Debrid / HTTP) says how it arrived, not where it came
  /// from, and two rows that both read "1080p · HTTP" are otherwise
  /// indistinguishable.
  Widget _facts(BuildContext context, List<String> audio) {
    final scraper = task.addonName?.trim().isNotEmpty == true
        ? task.addonName!.trim()
        : task.sourceName.trim();
    final facts = <String>[
      if (task.quality != null && task.quality!.isNotEmpty) task.quality!,
      _sourceLabel(context),
      if (scraper.isNotEmpty) scraper,
      ...audio,
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (final fact in facts) _FactChip(label: fact)],
    );
  }

  String _progressLine(BuildContext context, double progress) {
    final parts = <String>[
      _statusLabel(context),
      if (task.totalBytes > 0)
        '${(progress * 100).toStringAsFixed(0)}% · ${DownloadTask.formatBytes(task.totalBytes)}'
      else if (task.isCompleted)
        DownloadTask.formatBytes(task.receivedBytes),
      if (task.isDownloading) task.speedLabel,
      if (task.isDownloading && task.etaSeconds != null) task.etaLabel,
      if (task.sourceType == DownloadSourceType.p2p && task.peers > 0)
        context.l10n.downloadPeers(task.peers),
    ];
    return parts.join(' · ');
  }

  Widget _actions(BuildContext context) {
    final buttons = <Widget>[];

    if (task.isCompleted && _fileExists) {
      buttons.add(
        _ActionButton(
          icon: Icons.play_arrow_rounded,
          tooltip: context.l10n.downloadPlay,
          onPressed: () => _play(context),
        ),
      );
    } else if (task.isDownloading) {
      buttons.add(
        _ActionButton(
          icon: Icons.pause_rounded,
          tooltip: context.l10n.downloadPause,
          onPressed: () => DownloadService.instance.pauseDownload(task.id),
        ),
      );
    } else if (task.isPaused || task.isFailed || task.status == DownloadStatus.canceled) {
      buttons.add(
        _ActionButton(
          icon: Icons.play_arrow_rounded,
          tooltip: context.l10n.downloadResume,
          onPressed: () => DownloadService.instance.resumeDownload(task.id),
        ),
      );
    }

    buttons.add(
      _ActionButton(
        icon: Icons.delete_outline_rounded,
        tooltip: context.l10n.downloadDelete,
        color: Colors.redAccent,
        onPressed: () => _confirmDelete(context),
      ),
    );

    return Column(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

/// A small label on a download row: quality, source, or an audio language.
class _FactChip extends StatelessWidget {
  final String label;

  const _FactChip({required this.label});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.inkAlpha(0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.inkMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// An icon button sized for a download row.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return IconButton(
      icon: Icon(icon, color: color ?? AppColors.inkMuted),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
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
            context.l10n.libraryNewCollection,
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
