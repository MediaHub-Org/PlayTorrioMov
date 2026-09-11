import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/iptv/hardcoded_channels.dart';
import '../../services/theme/app_theme_service.dart';

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
                palette.scaffoldBackgroundColor,
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
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.25),
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.60),
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.92),
                  palette.scaffoldBackgroundColor,
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
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.88),
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // Content
        Positioned(
          left: 32,
          right: 32,
          bottom: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // LIVE Pulse & Category row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'LIVE BROADCAST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      channel.category,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Channel Logo (instead of plain text name)
              if (channel.iconUrl != null && channel.iconUrl!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 280,
                    maxHeight: 65,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: channel.iconUrl!,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                    memCacheWidth: 512,
                    errorWidget: (_, __, ___) => Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),

              const SizedBox(height: 12),

              // Description / stream info
              Text(
                'Instant live multi-source streaming with real-time stream resolution & high-framerate playback.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  // Primary Watch Live Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onWatchNow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [palette.primaryColor, palette.accentColor],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryColor.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Watch Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Sources / Stream Selector Pill
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onSourcesTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Stream Feeds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
