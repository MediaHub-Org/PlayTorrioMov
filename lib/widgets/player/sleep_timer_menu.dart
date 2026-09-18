import 'package:flutter/material.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';

/// The sleep timer's own popover, opened from the moon button in the
/// transport bar.
///
/// One row per duration, rather than chips: a row carries the consequence of
/// the choice ("pauses at 02:14") where a chip carried only the choice, and
/// rows scan vertically the way every other player menu does. A custom
/// value sits at the bottom with its own -/+ steppers, for durations the
/// presets do not cover.
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
          const PlayerMenuHeader(title: 'SLEEP TIMER'),
          const SizedBox(height: 6),
          ValueListenableBuilder<int?>(
            valueListenable: SleepTimerService.instance.minutesRemaining,
            builder: (context, remaining, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final min in const [15, 30, 45, 60, 90])
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
                    labelOverride: 'Off (cancel -- $remaining min left)',
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
    final value = _customMinutes ?? 20;
    final isCustomActive =
        remaining != null && _customMinutes != null && remaining <= value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Flexible(
            child: Text(
              'Custom',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: PlayerTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            tooltip: 'Fewer minutes',
            onPressed: () => setState(() {
              _customMinutes = (value - 5).clamp(5, 240);
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
            tooltip: 'More minutes',
            onPressed: () => setState(() {
              _customMinutes = (value + 5).clamp(5, 240);
            }),
          ),
          const SizedBox(width: 8),
          PlayerIconButton(
            size: 30,
            iconSize: 16,
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Set custom timer',
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
    final label = labelOverride ?? '$minutes min -- pauses at $hh:$mm';

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
