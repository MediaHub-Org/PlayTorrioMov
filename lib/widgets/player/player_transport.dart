import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../services/tv_mode_service.dart';
import 'player_glass.dart';
import 'player_seek_bar.dart';
import 'player_volume_control.dart';
import '../../services/app_units.dart';

/// Bottom transport bar: timeline scrubber, play/pause, volume, and one
/// button per control -- stats, speed, audio, subtitles, sleep timer, aspect
/// ratio. Play/pause is also centered in its own overlay (see
/// PlayerCenterControls) for a remote's D-pad to land on; episode switching
/// lives in PlayerTopBar's own "Episodes" badge rather than here.
///
/// Six buttons share the row on a narrow phone, and the volume button takes
/// the other end only on desktop: phones own hardware buttons and TV
/// remotes their speaker, so volume is a desktop tool and mobile/TV fit
/// the six at the compact step without crowding.
class PlayerTransport extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Duration? buffered;
  final ValueListenable<Duration>? positionListenable;
  final ValueListenable<Duration?>? bufferedListenable;
  final List<MediaSkipSegment> skipSegments;
  final double volume;
  final bool isMuted;
  final double playbackRate;
  final bool isSubtitlesActive;
  final bool isPlaying;

  // Actions
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final VoidCallback onPlayPause;

  /// Opens the full subtitle panel -- track list, appearance, sync. Its
  /// first pill is Off, so turning subtitles off is still two taps rather
  /// than the one this button used to cost as a plain toggle.
  final VoidCallback onOpenSubtitleMenu;
  final VoidCallback onOpenSpeedMenu;
  final VoidCallback onOpenAudioMenu;
  final VoidCallback onOpenAspectMenu;
  final VoidCallback onOpenSleepTimerMenu;

  /// Opens the stream statistics popover. Null hides the button, for screens
  /// that have no stream figures to report.
  final VoidCallback? onOpenStatsMenu;
  final ValueChanged<bool>? onScrubbingChanged;

  /// Named stops, so a remote's Up and Down go where they should rather than
  /// to whatever is geometrically nearest (#80): from the seek bar Up is
  /// [playPauseFocusNode] and Down is [volumeFocusNode]; from anything on the
  /// bottom row Up is the seek bar. Only a TV uses them -- a pointer and a
  /// keyboard have no use for hops.
  final FocusNode? seekFocusNode;
  final FocusNode? volumeFocusNode;
  final FocusNode? playPauseFocusNode;

  const PlayerTransport({
    super.key,
    required this.position,
    required this.duration,
    this.buffered,
    this.positionListenable,
    this.bufferedListenable,
    this.skipSegments = const [],
    required this.volume,
    required this.isMuted,
    required this.playbackRate,
    required this.isSubtitlesActive,
    required this.isPlaying,
    required this.onSeek,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onPlayPause,
    required this.onOpenSubtitleMenu,
    required this.onOpenSpeedMenu,
    required this.onOpenAudioMenu,
    required this.onOpenAspectMenu,
    required this.onOpenSleepTimerMenu,
    this.onOpenStatsMenu,
    this.onScrubbingChanged,
    this.seekFocusNode,
    this.volumeFocusNode,
    this.playPauseFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    // Three buttons share the row on a narrow phone (audio, subtitles,
    // the gear), and the volume button takes the other end.
    final btnSize = context.rem(isCompact ? 2.0 : 2.625);
    final btnIconSize = context.rem(isCompact ? AppRem.icon : AppRem.iconMd);
    final gap = context.rem(isCompact ? AppRem.xxs : AppRem.xs);
    final isTv = TvModeService.isTv.value;
    // A phone's hardware buttons own its volume, and a TV remote owns its
    // speaker: neither needs our slider or mute button, so volume stays a
    // desktop tool. (Widget tests run as android, so the ones exercising
    // the volume stops override the platform back to desktop.)
    final showVolume = !isTv &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rem(isCompact ? 0.875 : 1.75),
        context.rem(isCompact ? AppRem.xl : 3),
        context.rem(isCompact ? 0.875 : 1.75),
        context.rem(isCompact ? 0.875 : AppRem.lg),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.40),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek Bar & Timers
          PlayerSeekBar(
            position: position,
            duration: duration,
            buffered: buffered,
            positionListenable: positionListenable,
            bufferedListenable: bufferedListenable,
            skipSegments: skipSegments,
            onSeek: onSeek,
            onScrubbingChanged: onScrubbingChanged,
            focusNode: seekFocusNode,
            upFocusNode: isTv ? playPauseFocusNode : null,
            downFocusNode: showVolume ? volumeFocusNode : null,
          ),

          SizedBox(height: context.rem(isCompact ? AppRem.xs : AppRem.sm)),

          // Bottom Controls Row: volume at one end, the menu triggers at
          // the other.
          // Up from anywhere on the row is the seek bar, by name: the nearest
          // thing above a button at the far edge is not always it.
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (!isTv || seekFocusNode == null) return KeyEventResult.ignored;
              if (event is! KeyDownEvent ||
                  event.logicalKey != LogicalKeyboardKey.arrowUp) {
                return KeyEventResult.ignored;
              }
              seekFocusNode!.requestFocus();
              return KeyEventResult.handled;
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Play/pause, then volume (desktop only -- see showVolume
                // above): the full slider on wide screens, a mute button on
                // compact ones. Play/pause used to live only in the centered
                // overlay; it earns a second, permanent spot here because
                // that overlay fades out with the rest of the controls, and
                // a mouse user reaching for the bar to adjust something else
                // shouldn't have to wait for it to reappear just to pause.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      tooltip: isPlaying
                          ? context.l10n.playerPause
                          : context.l10n.playerPlay,
                      onPressed: onPlayPause,
                    ),
                    if (showVolume) ...[
                      SizedBox(width: gap),
                      if (!isCompact)
                        PlayerVolumeControl(
                          volume: volume,
                          isMuted: isMuted,
                          onVolumeChanged: onVolumeChanged,
                          onToggleMute: onToggleMute,
                        )
                      else
                        PlayerIconButton(
                          focusNode: volumeFocusNode,
                          size: btnSize,
                          iconSize: btnIconSize,
                          icon: Icon(
                            isMuted || volume == 0
                                ? Icons.volume_off_rounded
                                : (volume > 1.0
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_down_rounded),
                          ),
                          tooltip: isMuted
                              ? context.l10n.playerUnmute
                              : context.l10n.playerMute,
                          onPressed: onToggleMute,
                        ),
                    ],
                  ],
                ),

                // Right group: stats, speed, audio, subtitles, sleep timer,
                // aspect -- one button each, in that order. Each of these is
                // reached for mid-stream, so each gets its own button rather
                // than a menu of menus two taps away.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stream statistics: swarm figures for a torrent, host
                    // and buffer for anything else. First in the row, ahead
                    // of the controls it describes rather than among them.
                    if (onOpenStatsMenu != null) ...[
                      PlayerIconButton(
                        size: btnSize,
                        iconSize: btnIconSize,
                        icon: const Icon(Icons.info_outline_rounded),
                        tooltip: context.l10n.playerStats,
                        onPressed: onOpenStatsMenu,
                      ),

                      SizedBox(width: gap),
                    ],

                    // Playback Speed
                    PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: const Icon(Icons.speed_rounded),
                      tooltip: context.l10n.detailsPlaybackSpeed,
                      showActiveBadge: playbackRate != 1.0,
                      onPressed: onOpenSpeedMenu,
                    ),

                    SizedBox(width: gap),

                    // Audio Track
                    PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: const Icon(Icons.audiotrack_rounded),
                      tooltip: context.l10n.detailsAudioTrack,
                      onPressed: onOpenAudioMenu,
                    ),

                    SizedBox(width: gap),

                    // Subtitles: opens the full panel. Its first pill is Off,
                    // so the toggle this button used to be is still there --
                    // one tap further, in exchange for track and appearance
                    // being one tap closer.
                    PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: const Icon(Icons.subtitles_rounded),
                      tooltip: context.l10n.detailsSubtitles,
                      showActiveBadge: isSubtitlesActive,
                      badgeColor: const Color(0xFF10B981), // Emerald
                      onPressed: onOpenSubtitleMenu,
                    ),

                    SizedBox(width: gap),

                    // Sleep Timer. The badge counts down while it runs.
                    ValueListenableBuilder<int?>(
                      valueListenable:
                          SleepTimerService.instance.minutesRemaining,
                      builder: (context, minutes, _) => PlayerIconButton(
                        size: btnSize,
                        iconSize: btnIconSize,
                        icon: const Icon(Icons.bedtime_rounded),
                        tooltip: minutes == null
                            ? context.l10n.playerSleepTimer
                            : context.l10n.playerSleepTimerLeft(minutes),
                        showActiveBadge: minutes != null,
                        onPressed: onOpenSleepTimerMenu,
                      ),
                    ),

                    SizedBox(width: gap),

                    // Aspect Ratio
                    PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: const Icon(Icons.aspect_ratio_rounded),
                      tooltip: context.l10n.detailsAspectRatio,
                      onPressed: onOpenAspectMenu,
                    ),
                  ],
                ),
              ],
            ))
,
        ],
      ),
    );
  }
}
