import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/tv_mode_service.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// Playback speed floating popover menu: a readout and a slider.
///
/// The slider is laid out by *step*, not by value, so normal speed sits in the
/// middle of the track: three steps slower, three faster. By value the track
/// ran 0.25x to 2x and 1x landed left of center, which made "back to normal"
/// a target to aim at rather than the place the thumb naturally rests.
///
/// Preset chips sat under it for one release. They repeated what the slider
/// already offered, and at a phone's width they stacked into a column of
/// full-width bars, so the menu got taller to say the same thing twice. The
/// -/+ buttons that followed them went the same way: Left/Right on a remote
/// and a drag on a screen already step the slider, so the buttons were a
/// third way to do it and a second thing to focus.
///
/// On a TV the menu stays open while Left/Right step the speed, and closes on
/// OK or Back. It used to close after the first press, because the slider
/// reported every arrow as a finished drag.
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
  /// Every speed the slider steps through, with 1x in the middle. The steps
  /// are not evenly spaced (0.25 up to 1.5, then 2), which is fine: the
  /// slider works in indices, and 2x is worth more than 1.75x.
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

  @override
  Widget build(BuildContext context) {
    final index = _index;

    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      padding: EdgeInsets.all(context.rem(AppRem.ms)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayerMenuHeader(
            title: context.l10n.detailsPlaybackSpeed.toUpperCase(),
            onBack: widget.onBack,
          ),

          SizedBox(height: context.rem(AppRem.snug)),
          Center(
            child: Text(
              '${widget.currentRate.toStringAsFixed(2)}×',
              style: const TextStyle(
                color: PlayerTheme.ink,
                fontSize: AppType.titleSm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: context.rem(AppRem.xs)),
          PlayerStepSlider(
            value: index.toDouble(),
            min: 0,
            max: (_points.length - 1).toDouble(),
            divisions: _points.length - 1,
            label: '${_points[index].toStringAsFixed(2)}×',
            onChanged: (value) => widget.onRateSelected(_points[value.round()]),
            onChangeEnd: (_) => widget.onClose(),
          ),
          // Only where there is a remote to be told: a pointer sees the
          // slider and needs no sentence.
          if (TvModeService.isTv.value) ...[
            SizedBox(height: context.rem(AppRem.xs)),
            Center(
              child: Text(
                context.l10n.playerSpeedHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PlayerTheme.inkSubtle,
                  fontSize: AppType.caption,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
