import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/player/skip_segment_model.dart';
import 'player_glass.dart';
import 'player_seek_bar.dart';
import 'player_volume_control.dart';

/// Bottom transport bar: timeline scrubber, volume, and the audio/subtitle/
/// settings menu triggers. Play/pause and the ±10s seek buttons live in the
/// centered overlay instead (see PlayerCenterControls) -- YouTube/Netflix
/// style, not duplicated here. Episode switching lives in PlayerTopBar's own
/// "Episodes" badge, not duplicated here either.
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
  final VoidCallback onToggleSubtitleMenu;
  final VoidCallback onToggleSettingsMenu;
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
    required this.onToggleSubtitleMenu,
    required this.onToggleSettingsMenu,
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

          // Bottom Controls Row
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
                        : (volume > 1.0 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                  ),
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                  onPressed: onToggleMute,
                ),

              // Right Group: Subtitles, Settings (speed, aspect, audio track).
              // Audio moved behind the gear -- picking a dub is a set-once
              // choice, unlike subtitles, which get toggled mid-scene.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtitles Menu Trigger
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.subtitles_rounded),
                    tooltip: 'Subtitles',
                    showActiveBadge: isSubtitlesActive,
                    badgeColor: const Color(0xFF10B981), // Emerald
                    onPressed: onToggleSubtitleMenu,
                  ),

                  SizedBox(width: gap),

                  // Settings Menu Trigger (playback speed + aspect ratio)
                  PlayerIconButton(
                    size: btnSize,
                    iconSize: btnIconSize,
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Settings',
                    showActiveBadge: playbackRate != 1.0,
                    onPressed: onToggleSettingsMenu,
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
