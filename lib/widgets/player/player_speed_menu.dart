import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'player_glass.dart';

/// Playback speed floating popover menu: a readout, and a slider with a -/+
/// button on either side of it.
///
/// The slider is laid out by *step*, not by value, so normal speed sits in the
/// middle of the track: three steps slower, three faster. By value the track
/// ran 0.25x to 2x and 1x landed left of center, which made "back to normal"
/// a target to aim at rather than the place the thumb naturally rests.
///
/// Preset chips sat under it for one release. They repeated what the slider
/// already offered, and at a phone's width they stacked into a column of
/// full-width bars, so the menu got taller to say the same thing twice.
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
  /// Every speed the slider and the -/+ buttons step through, with 1x in the
  /// middle. The steps are not evenly spaced (0.25 up to 1.5, then 2), which
  /// is fine: the slider works in indices, and 2x is worth more than 1.75x.
  static const List<double> _points = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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
  /// and a viewer nudging from 1x to 1.5x wants two presses, not two
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
            title: context.l10n.detailsPlaybackSpeed.toUpperCase(),
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
                tooltip: context.l10n.playerSlower,
                onPressed: index > 0 ? () => _step(-1) : null,
              ),
              Expanded(
                child: PlayerStepSlider(
                  value: index.toDouble(),
                  min: 0,
                  max: (_points.length - 1).toDouble(),
                  divisions: _points.length - 1,
                  label: '${_points[index].toStringAsFixed(2)}×',
                  onChanged: (value) =>
                      widget.onRateSelected(_points[value.round()]),
                  onChangeEnd: (_) => widget.onClose(),
                ),
              ),
              PlayerIconButton(
                size: 32,
                iconSize: 18,
                icon: const Icon(Icons.add_rounded),
                tooltip: context.l10n.playerFaster,
                onPressed: index < _points.length - 1 ? () => _step(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
