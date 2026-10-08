import '../common/clamped_text_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_year.dart';
import '../../pages/details/details_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../common/interactive_card_shell.dart';
import '../common/poster_skeleton.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card sizing — a poster's width scales continuously with the window
// instead of stepping between fixed pixel values (see
// AppSpacing.cardWidthForScreenWidth, and #80 for why).
//
//   Up to 900px wide : a flat 6.75 rem (108 px at the default text size).
//   900 – 1400px wide: scales linearly from 6.75 to 10.5 rem (168 px).
//   1400px and up    : a flat 10.5 rem -- desktop browser windows and TVs
//                      both land here, and both used to get 205 px before
//                      real TV testing said that read as oversized.
//
// Aspect ratio 1:1.48  (width × 1.48 = poster height).
// Total card height = poster + 4.125 rem for title / year.
//
// The bounds are rem, so a larger text size grows the cards with it; the
// window width still decides where between them a card lands. [scale] is the
// text-size factor (AppUnits.scaleOf); the default is the 1x layout.
// ─────────────────────────────────────────────────────────────────────────────

class MovieCardSizing {
  final double cardWidth;
  final double posterHeight;
  final double totalHeight;
  final double spacing;
  final double sidePadding;

  MovieCardSizing({
    required this.cardWidth,
    required this.posterHeight,
    required this.totalHeight,
    required this.spacing,
    required this.sidePadding,
  });

  /// Sized for this context's window and text size: what a caller that has
  /// no measured width of its own should use.
  factory MovieCardSizing.of(BuildContext context) => MovieCardSizing.fromWidth(
        MediaQuery.sizeOf(context).width,
        scale: AppUnits.scaleOf(context),
      );

  factory MovieCardSizing.fromWidth(double screenWidth, {double scale = 1}) {
    final rem = AppUnits.remPixels * scale;
    final cardWidth = AppSpacing.cardWidthForScreenWidth(
      screenWidth,
      min: AppRem.cardMin * rem,
      max: AppRem.cardMax * rem,
    );

    final posterHeight = cardWidth * 1.48;
    final totalHeight = posterHeight + AppRem.cardText * rem;

    return MovieCardSizing(
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      totalHeight: totalHeight,
      spacing: AppRem.md * rem,
      // The page gutter, not a number of its own: a row's first card has
      // to line up with the section title above it and the filter bar
      // above that.
      sidePadding: AppSpacing.pageInsetForWidth(screenWidth),
    );
  }
}

/// A grid delegate that gives every poster card its real proportions.
///
/// The grids used to pass `childAspectRatio: 0.62`. A card is a poster that
/// is 1.48x its width plus a text block of fixed height, so no single ratio
/// fits: at 3 columns on a phone the cell is ~98 px wide, the ~66 px of text
/// takes a far bigger share than at 7 columns on a TV, and the poster is
/// whatever is left -- close to square. Fixing the main-axis extent instead
/// (poster = width x 1.48, plus the text) keeps the poster portrait at every
/// column count.
///
/// [contentWidth] is the width the grid lays out in, after its own padding.
SliverGridDelegateWithFixedCrossAxisCount posterGridDelegate({
  required double contentWidth,
  required int crossAxisCount,
  required double crossAxisSpacing,
  required double mainAxisSpacing,
  double scale = 1,
}) {
  final cellWidth =
      (contentWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
  final textHeight = AppRem.cardText * AppUnits.remPixels * scale;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
    mainAxisExtent: cellWidth * 1.48 + textHeight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie Card
// ─────────────────────────────────────────────────────────────────────────────

// This card's own sizes, in rem: too specific to belong in AppRem, too
// numerous to leave as bare numbers.
const double _kBadgeRadius = 0.4375;
const double _kBadgePadX = 0.375;
const double _kBadgePadY = 0.21875;
const double _kDotGap = 0.4375;
const double _kPlayInset = 0.625;
const double _kPlaySize = 2.4375;
const double _kPlayIcon = 1.8125;
const double _kPlayBlur = 1;
const double _kPlayOffset = 0.4375;

/// The card's title size, a touch above [AppType.bodyLg] so a one-line name
/// still reads at a poster's width.
const double _kTitleFont = 15.5;
const double _kRatingFont = 10.5;

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // A grid cell is a fixed box; its text is not. Capped so a
    // large system scale cannot paint outside the cell.
    return ClampedTextScale(
      child: InteractiveCardShell(
        pressedScale: 0.97,
        onTap: onTap ??
            () {
              pushPage(context, DetailsPage(movie: movie));
            },
        builder: (context, hovered, pressed) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster ──────────────────────────────────────────────
            Expanded(
              child: _PosterFrame(
                posterUrl: movie.poster,
                hovered: hovered,
                imdbRating: movie.imdbRating,
              ),
            ),

            // ── Title ───────────────────────────────────────────────
            SizedBox(height: context.rem(AppRem.posterInset)),
            Text(
              movie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: _kTitleFont,
                height: 1.15, // ratio: a line height, not a size
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25, // px: tracking, not a layout size
              ),
            ),

            // ── Year / type ─────────────────────────────────────────
            SizedBox(height: context.rem(AppRem.xs)),
            Row(
              children: [
                if (movie.year != null && movie.year!.isNotEmpty)
                  // Flexible as well as clamped: the clamp keeps this legible
                  // at ordinary settings, this stops it painting outside the
                  // cell whatever scale it is handed.
                  Flexible(
                    child: Text(
                      displayYearRange(movie.year),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.small,
                        color: AppColors.ink.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (movie.year != null && movie.year!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rem(_kDotGap)),
                    child: Container(
                      width: context.rem(AppRem.xs),
                      height: context.rem(AppRem.xs),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.26),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    movie.type == 'series' ? 'Series' : (movie.type == 'anime' ? 'Anime' : 'Movie'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppType.small,
                      color: AppColors.ink.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poster Frame — the image container with overlays, shadows, and hover FX.
// ─────────────────────────────────────────────────────────────────────────────

class _PosterFrame extends StatelessWidget {
  final String? posterUrl;
  final bool hovered;
  final String? imdbRating;

  const _PosterFrame({
    required this.posterUrl,
    required this.hovered,
    this.imdbRating,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;
    final palette = AppThemeService.currentPalette.value;
    final radius = context.rem(AppRem.radiusXl);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hovered ? 0.60 : 0.34),
            blurRadius: context.rem(hovered ? AppRem.blurXl : AppRem.blurLg),
            offset: Offset(0, context.rem(hovered ? AppRem.posterHoverOffset : AppRem.posterRestOffset)),
          ),
          if (hovered)
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.35),
              blurRadius: context.rem(AppRem.posterGlow),
              spreadRadius: 1, // px: a hairline of glow, not a size
              offset: Offset(0, context.rem(AppRem.sm)),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background fill. Fixed dark rather than a theme surface: it is
            // what shows through until the poster loads, in either theme.
            const ColoredBox(
              color: Color(0xFF171A23),
            ),

            // Poster image (cached)
            if (hasPoster)
              CachedNetworkImage(
                imageUrl: posterUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                placeholder: (context, url) => const PosterSkeleton(),
                errorWidget: (context, url, error) => const MissingPoster(),
              )
            else
              const MissingPoster(),

            // Bottom vignette gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.00),
                      Colors.black.withValues(alpha: 0.00),
                      Colors.black.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),

            // Hover highlight gradient
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0,
                duration: const Duration(milliseconds: 170),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.onAccent.withValues(alpha: 0.11),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Rating badge (top-right)
            if (imdbRating != null && imdbRating!.isNotEmpty)
              Builder(
                builder: (context) {
                  final parsed = double.tryParse(imdbRating!);
                  final displayRating = parsed != null ? (parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(1)) : imdbRating!;
                  return Positioned(
                    right: context.rem(AppRem.posterInset),
                    top: context.rem(AppRem.posterInset),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rem(_kBadgePadX),
                        vertical: context.rem(_kBadgePadY),
                      ),
                      decoration: BoxDecoration(
                        // A scrim over the poster, not a theme surface: it
                        // stays dark so the onAccent-white rating on it reads
                        // in either theme.
                        color: const Color(0xE6080A0F),
                        borderRadius: BorderRadius.circular(context.rem(_kBadgeRadius)),
                        border: Border.all(color: AppColors.onAccent.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: context.rem(AppRem.ms)),
                          SizedBox(width: context.rem(AppRem.xxs)),
                          Text(
                            displayRating,
                            style: TextStyle(
                              fontSize: TvType.scale(_kRatingFont),
                              fontWeight: FontWeight.w800,
                              color: AppColors.onAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Border glow on hover
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: hovered
                          ? AppColors.onAccent.withValues(alpha: 0.28)
                          : AppColors.onAccent.withValues(alpha: 0.08),
                      width: hovered ? 1.35 : 1, // px: a hairline border
                    ),
                  ),
                ),
              ),
            ),

            // Play button (bottom-right, hover reveal)
            Positioned(
              right: context.rem(_kPlayInset),
              bottom: context.rem(_kPlayInset),
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedScale(
                  scale: hovered ? 1 : 0.82,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: context.rem(_kPlaySize),
                    height: context.rem(_kPlaySize),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.onAccent.withValues(alpha: 0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: context.rem(_kPlayBlur),
                          offset: Offset(0, context.rem(_kPlayOffset)),
                        ),
                      ],
                    ),
                    child: Icon(
                      // Dark glyph on the white circle above, which is itself
                      // onAccent over the poster -- fixed in either theme.
                      Icons.play_arrow_rounded,
                      color: const Color(0xFF11131B),
                      size: context.rem(_kPlayIcon),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
