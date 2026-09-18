import 'package:flutter/material.dart';
import 'over_artwork.dart';

/// The tint every header pill draws itself from -- see [OverArtwork.tint],
/// which is the same rule every other control over a hero follows.
Color headerPillTint(BuildContext context) => OverArtwork.tint(context);

/// The one background/border every header pill control shares --
/// [FilterDropdown]'s genre/decade/sort pills, [PageSearchButton], and
/// [HeaderPillIconButton] -- so a plain icon action (like a bare search
/// button) never reads as visually different from the dropdown pills it
/// sits next to in the same row. Also used by Live TV's own header, which
/// used to carry a completely different, bespoke "glass" look.
///
/// Built per call rather than held as a `const`: the tint follows both the
/// active theme and whether this row floats over a hero, neither of which
/// is known at compile time.
BoxDecoration headerPillDecoration(BuildContext context) {
  final tint = headerPillTint(context);
  return BoxDecoration(
    color: tint.withValues(alpha: 0.06),
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    border: Border.fromBorderSide(
      BorderSide(color: tint.withValues(alpha: 0.10)),
    ),
  );
}

const double headerPillIconSize = 15;

/// Minimum width/height every header pill control (icon-only or not) keeps
/// as its tap target, even where its visible padding+content would draw
/// smaller -- an icon-only pill was landing around 31px, under both
/// Material's 48px and iOS HIG's 44px minimum touch target guidance. Set to
/// 40 to match this app's other small square icon buttons (e.g.
/// `SettingsIconButton`) rather than inventing a third size.
const double headerPillMinSize = 40;

/// A non-interactive pill carrying a label, and optionally an icon before
/// it -- Live TV's "LIVE TV" and "60+ CHANNELS" markers.
///
/// Live TV built both of these inline as a `DecoratedBox` + `Padding` +
/// `Row`, twice, which is how their glyph colors came to disagree with the
/// interactive pills beside them in the same row.
class HeaderPillLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Emphasized labels use the tint at full strength; a secondary marker
  /// (a count, a unit) sits back at the same 70% the icons use.
  final bool emphasized;

  final double fontSize;
  final double letterSpacing;

  const HeaderPillLabel({
    super.key,
    required this.label,
    this.icon,
    this.emphasized = true,
    this.fontSize = 12,
    this.letterSpacing = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final tint = headerPillTint(context);
    return DecoratedBox(
      decoration: headerPillDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: tint.withValues(alpha: 0.70),
                size: headerPillIconSize,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: emphasized ? tint : tint.withValues(alpha: 0.70),
                fontSize: fontSize,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: letterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            decoration: headerPillDecoration(context),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: headerPillIconSize,
              color: headerPillTint(context).withValues(alpha: 0.70),
            ),
          ),
        ),
      ),
    );
  }
}
