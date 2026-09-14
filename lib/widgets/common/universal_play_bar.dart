import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/playback_coordinator.dart';
import 'like_button.dart';
import '../../services/theme/app_colors.dart';

/// A universal bottom play bar shown above the hub's content.
///
/// It reflects whatever is currently playing via the global
/// [PlaybackCoordinator], with a play/pause toggle and a stop button.
class UniversalPlayBar extends StatelessWidget {
  const UniversalPlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Built as `const UniversalPlayBar()` by HubPage, and its own
    // ValueListenableBuilder only re-runs on playback changes, so without
    // this the bar keeps the theme it was first built under.
    AppColors.dependOn(context);
    return ValueListenableBuilder<int>(
      valueListenable: PlaybackCoordinator.revision,
      builder: (context, _, __) {
        // Video (movies/series/anime/IPTV) always opens its own dedicated
        // full-screen player with its own transport controls -- this bar
        // would just duplicate them. It's only meant as a music mini-player
        // for background playback while browsing elsewhere.
        if (!PlaybackCoordinator.hasActive ||
            PlaybackCoordinator.activeKind == 'video') {
          return const SizedBox.shrink();
        }

        final title = PlaybackCoordinator.title ?? 'Now Playing';
        final subtitle = PlaybackCoordinator.subtitle ?? '';
        final coverUrl = PlaybackCoordinator.coverUrl;
        final isPlaying = PlaybackCoordinator.isPlaying;
        final kind = PlaybackCoordinator.activeKind;

        final isMobile = MediaQuery.sizeOf(context).width < 600;

        final durMs = PlaybackCoordinator.duration.inMilliseconds;
        final posMs = PlaybackCoordinator.position.inMilliseconds;
        final progress =
            durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0).toDouble() : 0.0;

        return GestureDetector(
          onTap: PlaybackCoordinator.expand,
          child: Container(
            height: 60,
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
              // Cover / icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _kindIcon(kind),
                      )
                    : _kindIcon(kind),
              ),
              const SizedBox(width: 12),
              // Title / artist — independently tappable.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Song / media title → open the full player.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: PlaybackCoordinator.expand,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      // Artist / subtitle → open the artist (music) when possible.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: PlaybackCoordinator.openArtist,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.inkSubtle,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                Text(
                  _kindLabel(kind),
                  style: TextStyle(
                    color: AppColors.inkDisabled,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Like (music tracks only)
              if (PlaybackCoordinator.canLike)
                LikeButton(
                  isLiked: PlaybackCoordinator.isLiked,
                  onTap: PlaybackCoordinator.toggleLike,
                  style: LikeButtonStyle.icon,
                  size: 20,
                ),
              // Skip back / forward, for a source with a queue. Same pair
              // the media-session notification publishes, so the bar and the
              // shade offer the same controls instead of diverging.
              if (PlaybackCoordinator.canSkipPrevious && !isMobile)
                IconButton(
                  tooltip: 'Previous',
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: AppColors.inkMuted,
                    size: 24,
                  ),
                  onPressed: PlaybackCoordinator.skipToPrevious,
                ),
              // Play / Pause
              IconButton(
                tooltip: isPlaying ? 'Pause' : 'Play',
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppColors.accent,
                  size: 34,
                ),
                onPressed: PlaybackCoordinator.togglePlayPause,
              ),
              if (PlaybackCoordinator.canSkipNext)
                IconButton(
                  tooltip: 'Next',
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.inkMuted,
                    size: 24,
                  ),
                  onPressed: PlaybackCoordinator.skipToNext,
                ),
              // Close (dismiss the bar)
              IconButton(
                tooltip: 'Close',
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.inkSubtle,
                  size: 20,
                ),
                onPressed: PlaybackCoordinator.dismiss,
              ),
            ],
                ),
                // Thin progress bar along the bottom edge.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: durMs > 0 ? progress : null,
                    minHeight: 3,
                    backgroundColor: AppColors.inkAlpha(0.10),
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kindIcon(String? kind) {
    final icon = switch (kind) {
      'video' => Icons.movie_rounded,
      _ => Icons.play_arrow_rounded,
    };
    return Container(
      width: 40,
      height: 40,
      color: AppColors.accent.withValues(alpha: 0.25),
      child: Icon(icon, color: AppColors.accent, size: 22),
    );
  }

  String _kindLabel(String? kind) {
    return switch (kind) {
      'video' => 'VIDEO',
      _ => 'PLAYING',
    };
  }
}
