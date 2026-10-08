import '../common/clamped_text_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/movie/movie.dart';
import '../../models/anime/anime_media.dart';
import '../../pages/details/details_page.dart';
import '../../pages/anime/anime_details_page.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../pages/history/watch_history_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import 'package:flutter/services.dart';
import '../common/hover_button.dart';
import '../common/slider_arrow.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';
import '../common/activate_keys.dart';

class ContinueWatchingSlider extends StatefulWidget {
  final String?
  typeFilter; // 'main', 'anime', 'movie', 'series', or null for all
  final String? title;

  const ContinueWatchingSlider({
    super.key,
    this.typeFilter,
    this.title,
  });

  /// Height of the section header line (accent bar, title, count, "See all").
  ///
  /// Pinned rather than intrinsic so [bandHeight] can be exact: the tallest
  /// child is the "See all" TextButton, which only exists once something has
  /// been watched to the end, and a band that changed height when it appeared
  /// would shift the hero above it. 48 because that is what the row already
  /// measured whenever the button was there -- a Material tap target with the
  /// default padded sizing -- so pinning it keeps the look the button case
  /// already had rather than imposing a new one.
  ///
  /// Every size here is rem and every function below takes the text-size
  /// factor ([AppUnits.scaleOf]; the default is the 1x layout), so the band
  /// stays a pure function of the window and the text size and
  /// [BrowseScaffold] can still derive it without building the widget.
  static const double _headerHeightRem = 3;

  /// Gap between the header line and the cards.
  static const double _headerGapRem = 0.75;

  /// Space below the cards, before whatever row comes next.
  static const double _bottomGapRem = 1.75;

  /// The title and progress block under a card's artwork.
  static const double _textBlockRem = 3.75;

  static double _px(double rem, double scale) => rem * AppUnits.remPixels * scale;

  /// Width of one card at [screenWidth]. The row's card size is a step
  /// function of the window, not of the card count.
  static double cardWidthFor(double screenWidth, [double scale = 1]) => _px(
        screenWidth > 900
            ? 17.5
            : screenWidth > 600
                ? 15
                : 12.5,
        scale,
      );

  /// Height of one card: artwork at 0.62 of its width, plus the fixed
  /// title/progress block beneath it.
  static double cardHeightFor(double screenWidth, [double scale = 1]) =>
      cardWidthFor(screenWidth, scale) * 0.62 + _px(_textBlockRem, scale); // ratio: artwork's share of the card

  /// Total vertical space this widget occupies when it has anything to show.
  ///
  /// [BrowseScaffold] sizes its hero to `viewport - bandHeight` so that the
  /// hero and this one row fill the screen exactly, which is why the number
  /// has to be derivable without building the widget. Every term is used by
  /// [build] too, so the two cannot drift.
  static double bandHeight(double screenWidth, [double scale = 1]) =>
      _px(_headerHeightRem + _headerGapRem + _bottomGapRem, scale) +
      cardHeightFor(screenWidth, scale);

  @override
  State<ContinueWatchingSlider> createState() => _ContinueWatchingSliderState();
}

class _ContinueWatchingSliderState extends State<ContinueWatchingSlider> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHoveringSlider = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final canLeft = _scrollController.position.pixels > 10;
    final canRight =
        _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 10;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double directionMultiplier) {
    if (!_scrollController.hasClients) return;
    final viewportWidth = _scrollController.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.8 * directionMultiplier;
    final target = (_scrollController.position.pixels + scrollAmount).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final isDesktop = _isDesktop();

    return ValueListenableBuilder<List<ContinueWatchingItem>>(
      valueListenable: ContinueWatchingService.activeItems,
      builder: (context, allItems, _) {
        final items = allItems
            .where(
              (i) =>
                  ContinueWatchingService.matchesTypeFilter(i, widget.typeFilter),
            )
            .toList();

        if (items.isEmpty) return const SizedBox.shrink();

        final screenWidth = MediaQuery.sizeOf(context).width;
        final scale = AppUnits.scaleOf(context);
        final cardWidth = ContinueWatchingSlider.cardWidthFor(screenWidth, scale);
        final cardHeight = ContinueWatchingSlider.cardHeightFor(screenWidth, scale);

        return Padding(
          padding: EdgeInsets.only(
            bottom: ContinueWatchingSlider._px(ContinueWatchingSlider._bottomGapRem, scale),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              SizedBox(
                height: ContinueWatchingSlider._px(ContinueWatchingSlider._headerHeightRem, scale),
                // headerHeight is pinned so bandHeight stays exact whether
                // or not "See all" is showing -- see its doc. Pinned means
                // the 18px title, the count pill and the button have
                // nowhere to go when the system text scale grows, so the
                // scale is capped here instead: the header still responds
                // to a larger setting, just not past the box it lives in.
                // Same 1.3 ceiling the nav bar and the pill rows use.
                child: ClampedTextScale(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rem(1.125)),
                    child: Row(
                      children: [
                        Container(
                          width: context.rem(AppRem.xs),
                          height: context.rem(1.125),
                          decoration: BoxDecoration(
                            color: palette.primaryColor,
                            borderRadius: BorderRadius.circular(context.rem(AppRem.xxs)),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryColor.withValues(alpha: 0.5),
                                blurRadius: context.rem(AppRem.sm),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: context.rem(0.625)),
                        // Title and count take the space "See all" does not,
                        // and the title gives way first. Laid out flat with a
                        // Spacer, the title demanded its natural width and
                        // pushed the button off the edge -- 88px of overflow on
                        // a 420px-wide phone with any watch history, and more
                        // for a longer title than the English one.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title ?? context.l10n.continueWatchingTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppType.lead,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              SizedBox(width: context.rem(AppRem.sm)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rem(0.4375),
                                  vertical: context.rem(AppRem.xxs),
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primaryColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                                  border: Border.all(
                                    color: palette.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 0.8, // px: a hairline, not a layout size
                                  ),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: TextStyle(
                                    fontSize: AppType.tiny,
                                    fontWeight: FontWeight.w700,
                                    color: palette.primaryColor,
                                  ),
                                ),
                              ),
                              // Takes the slack the title did not need, so the
                              // count stays beside the title rather than
                              // drifting across to the button.
                              const Spacer(),
                            ],
                          ),
                        ),
                        // The row shows one card per show and drops a title once
                        // it is finished; the full per-episode log lives behind
                        // this. It was being recorded all along with nothing to
                        // render it.
                        if (ContinueWatchingService.historyItems.value.any(
                          (i) => ContinueWatchingService.matchesTypeFilter(
                            i,
                            widget.typeFilter,
                          ),
                        ))
                          TextButton(
                            onPressed: () => pushPage(
                              context,
                              WatchHistoryPage(
                                typeFilter: widget.typeFilter,
                                title: context.l10n.historyTitle,
                              ),
                            ),
                            child: Text(context.l10n.continueWatchingSeeAll),
                          ),
                      ],
                    ),
                  )),
              ),

              SizedBox(height: ContinueWatchingSlider._px(ContinueWatchingSlider._headerGapRem, scale)),

              // Horizontal Card Slider with Desktop Floating Arrows
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringSlider = true),
                onExit: (_) => setState(() => _isHoveringSlider = false),
                child: SizedBox(
                  height: cardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ListView.separated(
                        clipBehavior: Clip.none,
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: context.rem(1.125)),
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => SizedBox(width: context.rem(0.875)),
                        itemBuilder: (context, index) {
                          final item = items[index];
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

                      // Desktop Floating Scroll Arrows (Matching Anime/Movie Sections)
                      if (isDesktop)
                        RailEdgeArrows(
                          visible: _isHoveringSlider,
                          canGoPrevious: _canScrollLeft,
                          canGoNext: _canScrollRight,
                          onPrevious: () => _scroll(-1),
                          onNext: () => _scroll(1),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One Continue Watching card: art, progress, and a remove affordance.
///
/// Public because the watch-history view renders the same thing; the only
/// difference there is which list it is fed from and what removing means.
class ContinueWatchingCard extends StatefulWidget {
  final ContinueWatchingItem item;
  final double width;
  final AppThemePalette palette;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.width,
    required this.palette,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<ContinueWatchingCard> createState() => ContinueWatchingCardState();
}

class ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!kActivateKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  void _openDetails(BuildContext context) {
    final item = widget.item;
    if (item.type == 'anime' || item.id.startsWith('anilist:')) {
      final anilistId = int.tryParse(item.id.replaceAll('anilist:', '')) ?? 0;
      final anime = AnimeMedia(
        id: anilistId,
        titleEnglish: item.title,
        titleRomaji: item.title,
        titleNative: '',
        titleUserPreferred: item.title,
        coverImageLarge: item.posterUrl ?? '',
        coverImageExtraLarge: item.posterUrl ?? '',
        bannerImage: item.backdropUrl ?? '',
        description: '',
        seasonYear: int.tryParse(item.year ?? '') ?? 0,
        averageScore: 0,
        genres: const [],
        format: 'TV',
        status: 'RELEASING',
        totalEpisodes: 0,
      );

      pushPage(context, AnimeDetailsPage(anime: anime));
    } else {
      final movie = Movie(
        id: item.id,
        name: item.title,
        poster: item.posterUrl ?? item.backdropUrl,
        year: item.year,
        type: item.type,
        addonBaseUrl: '',
      );

      pushPage(context, DetailsPage(movie: movie));
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final item = widget.item;
    final imgHeight = widget.width * 0.58;
    final progress = item.progressPercent;
    final imageUrl = item.backdropUrl ?? item.posterUrl;
    final hovered = _isHovered || _isFocused;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          transform: hovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(context.rem(0.875)),
            border: Border.all(
              color: hovered
                  ? widget.palette.primaryColor.withValues(alpha: 0.5)
                  : AppColors.inkAlpha(0.08),
              width: hovered ? 1.4 : 1.0, // px: a border weight
            ), // px: a hairline, not a layout size
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: widget.palette.primaryColor.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: context.rem(1.125),
                      offset: Offset(0, context.rem(AppRem.xs)),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.rem(0.875)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Backdrop / Thumbnail with Play Overlay & Badge
                Stack(
                  children: [
                    Container(
                      width: widget.width,
                      height: imgHeight,
                      // What shows through until the thumbnail loads, so it
                      // stays a fixed dark in either theme -- same reason as
                      // _buildPlaceholder below.
                      color: const Color(0xFF1E212E),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Centered Play Button on hover
                    Positioned.fill(
                      child: Center(
                        child: AnimatedScale(
                          scale: hovered ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedOpacity(
                            opacity: hovered ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              width: context.rem(2.75),
                              height: context.rem(2.75),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.palette.primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.palette.primaryColor
                                        .withValues(alpha: 0.5),
                                    blurRadius: context.rem(0.875),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.onAccent,
                                size: context.rem(1.75),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons (Top-Right: always on mobile, hover/focus-only on desktop)
                    if (hovered ||
                        !(defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.macOS ||
                            defaultTargetPlatform == TargetPlatform.linux))
                      Positioned(
                        top: context.rem(AppRem.snug),
                        right: context.rem(AppRem.snug),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Details Button
                            Tooltip(
                              message: context.l10n.homeViewDetails,
                              child: HoverButton(
                                scaleAmount: 1.1,
                                showFocusRing: true,
                                onTap: () => _openDetails(context),
                                child: Container(
                                  padding: EdgeInsets.all(context.rem(AppRem.xs)),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.75),
                                    border: Border.all(
                                      color: AppColors.onAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ), // px: a hairline, not a layout size
                                  ),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: context.rem(0.875),
                                    color: AppColors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: context.rem(AppRem.snug)),
                            // Dismiss / Remove Button
                            Tooltip(
                              message: context.l10n.homeRemoveFromContinue,
                              child: HoverButton(
                                scaleAmount: 1.1,
                                showFocusRing: true,
                                onTap: widget.onRemove,
                                child: Container(
                                  padding: EdgeInsets.all(context.rem(AppRem.xs)),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.75),
                                    border: Border.all(
                                      color: AppColors.onAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ), // px: a hairline, not a layout size
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: context.rem(0.875),
                                    color: AppColors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Source Tag (Top-Left)
                    Positioned(
                      top: context.rem(AppRem.snug),
                      left: context.rem(AppRem.snug),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.snug),
                          vertical: context.rem(AppRem.xxs),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                          border: Border.all(
                            color: AppColors.onAccent.withValues(alpha: 0.15),
                            width: 0.6,
                          ), // px: a hairline, not a layout size
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isTorrent
                                  ? Icons.cloud_download_rounded
                                  : Icons.link_rounded,
                              size: context.rem(0.625),
                              color: item.isTorrent
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF10B981),
                            ),
                            SizedBox(width: context.rem(AppRem.xs)),
                            Text(
                              item.addonName ??
                                  (item.isTorrent
                                      ? context.l10n.continueTorrent
                                      : context.l10n.continueStream),
                              style: TextStyle(
                                fontSize: TvType.scale(AppType.nano),
                                fontWeight: FontWeight.w600,
                                color: AppColors.onAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Remaining time / Percentage (Bottom-Right)
                    Positioned(
                      bottom: context.rem(AppRem.snug),
                      right: context.rem(AppRem.snug),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.snug),
                          vertical: context.rem(AppRem.xxs),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(context.rem(0.3125)),
                        ),
                        child: Text(
                          item.remainingMinutes > 0
                              ? context.l10n.continueMinutesLeft(
                                  item.remainingMinutes,
                                )
                              : '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: TvType.scale(AppType.micro),
                            fontWeight: FontWeight.w600,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Progress Bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: context.rem(0.2188),
                        color: AppColors.onAccent.withValues(alpha: 0.15),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.palette.primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.palette.primaryColor.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: context.rem(AppRem.xs),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Title and Episode Metadata
                //
                // cardHeightFor reserves a flat 60px for this block, and
                // bandHeight is deliberately a pure function of width --
                // BrowseScaffold has to derive it without building the
                // widget -- so the reservation cannot grow with the text.
                // The block is capped to match, at the same 1.3 the rest of
                // the app's fixed-height chrome uses. Measured: the two
                // lines plus their 8px padding fit 60px up to about 1.75x,
                // so 1.3 keeps real slack rather than sitting on the edge.
                ClampedTextScale(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.rem(0.625), context.rem(AppRem.sm), context.rem(0.625), context.rem(AppRem.sm)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(0.1875)),
                        Text(
                          item.type == 'series' &&
                                  item.season != null &&
                                  item.episode != null
                              ? 'S${item.season!.toString().padLeft(2, '0')}:E${item.episode!.toString().padLeft(2, '0')}${item.episodeTitle != null ? ' • ${item.episodeTitle}' : ''}'
                              : (item.year != null
                                    ? '${item.year} • ${context.l10n.continueMovie}'
                                    : context.l10n.continueMovie),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppType.tiny,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkAlpha(0.55),
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      // Artwork stand-in, not a theme surface: stays dark in either theme.
      color: const Color(0xFF1A1D27),
      child: Center(
        child: Icon(Icons.movie_rounded, color: AppColors.onAccent.withValues(alpha: 0.24), size: context.rem(2.25)),
      ),
    );
  }
}
