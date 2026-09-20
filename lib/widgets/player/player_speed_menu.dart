import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Playback speed floating popover menu: a readout, a slider with -/+ buttons
/// on either side of it, and a row of one-tap presets underneath.
///
/// The slider used to stand alone with a row of numbers under it that was
/// only *roughly* under its ticks (a `spaceBetween` row does not know where
/// the slider's track starts), and nudging by a single step meant hitting a
/// 4px-wide tick with a thumb. The -/+ buttons take one step each, and the
/// preset chips *are* the numbers, so what is labeled is what is tappable.
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
  /// Every speed the slider and the -/+ buttons step through.
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

  /// The ones worth a chip: what people actually pick. 0.25x and 1.75x stay
  /// reachable from the slider and the buttons, and would only make the chip
  /// row wrap on a phone.
  static const List<double> _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static String _format(double rate) => rate
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  /// The index of the step nearest [rate], so a rate that is not on the grid
  /// (one restored from an older setting) still has a sensible neighbor.
  int get _index {
    var best = 0;
    for (var i = 1; i < _points.length; i++) {
      if ((_points[i] - widget.currentRate).abs() <
          (_points[best] - widget.currentRate).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// One step down or up. The menu stays open: the readout shows the result,
  /// and a viewer nudging from 1x to 1.5x wants three presses, not three
  /// reopenings.
  void _step(int direction) {
    final next = (_index + direction).clamp(0, _points.length - 1);
    widget.onRateSelected(_points[next]);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final index = _index;

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
          Center(
            child: Text(
              '${widget.currentRate.toStringAsFixed(2)}×',
              style: const TextStyle(
                color: PlayerTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              PlayerIconButton(
                size: 32,
                iconSize: 18,
                icon: const Icon(Icons.remove_rounded),
                tooltip: 'Slower',
                onPressed: index > 0 ? () => _step(-1) : null,
              ),
              Expanded(
                child: PlayerStepSlider(
                  value: widget.currentRate,
                  min: _points.first,
                  max: _points.last,
                  divisions: _points.length - 1,
                  label: '${widget.currentRate.toStringAsFixed(2)}×',
                  onChanged: widget.onRateSelected,
                  onChangeEnd: (_) => widget.onClose(),
                ),
              ),
              PlayerIconButton(
                size: 32,
                iconSize: 18,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Faster',
                onPressed: index < _points.length - 1 ? () => _step(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrap, not a Row: each chip is small and can honestly sit on a
          // second line at a large text scale.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final rate in _presets)
                _SpeedChip(
                  label: _format(rate),
                  caption: rate == 1.0 ? 'Normal' : null,
                  isSelected: (widget.currentRate - rate).abs() < 0.001,
                  onTap: () => widget.onRateSelected(rate),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One preset: a pill with the speed on it and, for the normal speed only, a
/// caption underneath saying so.
class _SpeedChip extends StatelessWidget {
  final String label;
  final String? caption;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    this.caption,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? PlayerTheme.accent.withValues(alpha: 0.35)
                    : PlayerTheme.raised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 10),
          ),
        ],
      ],
    );
  }
}
