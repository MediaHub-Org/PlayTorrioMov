import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/player/skip_segment_model.dart';
import 'player_glass.dart';
import 'player_seek_bar.dart';
import 'player_volume_control.dart';

/// Bottom transport bar: timeline scrubber, volume, and the audio/subtitle/
/// settings menu triggers. Play/pause and seek live in the centered overlay
/// instead (see PlayerCenterControls), and episode switching lives in
/// PlayerTopBar's own "Episodes" badge -- neither is duplicated here.
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

  /// Plain on/off, YouTube's CC-button style -- track and style selection
  /// live in the settings menu instead (see PlayerSettingsMenu).
  final VoidCallback onToggleSubtitles;
  final VoidCallback onToggleSettingsMenu;
  final VoidCallback onOpenSpeedMenu;
  final VoidCallback onOpenAudioMenu;
  final VoidCallback onOpenAspectMenu;
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
    required this.onToggleSubtitles,
    required this.onToggleSettingsMenu,
    required this.onOpenSpeedMenu,
    required this.onOpenAudioMenu,
    required this.onOpenAspectMenu,
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

          SizedBox(height: isCompact ? 8 : 14),

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

              // Right Group: speed, audio, subtitles, settings, aspect --
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

                  // Subtitles On/Off Toggle
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.subtitles_rounded),
                    tooltip: isSubtitlesActive
                        ? 'Subtitles off'
                        : 'Subtitles on',
                    showActiveBadge: isSubtitlesActive,
                    badgeColor: const Color(0xFF10B981), // Emerald
                    onPressed: onToggleSubtitles,
                  ),

                  SizedBox(width: gap),

                  // Settings Menu Trigger (subtitle appearance + sleep timer)
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Settings',
                    onPressed: onToggleSettingsMenu,
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
