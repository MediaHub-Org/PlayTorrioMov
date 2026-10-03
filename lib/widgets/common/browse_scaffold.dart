import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../movie/movie_card.dart';
import 'browse_row_view.dart';
import 'error_view.dart';
import 'over_artwork.dart';
import 'hero_carousel_auto_rotate.dart';
import 'hover_button.dart';
import 'pill_filter_header_bar.dart' show pillFilterHeaderHeightOf;
import 'poster_skeleton.dart';
import 'slider_arrow.dart';
import '../../services/theme/app_colors.dart';

// The hero's height bounds, in rem: the window's own height decides where a
// hero lands between them, these only stop a short window leaving a sliver
// and a tall one a hero taller than any poster is worth.
const double _kHeroMinPhone = 21.25;
const double _kHeroMinTablet = 22.5;
const double _kHeroMinDesktop = 23.75;
const double _kFillMaxPhone = 35;
const double _kFillMaxTablet = 43.75;
const double _kFillMaxDesktop = 56.25;
const double _kDefaultMaxPhone = 26.25;
const double _kDefaultMaxTablet = 30;
const double _kDefaultMaxDesktop = 35;

// The carousel's page dots, and the loading skeleton's title bar.
const double _kDotMargin = 0.1875;
const double _kDotActive = 1.125;
const double _kTitleBoneWidth = 8.75;

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

  /// Stable key for the Home-rows visibility store. Rows without one are
  /// always shown -- Live TV keeps its own category manager, so its rows
  /// do not take part in this one.
  final String? id;

  const BrowseRow({
    required this.title,
    required this.items,
    this.subtitle,
    this.onSeeAll,
    this.id,
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

  /// Overrides [rows]' default poster sizing -- see [BrowseRowView.sizingOf].
  final RowCardSizing Function(double screenWidth, double scale)? rowSizingOf;

  /// A search button, filters, a sub-tab bar.
  ///
  /// When there's a hero to show, this floats transparently over its top
  /// edge instead of reserving its own band above it -- full-bleed hero,
  /// filters readable over the image, the way every streaming app does it.
  /// It scrolls away together with the hero rather than staying pinned:
  /// unlike a header fixed above the scroll viewport, one living inside the
  /// hero's own box can never end up with *row* content sliding underneath
  /// a translucent strip (the pre-1.2.1 bug that made a pinned header look
  /// broken), because by the time rows are on screen the hero -- and this
  /// with it -- has already scrolled past.
  ///
  /// Loading/error/empty states have no hero to float over, so this falls
  /// back to its own fixed band above the content in those states.
  final Widget? header;

  /// Shown between the hero and the first row — e.g. a Continue Watching
  /// slider. Only rendered when [heroItems] is non-empty, same guard the
  /// hero itself uses, so a loading/empty page doesn't reserve space for it.
  final Widget? belowHero;

  /// Shown after every row, e.g. a Calendar row that only sometimes has
  /// content. Rendered unconditionally (the widget itself decides whether
  /// to show anything) — unlike [belowHero], not gated on [heroItems].
  final Widget? afterRows;

  /// What this page lists, as it should read in a sentence: "Anime",
  /// "Films", "Live TV". Only the error heading uses it, but that heading used
  /// to be a default reading "movies" for every section, so Anime failed with
  /// a message about films.
  ///
  /// Pass it already translated -- `context.l10n.navAnime`, not `'anime'` --
  /// because it lands inside a translated sentence (#68).
  final String contentLabel;

  final bool isLoading;

  /// Non-null renders [ErrorView] in place of the content.
  final String? error;
  final VoidCallback? onRetry;

  /// Shown when loading finished with no hero items and no rows.
  final Widget? emptyState;

  /// How often the hero advances. Null disables auto-rotation.
  final Duration? heroInterval;

  /// Overrides the hero's height for a section that lets the user choose it.
  ///
  /// Live TV exposes three hero styles (compact / minimalist / immersive),
  /// each with its own height formula, and that setting is the reason its
  /// hero could not simply be replaced by this one. Taking the formula as a
  /// parameter keeps the setting working while still putting every section
  /// on the same scaffold; sections without such a setting leave it null and
  /// get [_defaultHeroHeight].
  final double Function(double width, double screenHeight)? heroHeightOf;

  /// Vertical space [belowHero] will occupy, given the window width.
  ///
  /// Supplying it changes how the hero is sized: instead of a fraction of
  /// the screen it takes the whole viewport minus this band, so the hero and
  /// the one row beneath it fill the screen and nothing else shows above the
  /// fold. Reserved unconditionally -- when [belowHero] has nothing to show
  /// (an empty Continue Watching list) the first content row moves up into
  /// the same space, which is the same promise for a viewer who has not
  /// watched anything yet.
  ///
  /// Sections that size their hero themselves use [heroHeightOf], which
  /// still wins over this.
  final double Function(double width, double scale)? belowHeroExtent;

  final Future<void> Function()? onRefresh;

  const BrowseScaffold({
    super.key,
    required this.heroItems,
    required this.rows,
    required this.heroBuilder,
    required this.itemBuilder,
    this.rowSizingOf,
    this.header,
    this.belowHero,
    this.afterRows,
    required this.contentLabel,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.emptyState,
    this.heroInterval = const Duration(seconds: 7),
    this.heroHeightOf,
    this.belowHeroExtent,
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

  /// The caller's own formula first; then the viewport-filling size when the
  /// caller declared a below-hero band; else [_defaultHeroHeight].
  double _heroHeight(double width, double screenHeight, double viewportHeight) {
    final custom = widget.heroHeightOf?.call(width, screenHeight);
    if (custom != null) return custom;
    final extent = widget.belowHeroExtent;
    if (extent != null && viewportHeight.isFinite && viewportHeight > 0) {
      return _fillHeroHeight(
        width,
        viewportHeight - extent(width, AppUnits.scaleOf(context)),
      );
    }
    return _defaultHeroHeight(width, screenHeight);
  }

  /// The hero takes everything the below-hero band leaves, so the fold lands
  /// at the bottom of that one row.
  ///
  /// The clamps are the guard rails on that arithmetic rather than the rule:
  /// a short window (a half-height desktop window, a phone in landscape)
  /// would otherwise leave a sliver of artwork, and a very tall one a hero
  /// taller than any poster is worth. Between those the size is exact, which
  /// is what makes it adapt to the window instead of to a breakpoint.
  double _fillHeroHeight(double width, double remaining) {
    if (width < 600) {
      return remaining.clamp(context.rem(_kHeroMinPhone), context.rem(_kFillMaxPhone));
    }
    if (width < 1100) {
      return remaining.clamp(context.rem(_kHeroMinTablet), context.rem(_kFillMaxTablet));
    }
    return remaining.clamp(context.rem(_kHeroMinDesktop), context.rem(_kFillMaxDesktop));
  }

  // Height-relative like Anime's and Live TV's hero carousels, not the flat
  // 240/320/420 width tiers this used to have -- those capped out well under
  // upstream's own pre-fork hero (up to 680px on desktop).
  double _defaultHeroHeight(double width, double screenHeight) {
    if (width < 600) {
      return (screenHeight * 0.42).clamp(context.rem(_kHeroMinPhone), context.rem(_kDefaultMaxPhone));
    }
    if (width < 1100) {
      return (screenHeight * 0.48).clamp(context.rem(_kHeroMinTablet), context.rem(_kDefaultMaxTablet));
    }
    return (screenHeight * 0.52).clamp(context.rem(_kHeroMinDesktop), context.rem(_kDefaultMaxDesktop));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizing = MovieCardSizing.fromWidth(
      width,
      scale: AppUnits.scaleOf(context),
    );

    final hasContent =
        widget.error == null &&
        (widget.heroItems.isNotEmpty ||
            widget.rows.any((r) => r.items.isNotEmpty));
    final showEmptyState =
        !widget.isLoading && !hasContent && widget.emptyState != null;

    // Whether the header can float transparently over the hero (see
    // _buildHero) instead of reserving its own band above the content:
    // only true once the hero is actually about to render, i.e. not while
    // loading, erroring, or showing the empty state.
    final headerOverlaysHero =
        widget.header != null &&
        !widget.isLoading &&
        !showEmptyState &&
        widget.heroItems.isNotEmpty;

    Widget content;
    if (widget.error != null) {
      content = ErrorView(
        title: context.l10n.catalogCouldNotLoadWhat(widget.contentLabel),
        error: widget.error,
        onRetry: widget.onRetry ?? () {},
      );
    } else if (showEmptyState) {
      content = widget.emptyState!;
    } else {
      content = _buildScrollable(
        sizing,
        width,
        // Floated over the hero, the header is drawn on a photograph, so
        // its pills keep their white glyphs in either theme. In its own
        // band below it is on the app's background and follows the ink.
        headerOverlay: headerOverlaysHero
            ? OverArtwork.yes(child: widget.header!)
            : null,
      );
    }

    return widget.header == null || headerOverlaysHero
        ? content
        : Column(
            children: [
              OverArtwork(value: false, child: widget.header!),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: content),
            ],
          );
  }

  Widget _buildScrollable(
    MovieCardSizing sizing,
    double width, {
    Widget? headerOverlay,
  }) {
    // LayoutBuilder rather than MediaQuery: the hero is sized to the space
    // this scroll view actually got, which is the screen minus the top bar,
    // the section chip row and (on a phone) the bottom tab bar and its safe
    // area. Measuring the screen instead would overshoot by all of that and
    // push the row below the hero off the fold on exactly the small screens
    // where it matters most.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildViewport(sizing, width, constraints.maxHeight, headerOverlay),
    );
  }

  Widget _buildViewport(
    MovieCardSizing sizing,
    double width,
    double viewportHeight,
    Widget? headerOverlay,
  ) {
    // When there's no header to overlay, build() puts it in its own band
    // above this viewport instead, so it stays put and nothing scrolls
    // under it.
    //
    // The first row with content gets a deterministic landing spot for a
    // D-pad/keyboard viewer -- found by identity, not index, since the loop
    // below skips empty rows. Not the hero: it auto-rotates on its own
    // timer, and stealing focus into a slide that changes out from under
    // the viewer a few seconds later would be worse than landing nowhere.
    BrowseRow<T>? firstRowWithContent;
    for (final row in widget.rows) {
      if (row.items.isNotEmpty) {
        firstRowWithContent = row;
        break;
      }
    }

    final content = CustomScrollView(
      controller: _scrollController,
      // The default cacheExtent (250px) means a row a couple of screens
      // down is not laid out at all yet, so directional focus traversal has
      // no candidate to find there -- pressing down just does nothing past
      // whatever the default window already built. 2000px covers several
      // rows' worth of look-ahead in both directions; combined with
      // HoverButton/InteractiveCardShell scrolling a newly focused card
      // into view, the viewport keeps advancing as focus does, so each
      // press builds enough of the next row for the press after it.
      cacheExtent: 2000,
      slivers: [
        if (widget.isLoading)
          SliverToBoxAdapter(
            child: _buildLoading(sizing, width, viewportHeight),
          )
        else ...[
          if (widget.heroItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildHero(
                width,
                viewportHeight,
                headerOverlay: headerOverlay,
              ),
            ),
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
                  sizingOf: widget.rowSizingOf,
                  autofocusFirstItem: identical(row, firstRowWithContent),
                ),
              ),
          if (widget.afterRows != null)
            SliverToBoxAdapter(child: widget.afterRows!),
        ],
        SliverToBoxAdapter(child: SizedBox(height: context.rem(AppRem.pageTail))),
      ],
    );

    if (widget.onRefresh == null) return content;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
  }

  Widget _buildHero(
    double width,
    double viewportHeight, {
    Widget? headerOverlay,
  }) {
    final height = _heroHeight(
      width,
      MediaQuery.sizeOf(context).height,
      viewportHeight,
    );
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
              // The slide is the artwork. Anything shared it builds -- a
              // genre chip, a pill -- reads this rather than guessing.
              itemBuilder: (context, i) => OverArtwork.yes(
                child: widget.heroBuilder(context, widget.heroItems[i]),
              ),
            ),
            if (headerOverlay != null) ...[
              // A per-slide hero image has no guaranteed top scrim of its
              // own (most only fade left-to-right, for the title text), so
              // a transparent header floating over it needs one here,
              // centralized, rather than every heroBuilder adding its own.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: pillFilterHeaderHeightOf(context) * 2, // ratio: two bars tall
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Fixed dark, not a theme surface: this is the scrim
                      // that makes the header legible over the hero, and it is
                      // why the pills above it are onAccent-white in both
                      // themes (see OverArtwork).
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC080A0F), Color(0x00080A0F)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: headerOverlay),
            ],
            // Hover alone gates these: a touch device never fires onEnter, so
            // it never sees an arrow, and a device with a pointer does --
            // which is the actual question, unlike a width or platform check.
            if (widget.heroItems.length > 1) ...[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: context.rem(isHoveringCarousel ? AppRem.ms : -AppRem.arrowParked),
                top: 0,
                bottom: 0,
                child: Center(
                  child: ExcludeFocus(
                    // Hidden arrows are parked off-screen until a pointer hovers;
                    // a D-pad must not be able to focus what it cannot see.
                    excluding: !isHoveringCarousel,
                    child: SliderArrow(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => goToHeroPage(
                        (currentHeroIndex - 1) % widget.heroItems.length,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                right: context.rem(isHoveringCarousel ? AppRem.ms : -AppRem.arrowParked),
                top: 0,
                bottom: 0,
                child: Center(
                  child: ExcludeFocus(
                    // Hidden arrows are parked off-screen until a pointer hovers;
                    // a D-pad must not be able to focus what it cannot see.
                    excluding: !isHoveringCarousel,
                    child: SliderArrow(
                      icon: Icons.arrow_forward_ios_rounded,
                      onTap: () => goToHeroPage(
                        (currentHeroIndex + 1) % widget.heroItems.length,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.heroItems.length > 1)
              Positioned(
                bottom: context.rem(AppRem.ms),
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.heroItems.length; i++)
                      HoverButton(
                        scaleAmount: 1.3,
                        showFocusRing: true,
                        focusRingBorderRadius: context.rem(_kDotMargin) + context.rem(AppRem.xxs),
                        onTap: () => goToHeroPage(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.symmetric(horizontal: context.rem(_kDotMargin)),
                          width: context.rem(i == currentHeroIndex ? _kDotActive : AppRem.snug),
                          height: context.rem(AppRem.snug),
                          decoration: BoxDecoration(
                            color: i == currentHeroIndex
                                ? AppColors.onAccent
                                : AppColors.onAccent.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(context.rem(_kDotMargin)),
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
  Widget _buildLoading(
    MovieCardSizing sizing,
    double width,
    double viewportHeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _heroHeight(
            width,
            MediaQuery.sizeOf(context).height,
            viewportHeight,
          ),
          margin: EdgeInsets.only(bottom: context.rem(AppRem.md)),
          color: AppColors.inkAlpha(0.04),
        ),
        for (var r = 0; r < 2; r++) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageInset(context),
              context.rem(AppRem.sm),
              AppSpacing.pageInset(context),
              context.rem(AppRem.ms),
            ),
            child: Container(
              width: context.rem(_kTitleBoneWidth),
              height: context.rem(AppRem.icon),
              decoration: BoxDecoration(
                color: AppColors.inkAlpha(0.06),
                borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
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
          SizedBox(height: context.rem(AppRem.md)),
        ],
      ],
    );
  }
}
