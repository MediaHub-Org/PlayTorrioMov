import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../movie/movie_card.dart';
import 'browse_row_view.dart';
import 'custom_scroll_track.dart';
import 'error_view.dart';
import 'hero_carousel_auto_rotate.dart';
import 'poster_skeleton.dart';
import 'slider_arrow.dart';

/// One horizontal row of a [BrowseScaffold].
class BrowseRow<T> {
  /// Row heading, e.g. "Trending".
  final String title;

  /// Optional line under [title] saying what the row is, e.g. "Currently
  /// airing hits".
  final String? subtitle;

  final List<T> items;

  /// Optional "See all" target for the row's full catalog.
  final VoidCallback? onSeeAll;

  const BrowseRow({
    required this.title,
    required this.items,
    this.subtitle,
    this.onSeeAll,
  });
}

/// The shared browse layout: an auto-rotating hero of the latest items, then
/// any number of horizontal rows.
///
/// Every content section that browses a catalog uses this — Movies/Series,
/// Anime, Books, Manga — so they share one hero, one row rhythm, one card
/// size, one skeleton and one error state. Before this, each page built its
/// own arrangement (or, for Movies/Series, flattened every addon catalog into
/// a single undifferentiated grid), so the four looked and behaved differently
/// for no reason.
///
/// The scaffold owns layout only. What an item *is*, where it comes from, and
/// what a tap does all stay with the caller via [heroBuilder] and
/// [itemBuilder], which is what lets one widget serve four unrelated models.
class BrowseScaffold<T> extends StatefulWidget {
  /// Items for the hero carousel — typically the newest additions.
  final List<T> heroItems;

  final List<BrowseRow<T>> rows;

  /// Builds a full-bleed hero slide.
  final Widget Function(BuildContext context, T item) heroBuilder;

  /// Builds one poster card inside a row.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown above the hero — a search button, filters, a sub-tab bar.
  ///
  /// It sits in its own fixed band above the scroll viewport and stays
  /// there while the page scrolls, with the hero starting just below it.
  /// Deliberately *outside* the scrollable rather than an overlay pinned
  /// over it: that is what keeps it fixed without page content sliding
  /// visibly underneath a translucent strip, which is what made the
  /// pre-1.2.1 pinned header look broken.
  final Widget? header;

  /// Shown between the hero and the first row — e.g. a Continue Watching
  /// slider. Only rendered when [heroItems] is non-empty, same guard the
  /// hero itself uses, so a loading/empty page doesn't reserve space for it.
  final Widget? belowHero;

  /// Shown after every row, e.g. a Calendar row that only sometimes has
  /// content. Rendered unconditionally (the widget itself decides whether
  /// to show anything) — unlike [belowHero], not gated on [heroItems].
  final Widget? afterRows;

  final bool isLoading;

  /// Non-null renders [ErrorView] in place of the content.
  final String? error;
  final VoidCallback? onRetry;

  /// Shown when loading finished with no hero items and no rows.
  final Widget? emptyState;

  /// How often the hero advances. Null disables auto-rotation.
  final Duration? heroInterval;

  final Future<void> Function()? onRefresh;

  const BrowseScaffold({
    super.key,
    required this.heroItems,
    required this.rows,
    required this.heroBuilder,
    required this.itemBuilder,
    this.header,
    this.belowHero,
    this.afterRows,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.emptyState,
    this.heroInterval = const Duration(seconds: 7),
    this.onRefresh,
  });

  @override
  State<BrowseScaffold<T>> createState() => _BrowseScaffoldState<T>();
}

class _BrowseScaffoldState<T> extends State<BrowseScaffold<T>>
    with HeroCarouselAutoRotate<BrowseScaffold<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _restartRotation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BrowseScaffold<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The hero list arrives asynchronously, so rotation has to be (re)started
    // once it does rather than only in initState.
    if (oldWidget.heroItems.length != widget.heroItems.length ||
        oldWidget.heroInterval != widget.heroInterval) {
      _restartRotation();
    }
  }

  void _restartRotation() {
    final interval = widget.heroInterval;
    if (interval == null) {
      stopHeroAutoRotate();
      return;
    }
    startHeroAutoRotate(itemCount: widget.heroItems.length, interval: interval);
  }

  // Height-relative like Anime's and Live TV's hero carousels, not the flat
  // 240/320/420 width tiers this used to have -- those capped out well under
  // upstream's own pre-fork hero (up to 680px on desktop).
  double _heroHeight(double width, double screenHeight) {
    if (width < 600) return (screenHeight * 0.42).clamp(340.0, 420.0);
    if (width < 1100) return (screenHeight * 0.48).clamp(360.0, 480.0);
    return (screenHeight * 0.52).clamp(380.0, 560.0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizing = MovieCardSizing.fromWidth(width);

    Widget content;
    if (widget.error != null) {
      content = ErrorView(
        error: widget.error,
        onRetry: widget.onRetry ?? () {},
      );
    } else {
      final hasContent =
          widget.heroItems.isNotEmpty ||
          widget.rows.any((r) => r.items.isNotEmpty);

      content = (!widget.isLoading && !hasContent && widget.emptyState != null)
          ? widget.emptyState!
          : _buildScrollable(sizing, width);
    }

    // One arrangement for every state: the header band, a small gap, then
    // whatever the page is currently showing. The loading skeleton, the
    // error view and the empty state used to each re-derive this, and the
    // hero path put the header somewhere else again.
    final body = widget.header == null
        ? content
        : Column(
            children: [
              widget.header!,
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: content),
            ],
          );

    if (AppBreakpoints.of(context) != ScreenTier.desktop) return body;

    // The scroll-position indicator is an affordance over the page rather
    // than part of it, so it is the one thing that floats.
    return Stack(
      children: [
        body,
        Positioned(
          right: 24,
          bottom: 40,
          child: CustomScrollTrack(controller: _scrollController),
        ),
      ],
    );
  }

  Widget _buildScrollable(MovieCardSizing sizing, double width) {
    // The header is not in here at all any more -- build() puts it above
    // this viewport, so it stays put and nothing scrolls under it.
    final content = CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.isLoading)
          SliverToBoxAdapter(child: _buildLoading(sizing, width))
        else ...[
          if (widget.heroItems.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildHero(width)),
            if (widget.belowHero != null)
              SliverToBoxAdapter(child: widget.belowHero!),
          ],
          for (final row in widget.rows)
            if (row.items.isNotEmpty)
              SliverToBoxAdapter(
                child: BrowseRowView<T>(
                  title: row.title,
                  subtitle: row.subtitle,
                  items: row.items,
                  onSeeAll: row.onSeeAll,
                  itemBuilder: widget.itemBuilder,
                ),
              ),
          if (widget.afterRows != null)
            SliverToBoxAdapter(child: widget.afterRows!),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );

    if (widget.onRefresh == null) return content;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
  }

  Widget _buildHero(double width) {
    final height = _heroHeight(width, MediaQuery.sizeOf(context).height);
    return MouseRegion(
      onEnter: (_) => setState(() => isHoveringCarousel = true),
      onExit: (_) => setState(() => isHoveringCarousel = false),
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PageView.builder(
              controller: heroPageController,
              itemCount: widget.heroItems.length,
              onPageChanged: (i) => setState(() => currentHeroIndex = i),
              itemBuilder: (context, i) =>
                  widget.heroBuilder(context, widget.heroItems[i]),
            ),
            // Hover alone gates these: a touch device never fires onEnter, so
            // it never sees an arrow, and a device with a pointer does --
            // which is the actual question, unlike a width or platform check.
            if (widget.heroItems.length > 1) ...[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: isHoveringCarousel ? 12 : -60,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SliderArrow(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => goToHeroPage(
                      (currentHeroIndex - 1) % widget.heroItems.length,
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                right: isHoveringCarousel ? 12 : -60,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SliderArrow(
                    icon: Icons.arrow_forward_ios_rounded,
                    onTap: () => goToHeroPage(
                      (currentHeroIndex + 1) % widget.heroItems.length,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.heroItems.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.heroItems.length; i++)
                      GestureDetector(
                        onTap: () => goToHeroPage(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == currentHeroIndex ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == currentHeroIndex
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A hero block and two rows of shimmering posters, so the page settles into
  /// its real shape instead of jumping from a spinner to a full layout.
  Widget _buildLoading(MovieCardSizing sizing, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _heroHeight(width, MediaQuery.sizeOf(context).height),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        for (var r = 0; r < 2; r++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Container(
              width: 140,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(
            height: sizing.totalHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding),
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(width: sizing.spacing),
              itemBuilder: (_, __) => SizedBox(
                width: sizing.cardWidth,
                child: const PosterSkeleton(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
