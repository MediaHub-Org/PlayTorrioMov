import 'package:flutter/material.dart';
import 'player_glass.dart';

class AspectOption {
  final String id;
  final String label;
  final BoxFit fit;

  const AspectOption({required this.id, required this.label, required this.fit});
}

const List<AspectOption> aspectOptions = [
  AspectOption(id: 'fit', label: 'Fit to screen (Contain)', fit: BoxFit.contain),
  AspectOption(id: 'cover', label: 'Fill screen (Crop/Zoom)', fit: BoxFit.cover),
  AspectOption(id: 'fill', label: 'Stretch to fill', fit: BoxFit.fill),
];

/// Aspect ratio and picture popover menu.
class PlayerAspectMenu extends StatelessWidget {
  final BoxFit currentFit;
  final double subtitleScale;
  final ValueChanged<BoxFit> onFitSelected;
  final ValueChanged<double> onSubtitleScaleChanged;
  final VoidCallback onClose;

  /// Back to the settings root, when this menu was stepped into from
  /// there rather than opened directly.
  final VoidCallback? onBack;

  const PlayerAspectMenu({
    super.key,
    required this.currentFit,
    required this.subtitleScale,
    required this.onFitSelected,
    required this.onSubtitleScaleChanged,
    required this.onClose,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (320.0).clamp(240.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayerMenuHeader(
            title: 'ASPECT RATIO',
            onBack: onBack,
            onClose: onClose,
          ),

          const SizedBox(height: 6),

          // Aspect Options List
          Column(
            children: aspectOptions.map((opt) {
              final isSelected = currentFit == opt.fit;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    onFitSelected(opt.fit);
                    onClose();
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? PlayerTheme.raised : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? PlayerTheme.edge : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt.label,
                          style: TextStyle(
                            color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: PlayerTheme.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          const Divider(color: PlayerTheme.edgeSoft, height: 1),
          const SizedBox(height: 12),

          // Subtitle Size Scaling Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtitle Size Scale',
                  style: TextStyle(
                    color: PlayerTheme.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${subtitleScale.toStringAsFixed(1)}×',
                  style: const TextStyle(
                    color: PlayerTheme.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: PlayerTheme.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: PlayerTheme.accent.withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: subtitleScale,
              min: 0.5,
              max: 2.5,
              divisions: 20,
              onChanged: onSubtitleScaleChanged,
            ),
          ),
        ],
      ),
    );
  }
}
