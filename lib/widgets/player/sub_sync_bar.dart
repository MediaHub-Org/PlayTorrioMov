import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../common/hover_button.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// Floating glass toolbar for quick live subtitle delay adjustment.
class SubSyncBar extends StatefulWidget {
  final double delaySec;
  final ValueChanged<double> onDelayChanged;
  final VoidCallback? onEnterTextSync;
  final bool isTextSyncAvailable;
  final VoidCallback onClose;
  final VoidCallback? onSave;

  const SubSyncBar({
    super.key,
    required this.delaySec,
    required this.onDelayChanged,
    this.onEnterTextSync,
    this.isTextSyncAvailable = true,
    required this.onClose,
    this.onSave,
  });

  @override
  State<SubSyncBar> createState() => _SubSyncBarState();
}

class _SubSyncBarState extends State<SubSyncBar> {
  late double _localDelay;
  late double _initialDelay;

  @override
  void initState() {
    super.initState();
    _localDelay = widget.delaySec;
    _initialDelay = widget.delaySec;
  }

  @override
  void didUpdateWidget(covariant SubSyncBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delaySec != widget.delaySec) {
      _localDelay = widget.delaySec;
    }
  }

  void _applyDelay(double value) {
    final rounded = (value * 100).round() / 100.0;
    setState(() => _localDelay = rounded);
    widget.onDelayChanged(rounded);
  }

  void _handleDiscard() {
    _applyDelay(_initialDelay);
    widget.onClose();
  }

  void _handleSave() {
    _initialDelay = _localDelay;
    widget.onSave?.call();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = ((_localDelay - _initialDelay).abs() > 0.01);
    final isNonZero = _localDelay.abs() > 0.01;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms)),
        child: PlayerGlassCard(
          borderRadius: context.rem(AppRem.radiusLg),
          padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(AppRem.sm)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Center: Stepper Buttons & Display Pill
            Container(
              padding: EdgeInsets.all(context.rem(0.1875)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                border: Border.all(color: PlayerTheme.edgeSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepButton(
                    label: '−0.5s',
                    onTap: () => _applyDelay(_localDelay - 0.5),
                    isWide: true,
                  ),
                  _StepButton(
                    label: '−0.1s',
                    onTap: () => _applyDelay(_localDelay - 0.1),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: context.rem(AppRem.xs)),
                    padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(0.3125)),
                    decoration: BoxDecoration(
                      color: PlayerTheme.raised,
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                      border: Border.all(
                        color: isNonZero ? PlayerTheme.edge : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_localDelay >= 0 ? '+' : ''}${_localDelay.toStringAsFixed(2)}s',
                          style: TextStyle(
                            color: isNonZero ? PlayerTheme.accent : PlayerTheme.inkMuted,
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isNonZero) ...[
                          SizedBox(width: context.rem(AppRem.snug)),
                          Tooltip(
                            message: context.l10n.syncResetTiming,
                            child: HoverButton(
                              scaleAmount: 1.1,
                              showFocusRing: true,
                              onTap: () => _applyDelay(0.0),
                              child: Container(
                                padding: EdgeInsets.all(context.rem(AppRem.xxs)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.replay_rounded,
                                  color: Colors.white,
                                  size: context.rem(0.6875),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StepButton(
                    label: '+0.1s',
                    onTap: () => _applyDelay(_localDelay + 0.1),
                  ),
                  _StepButton(
                    label: '+0.5s',
                    onTap: () => _applyDelay(_localDelay + 0.5),
                    isWide: true,
                  ),
                ],
              ),
            ),

            SizedBox(width: context.rem(AppRem.sm)),

            // Right: Discard & Save Done & Close
            if (isDirty) ...[
              PlayerIconButton(
                size: context.rem(AppRem.xl),
                iconSize: context.rem(0.9375),
                icon: const Icon(Icons.undo_rounded),
                tooltip: context.l10n.playerDiscardChanges,
                onPressed: _handleDiscard,
              ),
              SizedBox(width: context.rem(AppRem.xs)),
            ],

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: PlayerTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(0.4375)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                minimumSize: Size(0, context.rem(AppRem.xl)),
              ),
              icon: Icon(Icons.check_rounded, size: context.rem(0.9375)),
              label: Text(
                context.l10n.playerDone,
                style: const TextStyle(fontSize: AppType.captionPlus, fontWeight: FontWeight.w600),
              ),
              onPressed: _handleSave,
            ),
            SizedBox(width: context.rem(AppRem.xs)),

            PlayerIconButton(
              size: context.rem(AppRem.xl),
              iconSize: context.rem(0.9375),
              icon: const Icon(Icons.close_rounded),
              tooltip: context.l10n.playerClose,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isWide;

  const _StepButton({
    required this.label,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
        onTap: onTap,
        child: Container(
          width: context.rem(isWide ? 2.75 : 2.375),
          constraints: BoxConstraints(minHeight: context.rem(1.75)),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: PlayerTheme.inkMuted,
              fontSize: AppType.tinyPlus,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
