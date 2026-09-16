import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'player_glass.dart';

/// Settings entry point -- the gear icon opens this. It used to be an index
/// of every player control (audio, subtitles, speed, aspect), which made it
/// a menu of menus: three taps to reach a speed that was one tap away on
/// YouTube. Those four are transport-bar buttons now, in the order a viewer
/// reaches for them.
///
/// What is left here is the two things that have no button of their own:
/// the subtitle's appearance editor -- a five-tab surface too large for the
/// track list it belongs to -- and the sleep timer.
class PlayerSettingsMenu extends StatelessWidget {
  /// Current subtitle state, e.g. a language name or "Off". Null hides the
  /// row (nothing to configure -- no subtitles available at all).
  final String? subtitleLabel;

  /// Opens subtitle track/style picking.
  final VoidCallback? onTapSubtitles;

  const PlayerSettingsMenu({
    super.key,
    this.subtitleLabel,
    this.onTapSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // No height cap and no scroll view of its own: PlayerMenuAnchor bounds
    // the popover to the space above the transport bar and scrolls it when
    // the rows do not fit.
    return PlayerGlassCard(
      width: (260.0).clamp(220.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlayerMenuHeader(title: 'SETTINGS'),
          const SizedBox(height: 6),
          if (onTapSubtitles != null)
            _SettingsRow(
              icon: Icons.subtitles_rounded,
              label: context.l10n.detailsSubtitles,
              value: subtitleLabel ?? context.l10n.detailsOff,
              onTap: onTapSubtitles!,
            ),
          const _SleepTimerRow(),
        ],
      ),
    );
  }
}

/// The sleep timer, as a row of preset chips. It lived at the bottom of the
/// speed menu before, which was the one place a viewer winding down for the
/// night would not look for it.
class _SleepTimerRow extends StatefulWidget {
  const _SleepTimerRow();

  @override
  State<_SleepTimerRow> createState() => _SleepTimerRowState();
}

class _SleepTimerRowState extends State<_SleepTimerRow> {
  int? _selectedMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'SLEEP TIMER',
            style: TextStyle(
              color: PlayerTheme.inkSubtle,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [15, 30, 45, 60].map((min) {
              final active = _selectedMinutes == min;
              return PlayerToggleChip(
                active: active,
                label: '$min min',
                onClick: () => setState(() => _selectedMinutes = active ? null : min),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          // A minimum rather than a fixed height. At 44 it was a hard box:
          // the label and the value both grow with text scale, and the row
          // had nowhere to put them -- 436px past the card at 3x on the
          // longest row. The card is bounded by PlayerMenuAnchor, which
          // scrolls when the rows no longer fit, so growing here is safe.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: PlayerTheme.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: PlayerTheme.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The value was the un-flexed half of this row: the label
              // shrank to its share and the value beside it did not, so a
              // long track name ("English (Dubbed)") painted out the side.
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: PlayerTheme.inkSubtle,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: PlayerTheme.inkSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
