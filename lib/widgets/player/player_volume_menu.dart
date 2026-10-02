import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/tv_mode_service.dart';
import 'player_glass.dart';
import 'player_volume_control.dart';

/// The volume as a floating popover, like speed: a readout, a mute button and
/// a slider through the whole range, boost included (up to 250%).
///
/// It exists for the TV. The slider in the transport bar claims the arrows it
/// adjusts with, which on a remote left it either a dead end (Left/Right) or
/// something that took Up/Down away from every other control; neither reads
/// as a volume. A menu has the same shape as audio, speed and the sleep
/// timer -- open it with OK, adjust inside it, Back to close -- and its
/// arrows are its own while it is open (#80). The panel stays open while the
/// level changes, unlike speed, so a viewer can keep adjusting.
///
/// The slider is where focus lands, so Left/Right work at once; OK, which the
/// slider does not use, mutes and unmutes from anywhere in the panel.
class PlayerVolumeMenu extends StatelessWidget {
  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  /// Back to the settings root, when this menu was stepped into from there
  /// rather than opened directly.
  final VoidCallback? onBack;

  const PlayerVolumeMenu({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onToggleMute,
    this.onBack,
  });

  /// One step on the slider: the same five percent the keys and the wheel
  /// move the level by everywhere else.
  static const int _divisions = 50;

  @override
  Widget build(BuildContext context) {
    final effective = isMuted ? 0.0 : volume;
    final pct = (effective * 100).round();
    final isBoosting = !isMuted && volume > 1.001;
    final boost = volume > 1.75
        ? const Color(0xFFFF3D00)
        : const Color(0xFFFF8A00);
    final readoutColor = isMuted
        ? PlayerTheme.inkSubtle
        : (isBoosting ? boost : PlayerTheme.ink);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA) {
          onToggleMute();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PlayerGlassCard(
        width: PlayerTheme.menuWidthFor(context),
        padding: EdgeInsets.all(context.rem(AppRem.ms)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerMenuHeader(
              title: context.l10n.playerVolume.toUpperCase(),
              onBack: onBack,
            ),
            SizedBox(height: context.rem(AppRem.snug)),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBoosting)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: context.rem(AppRem.xs),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        size: context.rem(AppRem.icon),
                        color: boost,
                      ),
                    ),
                  Text(
                    isMuted ? context.l10n.playerMute : '$pct%',
                    style: TextStyle(
                      color: readoutColor,
                      fontSize: AppType.titleSm,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rem(AppRem.xs)),
            Row(
              children: [
                PlayerIconButton(
                  size: context.rem(AppRem.xl),
                  iconSize: context.rem(1.125),
                  icon: Icon(
                    isMuted || volume == 0
                        ? Icons.volume_off_rounded
                        : (volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                    color: isBoosting ? boost : null,
                  ),
                  tooltip: isMuted
                      ? context.l10n.playerUnmute
                      : context.l10n.playerMute,
                  onPressed: onToggleMute,
                ),
                Expanded(
                  child: PlayerStepSlider(
                    value: effective,
                    min: 0,
                    max: PlayerVolumeControl.maxVolume,
                    divisions: _divisions,
                    label: '$pct%',
                    onChanged: onVolumeChanged,
                  ),
                ),
              ],
            ),
            // Only where there is a remote to be told: a pointer sees the
            // button and the slider and needs no sentence.
            if (TvModeService.isTv.value) ...[
              SizedBox(height: context.rem(AppRem.xs)),
              Center(
                child: Text(
                  context.l10n.playerVolumeHint,
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
      ),
    );
  }
}
