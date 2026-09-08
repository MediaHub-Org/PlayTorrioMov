import 'package:flutter/material.dart';

/// The one background/border every header pill control shares --
/// [FilterDropdown]'s genre/decade/sort pills, [PageSearchButton], and
/// [HeaderPillIconButton] -- so a plain icon action (like a bare search
/// button) never reads as visually different from the dropdown pills it
/// sits next to in the same row. Also used by Live TV's own header, which
/// used to carry a completely different, bespoke "glass" look.
const BoxDecoration headerPillDecoration = BoxDecoration(
  color: Color(0x0FFFFFFF), // Colors.white @ 6%
  borderRadius: BorderRadius.all(Radius.circular(10)),
  border: Border.fromBorderSide(
    BorderSide(color: Color(0x1AFFFFFF)),
  ), // white @ 10%
);

const double headerPillIconSize = 15;

/// Minimum width/height every header pill control (icon-only or not) keeps
/// as its tap target, even where its visible padding+content would draw
/// smaller -- an icon-only pill was landing around 31px, under both
/// Material's 48px and iOS HIG's 44px minimum touch target guidance. Set to
/// 40 to match this app's other small square icon buttons (e.g.
/// `SettingsIconButton`) rather than inventing a third size.
const double headerPillMinSize = 40;

/// A single icon-only pill button using [headerPillDecoration] -- for a
/// plain action (not a dropdown, not search) inside a header pill row, e.g.
/// Live TV's "manage sources" and "multi-view" buttons.
class HeaderPillIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const HeaderPillIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: headerPillMinSize,
              minHeight: headerPillMinSize,
            ),
            padding: const EdgeInsets.all(8),
            decoration: headerPillDecoration,
            alignment: Alignment.center,
            child: Icon(icon, size: headerPillIconSize, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
