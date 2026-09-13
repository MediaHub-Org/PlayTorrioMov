import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Settings entry point -- one gear icon opens this instead of separate
/// playback-speed, aspect-ratio and audio-track buttons cluttering the
/// transport bar. Picking a row opens that row's own existing popover
/// (PlayerSpeedMenu / PlayerAspectMenu / PlayerAudioMenu); this widget only
/// lists them, YouTube-gear-menu style.
///
/// Rows run audio, subtitles, speed, aspect: the two that change what you
/// hear and read first, then the two that change how it plays.
class PlayerSettingsMenu extends StatelessWidget {
  final double currentRate;
  final String aspectLabel;

  /// The playing track's name, or null while the media has not reported
  /// its tracks yet.
  final String? audioLabel;

  /// Null hides the playback-speed row. Live TV passes null: a live feed
  /// plays at the rate it arrives, and a row that opens a picker with no
  /// effect is worse than no row.
  final VoidCallback? onTapSpeed;

  final VoidCallback onTapAspect;

  /// Null hides the audio row. Callers should normally supply it even for
  /// single-track media: the menu it opens also carries the Audio Sync
  /// Offset control, and this row is its only entry point.
  final VoidCallback? onTapAudio;

  /// Current subtitle state, e.g. a language name or "Off". Null hides the
  /// row (nothing to configure -- no subtitles available at all).
  final String? subtitleLabel;

  /// Opens subtitle track/style picking. The transport bar's own subtitle
  /// button stays a plain on/off toggle (YouTube's CC button); this row is
  /// where track and appearance selection actually lives, same split as
  /// YouTube's gear-menu "Subtitles/CC" entry.
  final VoidCallback? onTapSubtitles;

  const PlayerSettingsMenu({
    super.key,
    required this.currentRate,
    required this.aspectLabel,
    required this.onTapAspect,
    this.onTapSpeed,
    this.audioLabel,
    this.onTapAudio,
    this.subtitleLabel,
    this.onTapSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // No height cap and no scroll view of its own: PlayerMenuAnchor bounds
    // the popover to the space above the transport bar and scrolls it when
    // the rows do not fit. This used to carry its own `screenHeight - 120`
    // clamp, which each sibling menu either duplicated or -- in the speed
    // menu's case -- did not, and that inconsistency is what put the speed
    // card off the top of a landscape phone.
    return PlayerGlassCard(
      width: (260.0).clamp(220.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlayerMenuHeader(title: 'SETTINGS'),
          const SizedBox(height: 6),

          // Audio first. It is the choice a viewer makes before anything
          // else -- picking the dub you can follow comes before deciding
          // how fast to play it -- and on a dubbed title it is the only row
          // here that has to be found in a hurry.
          if (onTapAudio != null)
            _SettingsRow(
              icon: Icons.audiotrack_rounded,
              label: 'Audio track',
              value: audioLabel ?? 'Default',
              onTap: onTapAudio!,
            ),
          if (onTapSubtitles != null)
            _SettingsRow(
              icon: Icons.subtitles_rounded,
              label: 'Subtitles',
              value: subtitleLabel ?? 'Off',
              onTap: onTapSubtitles!,
            ),
          if (onTapSpeed != null)
            _SettingsRow(
              icon: Icons.speed_rounded,
              label: 'Playback speed',
              value: currentRate == 1.0
                  ? 'Normal'
                  : '${currentRate.toStringAsFixed(currentRate == currentRate.roundToDouble() ? 0 : 2)}×',
              onTap: onTapSpeed!,
            ),
          _SettingsRow(
            icon: Icons.aspect_ratio_rounded,
            label: 'Aspect ratio',
            value: aspectLabel,
            onTap: onTapAspect,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: PlayerTheme.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: PlayerTheme.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: PlayerTheme.inkSubtle,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: PlayerTheme.inkSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
