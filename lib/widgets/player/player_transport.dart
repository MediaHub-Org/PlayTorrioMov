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
/// audio, subtitles, and the gear holding quality, speed, sleep timer,
/// aspect ratio and stats.
///
/// Play/pause and seek live in the centered overlay instead (see
/// PlayerCenterControls), and episode switching lives in PlayerTopBar's own
/// "Episodes" badge -- neither is duplicated here.
///
/// Audio and subtitles keep their own buttons because they are the two
/// per-scene choices a viewer reaches for mid-sentence; everything
/// set-once lives one tap behind the gear. Stats used to stand here too,
/// but diagnostics do not earn a per-scene button, so they moved into the
/// gear to keep the 2x2 symmetric.
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

  /// Opens the audio track panel straight away: with subtitles, the other
  /// per-scene choice, so both skip the gear.
  final VoidCallback onOpenAudioMenu;

  /// Opens the gear: quality, speed, sleep timer, aspect ratio and stats,
  /// each with its current value on its card.
  final VoidCallback onOpenSettingsMenu;

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
    required this.onOpenAudioMenu,
    required this.onOpenSettingsMenu,
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
    // Three buttons share the row on a narrow phone (audio, subtitles,
    // the gear), and the volume button takes the other end.
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

                // Right group: audio, subtitles, gear -- in that order. The two
                // per-scene choices stand here because they are reached for
                // mid-sentence; quality, speed, sleep timer, aspect and
                // stats live one tap behind the gear with their current
                // values on their cards.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio tracks: the hearing twin of the subtitles button.
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

                    // The gear: quality, speed, sleep timer, aspect, stats.
                    // The dot says something in there is off-default -- a
                    // speed, a running timer -- so it also reads as status.
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
