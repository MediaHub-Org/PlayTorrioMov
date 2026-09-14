import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/continue_watching/continue_watching_item.dart';
import '../../models/movie/movie.dart';
import '../../models/anime/anime_media.dart';
import '../../pages/details/details_page.dart';
import '../../pages/anime/anime_details_page.dart';
import '../../pages/anime_arabic/anime_arabic_details_page.dart';
import '../../services/anime_arabic/anime_arabic_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../pages/history/watch_history_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../common/slider_arrow.dart';
import '../../services/theme/app_colors.dart';

class ContinueWatchingSlider extends StatefulWidget {
  final String?
  typeFilter; // 'main', 'anime', 'movie', 'series', or null for all
  final String title;

  const ContinueWatchingSlider({
    super.key,
    this.typeFilter,
    this.title = 'Continue Watching',
  });

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
        final cardWidth = screenWidth > 900
            ? 280.0
            : screenWidth > 600
            ? 240.0
            : 200.0;
        final cardHeight = cardWidth * 0.62 + 60.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: palette.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primaryColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.primaryColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.primaryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
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
                            title: 'History',
                          ),
                        ),
                        child: const Text('See all'),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

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
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                      if (isDesktop) ...[
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          left: _canScrollLeft && _isHoveringSlider ? 10 : -60,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: SliderArrow(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => _scroll(-1),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          right: _canScrollRight && _isHoveringSlider
                              ? 10
                              : -60,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: SliderArrow(
                              icon: Icons.arrow_forward_ios_rounded,
                              onTap: () => _scroll(1),
                            ),
                          ),
                        ),
                      ],
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

  void _openDetails(BuildContext context) {
    final item = widget.item;
    if (item.id.startsWith('arabic_anime:') ||
        item.addonName == 'ArabicAnime') {
      final slug = item.id.replaceAll('arabic_anime:', '');
      final card = ArabicAnimeCard(
        slug: slug,
        title: item.title,
        cover: item.posterUrl ?? item.backdropUrl,
      );

      pushPage(
        context,
        AnimeArabicDetailsPage(
          anime: card,
          initialEpisodeNumber: item.episode,
        ),
      );
      return;
    }

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
    final item = widget.item;
    final imgHeight = widget.width * 0.58;
    final progress = item.progressPercent;
    final imageUrl = item.backdropUrl ?? item.posterUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? widget.palette.primaryColor.withValues(alpha: 0.5)
                  : AppColors.inkAlpha(0.08),
              width: _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.palette.primaryColor.withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
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
                          scale: _isHovered ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedOpacity(
                            opacity: _isHovered ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.palette.primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.palette.primaryColor
                                        .withValues(alpha: 0.5),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.onAccent,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons (Top-Right: always on mobile, hover-only on desktop)
                    if (_isHovered ||
                        !(defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.macOS ||
                            defaultTargetPlatform == TargetPlatform.linux))
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Details Button
                            Tooltip(
                              message: 'View Details',
                              child: GestureDetector(
                                onTap: () => _openDetails(context),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.75),
                                    border: Border.all(
                                      color: AppColors.onAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: AppColors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Dismiss / Remove Button
                            Tooltip(
                              message: 'Remove from Continue Watching',
                              child: GestureDetector(
                                onTap: widget.onRemove,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.75),
                                    border: Border.all(
                                      color: AppColors.onAccent.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
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
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.onAccent.withValues(alpha: 0.15),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isTorrent
                                  ? Icons.cloud_download_rounded
                                  : Icons.link_rounded,
                              size: 10,
                              color: item.isTorrent
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.addonName ??
                                  (item.isTorrent ? 'Torrent' : 'Stream'),
                              style: TextStyle(
                                fontSize: 9,
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
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.remainingMinutes > 0
                              ? '${item.remainingMinutes}m left'
                              : '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
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
                        height: 3.5,
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
                                  blurRadius: 4,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.type == 'series' &&
                                item.season != null &&
                                item.episode != null
                            ? 'S${item.season!.toString().padLeft(2, '0')}:E${item.episode!.toString().padLeft(2, '0')}${item.episodeTitle != null ? ' • ${item.episodeTitle}' : ''}'
                            : (item.year != null
                                  ? '${item.year} • Movie'
                                  : 'Movie'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkAlpha(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        child: Icon(Icons.movie_rounded, color: AppColors.onAccent.withValues(alpha: 0.24), size: 36),
      ),
    );
  }
}
