import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../common/hover_button.dart';
import '../common/reading_direction.dart';
import '../../l10n/l10n.dart';

import '../../services/iptv/hardcoded_channels.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

/// One full-bleed Live TV hero slide: the channel's art, its name and
/// category, and the Watch / Sources actions.
///
/// Split out of the old `IptvHeroCarousel` so that [BrowseScaffold] can own
/// the carousel mechanics -- page view, arrows, dots, auto-rotation -- the
/// same way it does for Movies, Series and Anime, while Live TV keeps the
/// slide it always had.

class IptvHeroSlide extends StatelessWidget {
  final HardcodedChannel channel;
  final VoidCallback onWatchNow;
  final VoidCallback onSourcesTap;

  const IptvHeroSlide({
    super.key,
    required this.channel,
    required this.onWatchNow,
    required this.onSourcesTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final primaryColor = channel.gradient.isNotEmpty
        ? channel.gradient.first
        : palette.primaryColor;
    final secondaryColor = channel.gradient.length > 1
        ? channel.gradient.last
        : palette.accentColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient & Ambient Glow Mesh (Fallback base)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.45),
                secondaryColor.withValues(alpha: 0.20),
                AppColors.canvas,
              ],
              stops: const [0.0, 0.4, 0.9],
            ),
          ),
        ),

        // Backdrop photo if available
        if (channel.backdropUrl != null && channel.backdropUrl!.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: channel.backdropUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              memCacheWidth: 1920,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // Dark top/bottom gradient overlay for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.canvas.withValues(alpha: 0.25),
                  AppColors.canvas.withValues(alpha: 0.60),
                  AppColors.canvas.withValues(alpha: 0.92),
                  AppColors.canvas,
                ],
                stops: const [0.0, 0.42, 0.82, 1.0],
              ),
            ),
          ),
        ),

        // Left-to-right gradient overlay to make logo and buttons pop
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.canvas.withValues(alpha: 0.88),
                  AppColors.canvas.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // Content
        Positioned(
          left: context.rem(AppRem.xl),
          right: context.rem(AppRem.xl),
          bottom: context.rem(2.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // LIVE Pulse & Category row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(0.625),
                      vertical: context.rem(AppRem.xs),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                          blurRadius: context.rem(0.625),
                          offset: Offset(0, context.rem(AppRem.xxs)),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: AppColors.onAccent,
                          size: context.rem(0.875),
                        ),
                        SizedBox(width: context.rem(0.3125)),
                        Text(
                          context.l10n.iptvLiveBroadcast.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.onAccent,
                            fontSize: AppType.tiny,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.rem(0.625)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(0.625),
                      vertical: context.rem(AppRem.xs),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                      border: Border.all(
                        color: AppColors.onAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      channel.category,
                      style: TextStyle(
                        color: AppColors.onAccent.withValues(alpha: 0.70),
                        fontSize: AppType.tiny,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: context.rem(0.875)),

              // Channel Logo (instead of plain text name)
              if (channel.iconUrl != null && channel.iconUrl!.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.rem(17.5),
                    maxHeight: context.rem(4.0625),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: channel.iconUrl!,
                    alignment: mirroredIfRtl(context, Alignment.centerLeft),
                    fit: BoxFit.contain,
                    memCacheWidth: 512,
                    errorWidget: (_, __, ___) => Text(
                      channel.name,
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontSize: AppType.display,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1, // ratio: a line height, not a size
                      ),
                    ),
                  ),
                )
              else
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontSize: AppType.display,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1, // ratio: a line height, not a size
                  ),
                ),

              SizedBox(height: context.rem(AppRem.ms)),

              // Description / stream info
              Text(
                context.l10n.iptvHeroBlurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onAccent.withValues(alpha: 0.65),
                  fontSize: AppType.body,
                  height: 1.3, // ratio: a line height, not a size
                ),
              ),

              SizedBox(height: context.rem(1.125)),

              // Action Buttons
              Row(
                children: [
                  // Primary Watch Live Button
                  HoverButton(
                    scaleAmount: 1.04,
                    showFocusRing: true,
                    onTap: onWatchNow,
                    child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.lg),
                          vertical: context.rem(AppRem.ms),
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(context.rem(0.875)),
                          gradient: LinearGradient(
                            colors: [palette.primaryColor, palette.accentColor],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: context.rem(AppRem.md),
                              offset: Offset(0, context.rem(AppRem.xs)),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.onAccent,
                              size: context.rem(AppRem.iconMd),
                            ),
                            SizedBox(width: context.rem(AppRem.sm)),
                            Text(
                              context.l10n.iptvWatchLive,
                              style: const TextStyle(
                                color: AppColors.onAccent,
                                fontSize: AppType.bodyMd,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(width: context.rem(0.875)),

                  // Sources / Stream Selector Pill
                  HoverButton(
                    scaleAmount: 1.04,
                    showFocusRing: true,
                    onTap: onSourcesTap,
                    child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(1.125),
                          vertical: context.rem(AppRem.ms),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.onAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(context.rem(0.875)),
                          border: Border.all(
                            color: AppColors.onAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: AppColors.onAccent.withValues(alpha: 0.70),
                              size: context.rem(AppRem.iconSm),
                            ),
                            SizedBox(width: context.rem(AppRem.sm)),
                            Text(
                              context.l10n.iptvStreamFeeds,
                              style: const TextStyle(
                                color: AppColors.onAccent,
                                fontSize: AppType.body,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
