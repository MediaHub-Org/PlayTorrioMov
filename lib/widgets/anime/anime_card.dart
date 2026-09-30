import '../common/clamped_text_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/anime/anime_media.dart';
import '../../services/app_units.dart';
import '../../services/titles/title_display.dart';
import '../../services/theme/app_theme_service.dart';
import '../common/poster_skeleton.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';

// This card's own sizes, in rem (the shared poster ones are in AppRem).
const double _kBadgePadX = 0.4375;
const double _kBadgePadY = 0.21875;
const double _kBadgeRadius = 0.5;
const double _kTagPadY = 0.1875;
const double _kTagRadius = 0.4375;
const double _kDotGap = 0.4375;
const double _kStarSize = 0.8125;
const double _kPlayPad = 0.4375;
const double _kPlayIcon = 1;
const double _kLift = 0.375;
const double _kTitleFont = 15.5;
const double _kScoreFont = 11;
const double _kTagFont = 9.5;

/// The keys that activate a focused [AnimeCard]. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that inside
/// a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

class AnimeCard extends StatefulWidget {
  final AnimeMedia anime;
  final VoidCallback onTap;
  final double? width;

  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.width,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final anime = widget.anime;
    final hovered = _hovered || _focused;

    // A grid cell is a fixed box; its text is not. Capped so a
    // large system scale cannot paint outside the cell.
    return ClampedTextScale(
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _handleKey,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.97 : (hovered ? 1.045 : 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hovered ? -context.rem(_kLift) : 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Frame
                  Expanded(
                    child: _AnimePosterFrame(
                      anime: anime,
                      hovered: hovered,
                    ),
                  ),

                  // Title
                  SizedBox(height: context.rem(AppRem.posterInset)),
                  Text(
                    animeDisplayTitle(anime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _kTitleFont,
                      height: 1.15, // ratio: a line height, not a size
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25, // px: tracking, not a layout size
                      color: AppColors.ink,
                    ),
                  ),

                  // Year / Format / Genre
                  SizedBox(height: context.rem(AppRem.xs)),
                  Row(
                    children: [
                      if (anime.seasonYear > 0) ...[
                        // The genre beside it is already Expanded; the year
                        // was not, so it took its natural width and pushed
                        // the row past the cell at a large scale.
                        Flexible(
                          child: Text(
                            '${anime.seasonYear}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppType.small,
                              color: AppColors.inkAlpha(0.52),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(_kDotGap)),
                          child: Container(
                            width: context.rem(AppRem.xs),
                            height: context.rem(AppRem.xs),
                            decoration: BoxDecoration(
                              color: AppColors.inkAlpha(0.26),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          anime.genres.isNotEmpty
                              ? anime.genres.first
                              : anime.formattedFormat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppType.small,
                            color: AppColors.inkAlpha(0.42),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _AnimePosterFrame extends StatelessWidget {
  final AnimeMedia anime;
  final bool hovered;

  const _AnimePosterFrame({
    required this.anime,
    required this.hovered,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final posterUrl = anime.coverUrl;
    final hasPoster = posterUrl.isNotEmpty;
    final radius = context.rem(AppRem.radiusXl);
    final inset = context.rem(AppRem.posterInset);

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
              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.28),
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
            // Stands in for artwork that has not loaded, so it keeps a fixed
            // dark fill in either theme -- as does anything drawn on it.
            const ColoredBox(color: Color(0xFF171A23)),

            // Poster Image
            if (hasPoster)
              CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                placeholder: (context, url) => const PosterSkeleton(),
                errorWidget: (context, url, error) => const MissingPoster(),
              )
            else
              const MissingPoster(),

            // Vignette Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),

            // Top Left Rating Badge
            if (anime.averageScore > 0)
              Positioned(
                top: inset,
                left: inset,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rem(_kBadgePadX),
                    vertical: context.rem(_kBadgePadY),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(context.rem(_kBadgeRadius)),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      width: 1, // px: a hairline border
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: context.rem(_kStarSize),
                        color: const Color(0xFFFFD700),
                      ),
                      SizedBox(width: context.rem(AppRem.xxs)),
                      Text(
                        anime.formattedScore,
                        style: const TextStyle(
                          fontSize: _kScoreFont,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Overlay with Episode Count
            if (anime.totalEpisodes > 0)
              Positioned(
                bottom: inset,
                left: inset,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rem(_kBadgePadX),
                    vertical: context.rem(_kTagPadY),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(context.rem(_kTagRadius)),
                  ),
                  child: Text(
                    context.l10n.animeEpsShort(anime.totalEpisodes),
                    style: TextStyle(
                      fontSize: TvType.scale(_kTagFont),
                      fontWeight: FontWeight.bold,
                      color: AppColors.onAccent.withValues(alpha: 0.70),
                    ),
                  ),
                ),
              ),

            // Hover Play Glow Icon
            if (hovered)
              Positioned(
                bottom: inset,
                right: inset,
                child: Container(
                  padding: EdgeInsets.all(context.rem(_kPlayPad)),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.onAccent,
                    size: context.rem(_kPlayIcon),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
