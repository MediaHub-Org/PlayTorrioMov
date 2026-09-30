import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/tv_type.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// Top header bar for the video player.
class PlayerTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? quality;
  final VoidCallback onBack;
  final VoidCallback? onToggleEpisodes;
  final bool isEpisodesActive;
  final VoidCallback? onCast;
  final VoidCallback? onCopyStreamUrl;

  /// Downloads the source being played. Null hides the button: there is
  /// nothing to download for a file that is already local, or for a video
  /// with no title behind it (a bare magnet opened from search).
  final VoidCallback? onDownload;

  const PlayerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.quality,
    required this.onBack,
    this.onToggleEpisodes,
    this.isEpisodesActive = false,
    this.onCast,
    this.onCopyStreamUrl,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    // A phone in portrait has no room for the title *and* four actions at
    // their desktop sizes: with the download button added the row ran 45px
    // over at 360px wide. Compact trims what can give -- the margins, the
    // buttons by 4px, and the Episodes badge to its icon -- and leaves the
    // title the rest.
    final isCompact = MediaQuery.sizeOf(context).width < 480;
    final buttonSize = isCompact ? 36.0 : 40.0;
    final gap = SizedBox(width: context.rem(isCompact ? AppRem.snug : AppRem.sm));

    return Container(
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.paddingOf(context).top + context.rem(AppRem.ms),
        start: context.rem(isCompact ? 0.875 : AppRem.lg),
        end: context.rem(isCompact ? 0.875 : AppRem.lg),
        bottom: context.rem(AppRem.lg),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frosted Glass Circular Back Button
          PlayerIconButton(
            size: context.rem(2.75),
            iconSize: context.rem(1.625),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: context.l10n.playerBack,
            backgroundColor: const Color(0x33080C12),
            borderRadius: 9999, // px: a hairline, not a layout size
            onPressed: onBack,
          ),

          SizedBox(width: context.rem(isCompact ? 0.625 : AppRem.md)),

          // Title & Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppType.leadPlus,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: const Color(0x99000000),
                              offset: Offset(0, context.rem(AppRem.xxs)),
                              blurRadius: context.rem(AppRem.sm),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (quality != null && quality!.isNotEmpty) ...[
                      SizedBox(width: context.rem(AppRem.sm)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                        ),
                        child: Text(
                          quality!.toUpperCase(),
                          style: TextStyle(
                            color: const Color(0xDDFFFFFF),
                            fontSize: TvType.scale(AppType.microPlus),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: context.rem(AppRem.xxs)),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w400,
                      shadows: [
                        Shadow(
                          color: const Color(0x99000000),
                          offset: Offset(0, context.rem(0.0625)),
                          blurRadius: context.rem(AppRem.xs),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Top-Right Action Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onToggleEpisodes != null) ...[
                Tooltip(
                  message: context.l10n.detailsEpisodes,
                  child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleEpisodes,
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(horizontal: context.rem(isCompact ? 0.625 : AppRem.ms), vertical: context.rem(AppRem.sm)),
                      decoration: BoxDecoration(
                        color: isEpisodesActive
                            ? PlayerTheme.accent.withValues(alpha: 0.30)
                            : const Color(0x33080C12),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                        border: Border.all(
                          color: isEpisodesActive
                              ? PlayerTheme.accent.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.2, // px: a hairline, not a layout size
                        ),
                        boxShadow: isEpisodesActive
                            ? [
                                BoxShadow(
                                  color: PlayerTheme.accent.withValues(alpha: 0.35),
                                  blurRadius: context.rem(0.625),
                                  offset: Offset(0, context.rem(AppRem.xxs)),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.video_library_rounded,
                            size: context.rem(AppRem.iconSm),
                            color: isEpisodesActive ? const Color(0xFF9D84FF) : Colors.white,
                          ),
                          if (!isCompact) ...[
                            SizedBox(width: context.rem(0.4375)),
                            Text(
                              context.l10n.detailsEpisodes,
                              style: TextStyle(
                                color: isEpisodesActive ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                fontSize: AppType.captionPlus,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
                SizedBox(width: context.rem(isCompact ? AppRem.sm : 0.625)),
              ],
              if (onCopyStreamUrl != null) ...[
                PlayerIconButton(
                  size: buttonSize,
                  iconSize: context.rem(1.25),
                  icon: const Icon(Icons.link_rounded),
                  tooltip: context.l10n.playerCopyStreamUrl,
                  backgroundColor: const Color(0x22080C12),
                  onPressed: onCopyStreamUrl,
                ),
                gap,
              ],
              if (onDownload != null) ...[
                PlayerIconButton(
                  size: buttonSize,
                  iconSize: context.rem(1.25),
                  icon: const Icon(Icons.download_rounded),
                  tooltip: context.l10n.playerDownload,
                  backgroundColor: const Color(0x22080C12),
                  onPressed: onDownload,
                ),
                gap,
              ],
              if (onCast != null)
                PlayerIconButton(
                  size: buttonSize,
                  iconSize: context.rem(1.25),
                  icon: const Icon(Icons.cast_rounded),
                  tooltip: context.l10n.playerCast,
                  backgroundColor: const Color(0x22080C12),
                  onPressed: onCast,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
