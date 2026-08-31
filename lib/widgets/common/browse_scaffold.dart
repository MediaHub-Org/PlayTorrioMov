import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import '../movie/movie_card.dart';
import 'browse_row_view.dart';
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
  final Widget? header;

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
  @override
  void initState() {
    super.initState();
    _restartRotation();
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
    startHeroAutoRotate(
      itemCount: widget.heroItems.length,
      interval: interval,
    );
  }

  double _heroHeight(double width) {
    if (width < 600) return 240;
    if (width < 1000) return 320;
    return 420;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizing = MovieCardSizing.fromWidth(width);

    if (widget.error != null) {
      return Column(
        children: [
          if (widget.header != null) widget.header!,
          Expanded(
            child: ErrorView(
              error: widget.error,
              onRetry: widget.onRetry ?? () {},
            ),
          ),
        ],
      );
    }

    final hasContent =
        widget.heroItems.isNotEmpty || widget.rows.any((r) => r.items.isNotEmpty);

    if (!widget.isLoading && !hasContent && widget.emptyState != null) {
      return Column(
        children: [
          if (widget.header != null) widget.header!,
          Expanded(child: widget.emptyState!),
        ],
      );
    }

    final content = CustomScrollView(
      slivers: [
        if (widget.header != null)
          SliverToBoxAdapter(child: widget.header!),
        if (widget.isLoading)
          SliverToBoxAdapter(child: _buildLoading(sizing, width))
        else ...[
          if (widget.heroItems.isNotEmpty)
            SliverToBoxAdapter(child: _buildHero(width)),
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
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );

    if (widget.onRefresh == null) return content;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
  }

  Widget _buildHero(double width) {
    final height = _heroHeight(width);
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
          height: _heroHeight(width),
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
