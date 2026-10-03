import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/player/sleep_timer_service.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';

/// The gear's root menu: the four set-once controls that used to share the
/// transport bar with subtitles and stats.
///
/// Subtitles and stats keep their own buttons -- they are per-scene choices
/// a viewer reaches for mid-sentence. Speed, audio, sleep and aspect are
/// set-once-per-session choices, so they live one tap behind the gear, each
/// row stepping into its own panel with a back arrow. Each row carries its
/// current value as a badge, so the menu also reads as a status glance
/// without opening anything.
class PlayerSettingsMenu extends StatelessWidget {
  final double currentRate;
  final String? audioSummary;
  final String? aspectSummary;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenAspect;

  const PlayerSettingsMenu({
    super.key,
    required this.currentRate,
    this.audioSummary,
    this.aspectSummary,
    required this.onOpenSpeed,
    required this.onOpenAudio,
    required this.onOpenSleep,
    required this.onOpenAspect,
  });

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
            title: context.l10n.playerSettingsPanelTitle.toUpperCase(),
          ),
          SizedBox(height: context.rem(AppRem.snug)),
          _NavRow(
            icon: Icons.speed_rounded,
            title: context.l10n.detailsPlaybackSpeed,
            summary: '${currentRate.toStringAsFixed(2)}×',
            onTap: onOpenSpeed,
          ),
          _NavRow(
            icon: Icons.audiotrack_rounded,
            title: context.l10n.detailsAudioTrack,
            summary: audioSummary,
            onTap: onOpenAudio,
          ),
          ValueListenableBuilder<int?>(
            valueListenable: SleepTimerService.instance.minutesRemaining,
            builder: (context, minutes, _) => _NavRow(
              icon: Icons.bedtime_rounded,
              title: context.l10n.playerSleepTimer,
              // No badge when off: the row is navigation, and "Cancel timer"
              // would read as an action rather than a status.
              summary: minutes == null
                  ? null
                  : context.l10n.playerMinutesShort(minutes),
              onTap: onOpenSleep,
            ),
          ),
          _NavRow(
            icon: Icons.aspect_ratio_rounded,
            title: context.l10n.detailsAspectRatio,
            summary: aspectSummary,
            onTap: onOpenAspect,
          ),
        ],
      ),
    );
  }
}

/// One row of the settings root: an icon, a label, the current value, and
/// a chevron saying there is a panel behind it. Never selected -- this is
/// navigation, not a choice among these four.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? summary;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.title,
    this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerMenuRow(
      leading: Icon(
        icon,
        size: context.rem(0.9375),
        color: PlayerTheme.inkSubtle,
      ),
      title: title,
      badges: [if (summary != null && summary!.isNotEmpty) summary!],
      isSelected: false,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: context.rem(0.9375),
        color: PlayerTheme.inkDisabled,
      ),
    );
  }
}
