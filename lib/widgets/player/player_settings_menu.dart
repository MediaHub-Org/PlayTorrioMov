import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../services/tv_type.dart';
import '../common/focus_fill.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';

/// The gear's root menu: quality plus the four set-once controls that used
/// to share the transport bar with subtitles and stats.
///
/// Quality leads, as on YouTube -- with one honest difference: a torrent or
/// a direct file has no in-stream variants to switch between (each quality
/// is a different release), so the row opens the Sources panel instead of a
/// variant list. Its badge names the current source's detected resolution.
///
/// Subtitles and stats keep their own buttons -- they are per-scene choices
/// a viewer reaches for mid-sentence. Speed, audio, sleep and aspect are
/// set-once-per-session choices, so they live one tap behind the gear, each
/// row stepping into its own panel with a back arrow. Each row carries its
/// current value as a badge, so the menu also reads as a status glance
/// without opening anything.
class PlayerSettingsMenu extends StatelessWidget {
  final double currentRate;
  final String? qualitySummary;
  final String? audioSummary;
  final String? aspectSummary;

  /// Opens the Sources panel. Null hides the Quality row entirely -- without
  /// an episode behind the player there is no panel to open.
  final VoidCallback? onOpenQuality;
  final VoidCallback onOpenSpeed;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenAspect;

  const PlayerSettingsMenu({
    super.key,
    required this.currentRate,
    this.qualitySummary,
    this.audioSummary,
    this.aspectSummary,
    this.onOpenQuality,
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
          if (onOpenQuality != null)
            _NavRow(
              icon: Icons.high_quality_rounded,
              title: context.l10n.playerQuality,
              summary: qualitySummary,
              onTap: onOpenQuality!,
            ),
          SizedBox(height: context.rem(AppRem.xs)),
          // The four set-once controls as a 2x2 of rectangular cards. They
          // were radio rows before, which read as four choices among each
          // other; they are four doors, so they draw as four cards filling
          // the menu's width.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SettingCard(
                    icon: Icons.speed_rounded,
                    label: context.l10n.detailsPlaybackSpeed,
                    value: '${currentRate.toStringAsFixed(2)}×',
                    onTap: onOpenSpeed,
                  ),
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                Expanded(
                  child: _SettingCard(
                    icon: Icons.audiotrack_rounded,
                    label: context.l10n.detailsAudioTrack,
                    value: audioSummary,
                    onTap: onOpenAudio,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ValueListenableBuilder<int?>(
                    valueListenable:
                        SleepTimerService.instance.minutesRemaining,
                    builder: (context, minutes, _) => _SettingCard(
                      icon: Icons.bedtime_rounded,
                      label: context.l10n.playerSleepTimer,
                      // No value when off: the card is navigation, and
                      // "Cancel timer" would read as an action rather than
                      // a status.
                      value: minutes == null
                          ? null
                          : context.l10n.playerMinutesShort(minutes),
                      onTap: onOpenSleep,
                    ),
                  ),
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                Expanded(
                  child: _SettingCard(
                    icon: Icons.aspect_ratio_rounded,
                    label: context.l10n.detailsAspectRatio,
                    value: aspectSummary,
                    onTap: onOpenAspect,
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

/// One card of the settings grid: an icon, a small label, and the current
/// value -- the status glance the radio rows carried, in a shape that reads
/// as a door to its panel rather than a choice among the four.
class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingCard({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final summary = value;
    return Material(
      color: Colors.transparent,
      child: FocusFill(
        radius: context.rem(AppRem.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: context.rem(3.75)),
            padding: EdgeInsets.all(context.rem(AppRem.ms)),
            decoration: BoxDecoration(
              color: PlayerTheme.raised,
              borderRadius:
                  BorderRadius.circular(context.rem(AppRem.radiusPill)),
              border: Border.all(color: PlayerTheme.edgeSoft),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: context.rem(AppRem.icon),
                  color: PlayerTheme.inkSubtle,
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                // Flexible, never fixed: the value can be a sentence
                // ("Original (keeps the source shape)") and the label grows
                // with text scale, so both ellipsize instead of pushing the
                // card past its half of the menu.
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PlayerTheme.inkSubtle,
                          fontSize: TvType.scale(AppType.micro),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (summary != null && summary.isNotEmpty)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PlayerTheme.ink,
                            fontSize: AppType.captionPlus,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
