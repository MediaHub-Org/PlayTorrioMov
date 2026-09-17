import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';
import 'player_seek_bar.dart';
import 'player_volume_control.dart';

/// Bottom transport bar: timeline scrubber, volume, and one button per
/// control -- speed, audio, subtitles, sleep timer, aspect ratio. Play/pause
/// and seek live in the centered overlay instead (see PlayerCenterControls),
/// and episode switching lives in PlayerTopBar's own "Episodes" badge --
/// neither is duplicated here.
///
/// There is no settings button. The gear used to be an index of every
/// control here, then held only the subtitle entry and the sleep timer once
/// those grew their own buttons -- a menu for one control is worse than a
/// button for it, so the subtitle button opens the full subtitle panel
/// (whose first pill is Off, keeping the toggle) and the sleep timer is a
/// button of its own.
///
/// This bar briefly carried a ±30s pair of its own. It was removed once the
/// centered buttons became ±30s: one amount, one affordance. Seeking now has
/// exactly two ways in -- the double-tap side zones for ±10s and those
/// centered buttons for ±30s -- instead of three, two of which did the same
/// thing.
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
  final VoidCallback onOpenSpeedMenu;
  final VoidCallback onOpenAudioMenu;
  final VoidCallback onOpenAspectMenu;
  final VoidCallback onOpenSleepTimerMenu;
  final ValueChanged<bool>? onScrubbingChanged;

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
    required this.onOpenSpeedMenu,
    required this.onOpenAudioMenu,
    required this.onOpenAspectMenu,
    required this.onOpenSleepTimerMenu,
    this.onScrubbingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    final btnSize = isCompact ? 36.0 : 42.0;
    final btnIconSize = isCompact ? 20.0 : 22.0;
    final gap = isCompact ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 14 : 28,
        isCompact ? 32 : 48,
        isCompact ? 14 : 28,
        isCompact ? 14 : 24,
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
          ),

          SizedBox(height: isCompact ? 4 : 8),

          // Bottom Controls Row: volume at one end, the menu triggers at
          // the other.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Volume Control (Full slider on wide screens, Mute button on compact)
              if (!isCompact)
                PlayerVolumeControl(
                  volume: volume,
                  isMuted: isMuted,
                  onVolumeChanged: onVolumeChanged,
                  onToggleMute: onToggleMute,
                )
              else
                PlayerIconButton(
                  size: btnSize,
                  iconSize: btnIconSize,
                  icon: Icon(
                    isMuted || volume == 0
                        ? Icons.volume_off_rounded
                        : (volume > 1.0
                              ? Icons.volume_up_rounded
                              : Icons.volume_down_rounded),
                  ),
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                  onPressed: onToggleMute,
                ),

              // Right Group: speed, audio, subtitles, sleep timer, aspect --
              // one button each, in that order. They used to be two buttons
              // (subtitles and a gear that held everything else), which made
              // the gear a menu of menus: three taps to reach a speed that
              // was one tap away on YouTube. Each of these is a set-once
              // choice a viewer makes mid-scene, so each gets its own button.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Playback Speed
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.speed_rounded),
                    tooltip: 'Playback speed',
                    showActiveBadge: playbackRate != 1.0,
                    onPressed: onOpenSpeedMenu,
                  ),

                  SizedBox(width: gap),

                  // Audio Track
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.audiotrack_rounded),
                    tooltip: 'Audio track',
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
                    tooltip: 'Subtitles',
                    showActiveBadge: isSubtitlesActive,
                    badgeColor: const Color(0xFF10B981), // Emerald
                    onPressed: onOpenSubtitleMenu,
                  ),

                  SizedBox(width: gap),

                  // Sleep Timer. A button rather than a menu row: it is one
                  // control, and a menu for one control is worse than a
                  // button for it. The badge counts down while it runs.
                  ValueListenableBuilder<int?>(
                    valueListenable: SleepTimerService.instance.minutesRemaining,
                    builder: (context, minutes, _) => PlayerIconButton(
                      size: btnSize,
                      iconSize: btnIconSize,
                      icon: const Icon(Icons.bedtime_rounded),
                      tooltip: minutes == null
                          ? 'Sleep timer'
                          : 'Sleep timer: $minutes min left',
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
                    tooltip: 'Aspect ratio',
                    onPressed: onOpenAspectMenu,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
