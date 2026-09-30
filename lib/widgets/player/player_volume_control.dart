import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// Interactive volume slider with high-gain boost support (up to 250%).
class PlayerVolumeControl extends StatefulWidget {
  final double volume; // 0.0 to 2.50 (250%)
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;

  static const double maxVolume = 2.50;

  const PlayerVolumeControl({
    super.key,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onToggleMute,
  });

  @override
  State<PlayerVolumeControl> createState() => _PlayerVolumeControlState();
}

class _PlayerVolumeControlState extends State<PlayerVolumeControl> {
  bool _isHovered = false;
  bool _isFocused = false;
  double get _trackWidth => context.rem(6);

  /// Same step the scroll wheel uses, so left/right and the wheel move the
  /// level by the same amount either way.
  static const double _keyboardVolumeStep = 0.05;

  void _nudgeVolume(double direction) {
    final next = (widget.volume + _keyboardVolumeStep * direction)
        .clamp(0.0, PlayerVolumeControl.maxVolume);
    widget.onVolumeChanged((next * 100).round() / 100.0);
  }

  IconData _getVolumeIcon() {
    if (widget.isMuted || widget.volume == 0) {
      return Icons.volume_off_rounded;
    }
    if (widget.volume > 1.0) {
      return Icons.volume_up_rounded;
    }
    if (widget.volume < 0.5) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  Color _getBoostColor() {
    if (widget.volume <= 1.0) return Colors.white;
    if (widget.volume > 1.75) return const Color(0xFFFF3D00); // Deep Flame Orange/Red
    return const Color(0xFFFF8A00); // Amber/Orange
  }

  void _updateFromPosition(double localX) {
    final fraction = (localX / _trackWidth).clamp(0.0, 1.0);
    double newVol;
    if (fraction <= 0.55) {
      newVol = (fraction / 0.55) * 1.0;
    } else {
      newVol = 1.0 + ((fraction - 0.55) / 0.45) * 1.50;
    }
    widget.onVolumeChanged((newVol * 100).round() / 100.0);
  }

  double _getFractionFromVolume(double v) {
    if (widget.isMuted) return 0.0;
    if (v <= 1.0) {
      return (v * 0.55).clamp(0.0, 0.55);
    }
    return (0.55 + ((v - 1.0) / 1.50) * 0.45).clamp(0.55, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVol = widget.isMuted ? 0.0 : widget.volume;
    final fillFraction = _getFractionFromVolume(effectiveVol);
    final isBoosting = !widget.isMuted && widget.volume > 1.001;
    final boostColor = _getBoostColor();
    final pct = (effectiveVol * 100).round();

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
          final next = (widget.volume + delta).clamp(0.0, PlayerVolumeControl.maxVolume);
          widget.onVolumeChanged((next * 100).round() / 100.0);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mute / Unmute Button
            PlayerIconButton(
              size: context.rem(2.5),
              iconSize: context.rem(1.375),
              icon: Icon(
                _getVolumeIcon(),
                color: isBoosting ? boostColor : (widget.isMuted ? PlayerTheme.inkSubtle : Colors.white),
              ),
              tooltip: widget.isMuted ? context.l10n.playerUnmute : context.l10n.playerMute,
              onPressed: widget.onToggleMute,
            ),

            SizedBox(width: context.rem(AppRem.xs)),

            // Volume Slider Track
            Focus(
              onFocusChange: (focused) =>
                  setState(() => _isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _nudgeVolume(-1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _nudgeVolume(1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusRing(
                visible: _isFocused,
                borderRadius: context.rem(AppRem.radiusSm),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (e) =>
                      _updateFromPosition(e.localPosition.dx),
                  onTapDown: (e) => _updateFromPosition(e.localPosition.dx),
                  child: Container(
                    width: _trackWidth,
                    height: context.rem(AppRem.xl),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background track
                        Container(
                          height: context.rem(AppRem.snug),
                          width: _trackWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999), // px: a hairline, not a layout size
                          ),
                        ),

                        // 100% Threshold Notch Line
                        Positioned(
                          left: _trackWidth * 0.55 - 0.75,
                          child: Container(
                            width: 1.5, // px: a hairline, not a layout size
                            height: context.rem(0.5625),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.40),
                              borderRadius: BorderRadius.circular(context.rem(0.0625)),
                            ),
                          ),
                        ),

                        // Filled track
                        Container(
                          height: context.rem(AppRem.snug),
                          width: _trackWidth * fillFraction,
                          decoration: BoxDecoration(
                            gradient: isBoosting
                                ? LinearGradient(
                                    colors: [
                                      Colors.white,
                                      const Color(0xFFFF8A00),
                                      if (widget.volume > 1.75)
                                        const Color(0xFFFF3D00),
                                    ],
                                  )
                                : null,
                            color: isBoosting
                                ? null
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999), // px: a hairline, not a layout size
                          ),
                        ),

                        // Thumb dot
                        Positioned(
                          left: (_trackWidth * fillFraction - context.rem(AppRem.snug))
                              .clamp(0.0, _trackWidth - context.rem(AppRem.ms)),
                          child: Container(
                            width: context.rem(AppRem.ms),
                            height: context.rem(AppRem.ms),
                            decoration: BoxDecoration(
                              color: isBoosting ? boostColor : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isBoosting
                                      ? boostColor.withValues(alpha: 0.6)
                                      : Colors.black54,
                                  blurRadius: context.rem(isBoosting ? AppRem.snug : AppRem.xs),
                                  spreadRadius: context.rem(isBoosting ? 0.0625 : 0),
                                  offset: Offset(0, context.rem(0.0625)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Percentage Readout
            if (isBoosting || _isHovered || _isFocused) ...[
              SizedBox(width: context.rem(AppRem.snug)),
              Container(
                constraints: BoxConstraints(minWidth: context.rem(2.375)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBoosting)
                      Padding(
                        padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.xxs)),
                        child: Icon(
                          Icons.bolt_rounded,
                          size: context.rem(0.8125),
                          color: boostColor,
                        ),
                      ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: isBoosting ? boostColor : PlayerTheme.inkMuted,
                        fontSize: AppType.tinyPlus,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
