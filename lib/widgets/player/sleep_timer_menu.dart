import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';
import '../../services/app_units.dart';

/// The sleep timer, one option per row.
///
/// Six rows, each a duration and nothing else. It carried a custom stepper
/// and a "pauses at 02:14" line under every preset for a while, and both
/// made a list of six numbers look like a form: the time a timer ends at is
/// arithmetic a viewer can do, and a preset that does not suit is not worth
/// a pair of -/+ buttons in a menu opened from a moon icon.
///
/// The rows are told apart by duration, so the tick marks which one is
/// armed. "End of video" is the last row because it is the one promise in
/// the list that is not a number of minutes.
class SleepTimerMenu extends StatelessWidget {
  const SleepTimerMenu({super.key});

  static const minutes = [10, 15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      padding: EdgeInsets.all(context.rem(0.625)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlayerMenuHeader(
            title: context.l10n.playerSleepTimer.toUpperCase(),
          ),
          SizedBox(height: context.rem(AppRem.snug)),
          ValueListenableBuilder<int?>(
            valueListenable: SleepTimerService.instance.minutesRemaining,
            builder: (context, remaining, _) {
              return ValueListenableBuilder<bool>(
                valueListenable:
                    SleepTimerService.instance.armedForEndOfVideo,
                builder: (context, endOfVideo, __) {
                  final isArmed = remaining != null || endOfVideo;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final min in minutes)
                        PlayerMenuRow(
                          leading: const SizedBox(width: 0),
                          title: context.l10n.playerMinutesShort(min),
                          isSelected: remaining == min,
                          onTap: () => SleepTimerService.instance.start(min),
                        ),
                      PlayerMenuRow(
                        leading: const SizedBox(width: 0),
                        title: context.l10n.playerSleepEndOfVideo,
                        isSelected: endOfVideo,
                        onTap: () => SleepTimerService.instance
                            .startUntilEndOfVideo(),
                      ),
                      if (isArmed) ...[
                        SizedBox(height: context.rem(AppRem.xs)),
                        const Divider(color: PlayerTheme.edgeSoft, height: 1), // px: a hairline, not a layout size
                        TextButton.icon(
                          onPressed: SleepTimerService.instance.cancel,
                          icon: Icon(Icons.timer_off_outlined, size: context.rem(0.9375)),
                          label: Text(
                            remaining != null
                                ? context.l10n.playerSleepOff(remaining)
                                : context.l10n.playerSleepOffShort,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: PlayerTheme.inkSubtle,
                            minimumSize: Size(0, context.rem(2.25)),
                            textStyle: const TextStyle(fontSize: AppType.caption),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}