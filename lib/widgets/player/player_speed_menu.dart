import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Playback speed and sleep timer floating popover menu.
class PlayerSpeedMenu extends StatefulWidget {
  final double currentRate;
  final ValueChanged<double> onRateSelected;
  final VoidCallback onClose;

  /// Back to the settings root, when this menu was stepped into from
  /// there rather than opened directly.
  final VoidCallback? onBack;

  const PlayerSpeedMenu({
    super.key,
    required this.currentRate,
    required this.onRateSelected,
    required this.onClose,
    this.onBack,
  });

  @override
  State<PlayerSpeedMenu> createState() => _PlayerSpeedMenuState();
}

class _PlayerSpeedMenuState extends State<PlayerSpeedMenu> {
  static const List<double> _points = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

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
            title: 'PLAYBACK SPEED',
            onBack: widget.onBack,
          ),

          const SizedBox(height: 6),
          Text(
            '${widget.currentRate.toStringAsFixed(2)}×',
            style: const TextStyle(
              color: PlayerTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          PlayerStepSlider(
            value: widget.currentRate,
            min: 0.25,
            max: 2.0,
            divisions: _points.length - 1,
            label: '${widget.currentRate.toStringAsFixed(2)}×',
            onChanged: widget.onRateSelected,
            onChangeEnd: (_) => widget.onClose(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final point in _points)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        point
                            .toStringAsFixed(2)
                            .replaceFirst(RegExp(r'0+$'), '')
                            .replaceFirst(RegExp(r'\.$'), ''),
                        style: const TextStyle(
                          color: PlayerTheme.inkSubtle,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
