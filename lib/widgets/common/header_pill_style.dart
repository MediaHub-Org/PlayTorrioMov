import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';

/// Whether the header pills in this subtree are drawn over artwork.
///
/// A browse page's pill row is in one of two places depending on the page's
/// state: in its own band above the content, where it sits on the app's
/// background and follows the theme's ink; or floated over the hero
/// carousel on a dark scrim, where it sits on a photograph. A photograph is
/// a photograph in either theme, so the pills over one stay white --
/// exactly the `ink` vs `onAccent` distinction [AppColors] draws.
///
/// [BrowseScaffold] is the only thing that knows which case applies (see its
/// `headerOverlaysHero`), and it changes with the page's own loading and
/// empty states. The pills cannot be told through a constructor because
/// callers build and pass them in already-constructed, so the answer
/// travels down the tree instead. Absent an ancestor the answer is "no",
/// which is right for every pill row outside a hero.
class HeaderPillSurface extends InheritedWidget {
  final bool overArtwork;

  const HeaderPillSurface({
    super.key,
    required this.overArtwork,
    required super.child,
  });

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HeaderPillSurface>()
          ?.overArtwork ??
      false;

  @override
  bool updateShouldNotify(HeaderPillSurface oldWidget) =>
      oldWidget.overArtwork != overArtwork;
}

/// The tint every header pill draws itself from: its border, its background
/// wash and its icon are all this colour at different opacities, so a pill
/// cannot end up with a light border and a dark glyph.
Color headerPillTint(BuildContext context) =>
    HeaderPillSurface.of(context) ? AppColors.onAccent : AppColors.ink;

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
/// `Row`, twice, which is how their glyph colours came to disagree with the
/// interactive pills beside them in the same row.
class HeaderPillLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Emphasised labels use the tint at full strength; a secondary marker
  /// (a count, a unit) sits back at the same 70% the icons use.
  final bool emphasised;

  final double fontSize;
  final double letterSpacing;

  const HeaderPillLabel({
    super.key,
    required this.label,
    this.icon,
    this.emphasised = true,
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
                color: emphasised ? tint : tint.withValues(alpha: 0.70),
                fontSize: fontSize,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w700,
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
