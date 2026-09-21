import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';

/// The sleep timer's own popover, opened from the moon button in the
/// transport bar.
///
/// One row per duration, rather than chips: a row carries the consequence of
/// the choice ("pauses at 02:14") where a chip carried only the choice, and
/// rows scan vertically the way every other player menu does. The presets stop
/// at an hour; a custom value at the bottom, opening on 90 minutes, has its
/// own -/+ steppers for the longer sleeps the presets do not cover.
///
/// A slider over the presets sat above the rows for a while. It offered the
/// same choices a second way, in a control too small to read its own
/// numbers, so it went -- one way to pick a preset, not two.
///
/// The chips this replaced existed for several releases before anything was
/// wired behind them: choosing "30 min" changed a highlight and nothing
/// else. They drive [SleepTimerService] now, which actually pauses playback.
class SleepTimerMenu extends StatefulWidget {
  const SleepTimerMenu({super.key});

  @override
  State<SleepTimerMenu> createState() => _SleepTimerMenuState();
}

class _SleepTimerMenuState extends State<SleepTimerMenu> {
  static const _presetMinutes = [15, 30, 45, 60];

  /// Where the custom stepper opens, and how far each press moves it. The
  /// presets end at an hour, so custom starts beyond it.
  static const _customStart = 90;
  static const _customStep = 15;
  static const _customMin = 15;
  static const _customMax = 480;

  /// The custom duration the -/+ steppers are editing, in minutes. Null
  /// until the user touches a stepper -- the presets are one tap, and the
  /// steppers should not imply a selection nobody made.
  int? _customMinutes;

  void _start(int minutes) => SleepTimerService.instance.start(minutes);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (300.0).clamp(260.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayerMenuHeader(title: context.l10n.playerSleepTimer.toUpperCase()),
          const SizedBox(height: 6),
          ValueListenableBuilder<int?>(
            valueListenable: SleepTimerService.instance.minutesRemaining,
            builder: (context, remaining, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final min in _presetMinutes)
                  _DurationRow(
                    minutes: min,
                    isSelected: remaining == min,
                    onTap: () {
                      setState(() => _customMinutes = null);
                      _start(min);
                    },
                  ),
                if (remaining != null) ...[
                  const SizedBox(height: 4),
                  _DurationRow(
                    minutes: remaining,
                    labelOverride: context.l10n.playerSleepOff(remaining),
                    isSelected: false,
                    icon: Icons.timer_off_outlined,
                    onTap: () {
                      setState(() => _customMinutes = null);
                      SleepTimerService.instance.cancel();
                    },
                  ),
                ],
                const SizedBox(height: 6),
                const Divider(color: PlayerTheme.edgeSoft, height: 1),
                const SizedBox(height: 6),
                _buildCustomRow(remaining),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The custom duration steppers. Editing alone does not start the timer --
  /// the row says "Set", and starting it is its own tap, so nudging past a
  /// value by accident does not silently arm a two-hour timer.
  Widget _buildCustomRow(int? remaining) {
    final value = _customMinutes ?? _customStart;
    final isCustomActive =
        remaining != null && _customMinutes != null && remaining <= value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.playerSleepCustom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PlayerTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            tooltip: context.l10n.playerFewerMinutes,
            onPressed: () => setState(() {
              _customMinutes = (value - _customStep).clamp(_customMin, _customMax);
            }),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value min',
                  style: TextStyle(
                    color:
                        isCustomActive ? PlayerTheme.accent : PlayerTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            tooltip: context.l10n.playerMoreMinutes,
            onPressed: () => setState(() {
              _customMinutes = (value + _customStep).clamp(_customMin, _customMax);
            }),
          ),
          const SizedBox(width: 8),
          PlayerIconButton(
            size: 30,
            iconSize: 16,
            icon: const Icon(Icons.check_rounded),
            tooltip: context.l10n.playerSetCustomTimer,
            active: isCustomActive,
            onPressed: () {
              setState(() => _customMinutes = value);
              _start(value);
            },
          ),
        ],
      ),
    );
  }
}

/// One duration choice, as a full-width row. Rows rather than chips: a chip
/// carried only the number, a row carries what choosing it does, and rows
/// scan vertically the way every other player menu does.
class _DurationRow extends StatelessWidget {
  final int minutes;
  final String? labelOverride;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback onTap;

  const _DurationRow({
    required this.minutes,
    this.labelOverride,
    required this.isSelected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final endsAt = DateTime.now().add(Duration(minutes: minutes));
    final hh = endsAt.hour.toString().padLeft(2, '0');
    final mm = endsAt.minute.toString().padLeft(2, '0');
    final label = labelOverride ??
        context.l10n.playerSleepPausesAt(minutes, '$hh:$mm');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? PlayerTheme.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? PlayerTheme.edge : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: PlayerTheme.inkSubtle),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded,
                    size: 16, color: PlayerTheme.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerIconButton(
      size: 28,
      iconSize: 16,
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
