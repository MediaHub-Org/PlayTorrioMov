import 'package:flutter/material.dart';

import '../../services/tv_type.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// One selectable row in a player menu.
///
/// Shared by the audio and subtitle menus, which draw the same shape for the
/// same reason: a flag, a language, an optional badge, and a mark saying
/// whether it is the one playing. They used to be written out separately in
/// each menu, which is how the two drifted into labelling rows differently.
///
/// The row is a language, not a file. Four subtitle files for Arabic are one
/// row, and the badge says how many there are rather than listing their tags.
class PlayerMenuRow extends StatelessWidget {
  /// Leading artwork. A [LanguageFlag] in practice, or an empty box where a
  /// row has no language of its own.
  final Widget leading;

  final String title;

  final List<String> badges;

  final bool isSelected;
  final VoidCallback onTap;

  /// Drawn after the badges. A chevron, where a row opens something.
  final Widget? trailing;

  const PlayerMenuRow({
    super.key,
    required this.leading,
    required this.title,
    this.badges = const [],
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(0.1875)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rem(0.5625)),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: context.rem(2.375)),
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.5625), vertical: context.rem(0.3125)),
            decoration: BoxDecoration(
              color: isSelected ? PlayerTheme.raised : Colors.transparent,
              borderRadius: BorderRadius.circular(context.rem(0.5625)),
              border: Border.all(
                color: isSelected ? PlayerTheme.edge : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // A radio mark, not a filled row: which one of these is on is
                // the question the list answers, and a tick says it without
                // leaning on the accent color to carry the meaning alone.
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: context.rem(0.9375),
                  color:
                      isSelected ? PlayerTheme.accent : PlayerTheme.inkDisabled,
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                leading,
                SizedBox(width: context.rem(AppRem.sm)),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                      fontSize: AppType.captionPlus,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                for (final badge in badges) ...[
                  SizedBox(width: context.rem(0.3125)),
                  _MiniBadge(badge),
                ],
                if (trailing != null) ...[
                  SizedBox(width: context.rem(AppRem.xs)),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;

  const _MiniBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
      decoration: BoxDecoration(
        color: PlayerTheme.raised,
        borderRadius: BorderRadius.circular(context.rem(0.3125)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: PlayerTheme.inkSubtle,
          fontSize: TvType.scale(AppType.nano),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A section heading inside a menu.
class PlayerSectionLabel extends StatelessWidget {
  final String text;

  const PlayerSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.rem(AppRem.sm), context.rem(AppRem.xs), context.rem(AppRem.sm), context.rem(AppRem.snug)),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: PlayerTheme.inkSubtle,
          fontSize: TvType.scale(AppType.micro),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// "Nothing here", inside a menu rather than as an empty box.
class PlayerMenuEmptyRow extends StatelessWidget {
  final String text;

  const PlayerMenuEmptyRow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.rem(0.5625), context.rem(AppRem.snug), context.rem(0.5625), context.rem(0.625)),
      child: Text(
        text,
        style: const TextStyle(color: PlayerTheme.inkDisabled, fontSize: AppType.caption),
      ),
    );
  }
}