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
  /// its tracks yet (or has only one, where there is nothing to choose).
  final String? audioLabel;

  final VoidCallback onTapSpeed;
  final VoidCallback onTapAspect;

  /// Null hides the audio row entirely -- a single-track file has no
  /// choice to offer, and a row that opens an empty menu is worse than
  /// no row.
  final VoidCallback? onTapAudio;

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
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (260.0).clamp(220.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
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
