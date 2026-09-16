import 'package:flutter/material.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';

/// The sleep timer's own popover, opened from the moon button in the
/// transport bar.
///
/// This was the settings menu until the controls it indexed grew buttons of
/// their own; what remained was the sleep timer, and a menu for one control
/// is worse than a button for it -- so the menu became this, and the gear
/// went away.
///
/// The chips existed for several releases before anything was wired behind
/// them: choosing "30 min" changed a highlight and nothing else. They drive
/// [SleepTimerService] now, which actually pauses playback.
class SleepTimerMenu extends StatelessWidget {
  const SleepTimerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (260.0).clamp(220.0, screenWidth - 32),
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
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$remaining min remaining -- playback pauses at 0',
                      style: const TextStyle(
                        color: PlayerTheme.inkSubtle,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                if (remaining != null) const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final min in const [15, 30, 45, 60])
                        PlayerToggleChip(
                          active: remaining == min,
                          label: '$min min',
                          onClick: () =>
                              SleepTimerService.instance.start(min),
                        ),
                      if (remaining != null)
                        PlayerToggleChip(
                          active: false,
                          label: 'Off',
                          onClick: () =>
                              SleepTimerService.instance.cancel(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
