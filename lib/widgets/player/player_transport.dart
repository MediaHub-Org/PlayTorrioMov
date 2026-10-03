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

/// Bottom transport bar: timeline scrubber, volume, and three menu triggers --
/// stats, subtitles, and the gear holding speed, audio, sleep timer and
/// aspect ratio.
///
/// Play/pause and seek live in the centered overlay instead (see
/// PlayerCenterControls), and episode switching lives in PlayerTopBar's own
/// "Episodes" badge -- neither is duplicated here.
///
/// Six buttons shared this row before (stats, speed, audio, subtitles, sleep
/// timer, aspect). On a narrow phone the four set-once controls crowded out
/// the ones reached for mid-scene, so they moved one tap behind the gear --
/// each with its current value as a badge on its row -- while subtitles and
/// stats keep their own buttons: they are per-scene choices, not
/// set-once ones.
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

  // Actions
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  /// Opens the full subtitle panel -- track list, appearance, sync. Its
  /// first pill is Off, so turning subtitles off is still two taps rather
  /// than the one this button used to cost as a plain toggle.
  final VoidCallback onOpenSubtitleMenu;

  /// Opens the gear: speed, audio, sleep timer and aspect ratio, each with
  /// its current value on its row.
  final VoidCallback onOpenSettingsMenu;

  /// Opens the stream statistics popover. Null hides the button, for screens
  /// that have no stream figures to report.
  final VoidCallback? onOpenStatsMenu;

  /// Opens the volume panel. A TV shows a button for it where a pointer shows
  /// the slider: the slider's arrows are the ones a remote needs to move
  /// around the row, so it could not be used and could not be left (#80).
  final VoidCallback? onOpenVolumeMenu;
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
    required this.onSeek,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onOpenSubtitleMenu,
    required this.onOpenSettingsMenu,
    this.onOpenStatsMenu,
    this.onOpenVolumeMenu,
    this.onScrubbingChanged,
    this.seekFocusNode,
    this.volumeFocusNode,
    this.playPauseFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    // Three buttons share the row on a narrow phone (stats, subtitles, the
    // gear), and the volume button takes the other end.
    final btnSize = context.rem(isCompact ? 2.0 : 2.625);
    final btnIconSize = context.rem(isCompact ? AppRem.icon : AppRem.iconMd);
    final gap = context.rem(isCompact ? AppRem.xxs : AppRem.xs);
    final isTv = TvModeService.isTv.value;
    final tvVolume = isTv && onOpenVolumeMenu != null;

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
            downFocusNode: isTv ? volumeFocusNode : null,
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
                // Volume Control (Full slider on wide screens, Mute button on compact)
                if (!isCompact && !tvVolume)
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
                    tooltip: tvVolume
                        ? context.l10n.playerVolume
                        : (isMuted ? context.l10n.playerUnmute : context.l10n.playerMute),
                    onPressed: tvVolume ? onOpenVolumeMenu : onToggleMute,
                  ),

                // Right group: stats, subtitles, gear -- in that order. Speed,
                // audio, sleep timer and aspect used to stand here as their
                // own buttons, which crowded the per-scene choices on a
                // narrow phone; now they live one tap behind the gear with
                // their current values on their rows.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stream statistics: swarm figures for a torrent, host
                    // and buffer for anything else. First in the row, ahead
                    // of the control it describes rather than among them.
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

                    // The gear: speed, audio, sleep timer, aspect. The dot
                    // says something in there is off-default -- a speed, a
                    // running timer -- so it also reads as status.
                    ValueListenableBuilder<int?>(
                      valueListenable:
                          SleepTimerService.instance.minutesRemaining,
                      builder: (context, minutes, _) => PlayerIconButton(
                        size: btnSize,
                        iconSize: btnIconSize,
                        icon: const Icon(Icons.settings_rounded),
                        tooltip: context.l10n.playerSettingsPanelTitle,
                        showActiveBadge:
                            playbackRate != 1.0 || minutes != null,
                        onPressed: onOpenSettingsMenu,
                      ),
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
