import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Settings entry point -- one gear icon opens this instead of separate
/// playback-speed, aspect-ratio and audio-track buttons cluttering the
/// transport bar. Picking a row opens that row's own existing popover
/// (PlayerSpeedMenu / PlayerAspectMenu / PlayerAudioMenu); this widget only
/// lists them, YouTube-gear-menu style.
class PlayerSettingsMenu extends StatelessWidget {
  final double currentRate;
  final String aspectLabel;

  /// The playing track's name, or null while the media has not reported
  /// its tracks yet.
  final String? audioLabel;

  final VoidCallback onTapSpeed;
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

  final VoidCallback onClose;

  const PlayerSettingsMenu({
    super.key,
    required this.currentRate,
    required this.aspectLabel,
    required this.onTapSpeed,
    required this.onTapAspect,
    required this.onClose,
    this.audioLabel,
    this.onTapAudio,
    this.subtitleLabel,
    this.onTapSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    // A short landscape phone screen can't fit five rows (header + up to
    // four settings) without this: the popover is bottom-anchored with no
    // top bound (see player_screen.dart's Positioned), so an unconstrained
    // height just pushes it above the visible viewport instead of
    // clipping -- capped and scrollable instead, same safeguard
    // PlayerSubtitleMenu already has for its own, usually-longer lists.
    final maxHeight = (screenSize.height - 120).clamp(160.0, double.infinity);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: PlayerGlassCard(
        width: (260.0).clamp(220.0, screenSize.width - 32),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: PlayerTheme.inkSubtle,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  PlayerIconButton(
                    size: 28,
                    iconSize: 14,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (onTapSubtitles != null)
                _SettingsRow(
                  icon: Icons.subtitles_rounded,
                  label: 'Subtitles',
                  value: subtitleLabel ?? 'Off',
                  onTap: onTapSubtitles!,
                ),
              _SettingsRow(
                icon: Icons.speed_rounded,
                label: 'Playback speed',
                value: currentRate == 1.0
                    ? 'Normal'
                    : '${currentRate.toStringAsFixed(currentRate == currentRate.roundToDouble() ? 0 : 2)}×',
                onTap: onTapSpeed,
              ),
              _SettingsRow(
                icon: Icons.aspect_ratio_rounded,
                label: 'Aspect ratio',
                value: aspectLabel,
                onTap: onTapAspect,
              ),
              if (onTapAudio != null)
                _SettingsRow(
                  icon: Icons.audiotrack_rounded,
                  label: 'Audio track',
                  value: audioLabel ?? 'Default',
                  onTap: onTapAudio!,
                ),
            ],
          ),
        ),
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
