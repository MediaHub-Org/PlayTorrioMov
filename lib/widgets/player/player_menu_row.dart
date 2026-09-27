import 'package:flutter/material.dart';

import 'player_glass.dart';

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
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? PlayerTheme.raised : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
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
                  size: 15,
                  color:
                      isSelected ? PlayerTheme.accent : PlayerTheme.inkDisabled,
                ),
                const SizedBox(width: 8),
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                for (final badge in badges) ...[
                  const SizedBox(width: 5),
                  _MiniBadge(badge),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PlayerTheme.raised,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PlayerTheme.inkSubtle,
          fontSize: 9,
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: PlayerTheme.inkSubtle,
          fontSize: 10,
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
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 10),
      child: Text(
        text,
        style: const TextStyle(color: PlayerTheme.inkDisabled, fontSize: 12),
      ),
    );
  }
}