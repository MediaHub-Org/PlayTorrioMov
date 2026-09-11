import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'header_pill_style.dart';

/// Vertical breathing room above and below the pill row.
const double _kBarVerticalPadding = 12;

/// Height of the bar's content, excluding the status-bar inset. The pills
/// themselves keep [headerPillMinSize] as their tap target, so the row is
/// exactly that tall.
const double pillFilterHeaderContentHeight =
    headerPillMinSize + _kBarVerticalPadding * 2;

/// The filter/search pill row at the top of every browse page (Movies,
/// Series, Anime, Live TV), so the row sits at the same inset and behaves
/// the same way everywhere instead of each page hand-rolling its own
/// padding and positioning.
///
/// The pills stay on **one line**. When they do not all fit -- a phone with
/// genre, decade, sort and search showing at once -- the row scrolls
/// horizontally rather than wrapping onto a second run, so the bar keeps a
/// fixed height and the content below it never shifts as filters change
/// their labels ("All genres" -> "Science Fiction").
///
/// The bar is meant to be placed *above* a page's scrollable, not floated
/// over it: callers put it in a `Column` with the scroll view in the
/// `Expanded` below (that is what [BrowseScaffold] does), which is what
/// makes it stay put while the page scrolls. Pinning it as a transparent
/// overlay instead is what made it look broken in 1.2.1 -- content slid
/// visibly underneath it. Here nothing scrolls under the bar at all,
/// because the scroll viewport starts below it.
class PillFilterHeaderBar extends StatelessWidget {
  /// Pills pinned to the leading edge -- Live TV's section title and
  /// channel count. Empty on the browse pages, which carry filters only.
  final List<Widget> leading;

  /// Pills pinned to the trailing edge: the genre/decade/sort dropdowns
  /// and the search button.
  final List<Widget> pills;

  /// Draws a hairline under the bar, separating it from the content below.
  /// Null defaults to the opposite of [transparent]: an opaque bar sitting
  /// in its own band above the content wants the hairline to mark that
  /// edge, but a transparent bar floats *over* a hero image -- a hard line
  /// cutting across it would look like a rendering glitch, not a border.
  final bool? showDivider;

  /// When true, the fixed pill strip itself hides its own background and
  /// lets the hero/carousel show directly through. This supports the
  /// roadmap's transparent top-pills pattern without disturbing the rest of
  /// the shared header layout.
  final bool transparent;

  const PillFilterHeaderBar({
    super.key,
    required this.pills,
    this.leading = const [],
    this.showDivider,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedShowDivider = showDivider ?? !transparent;
    final inset = AppSpacing.pageInset(context);

    // No SafeArea here: every page that uses this bar renders inside the
    // hub's content area, and AdaptiveNavShell has already inset past the
    // status bar (SizedBox(topPadding) + TopBar) before the content starts.
    // Wrapping again double-counted the notch, and made this bar taller
    // than pillFilterHeaderContentHeight claims.
    final bar = SizedBox(
      height: pillFilterHeaderContentHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // minWidth keeps the row right-aligned while the pills fit,
          // and lets it grow past the viewport (so the SingleChildScroll
          // View actually scrolls) once they do not.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: inset,
              vertical: _kBarVerticalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: (constraints.maxWidth - inset * 2).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              // No Spacer/Expanded in here: the row is laid out with an
              // unbounded max width so it can scroll, and a flex child
              // would throw. spaceBetween does the same job off the
              // minWidth above, and collapses to packed once the pills
              // are wide enough to scroll.
              child: Row(
                mainAxisAlignment: leading.isEmpty
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading.isNotEmpty) _group(leading),
                  _group(pills),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!resolvedShowDivider) return bar;

    // DecoratedBox, not a Container with a border: a Container's border
    // becomes layout padding, which would make the bar 1px taller than
    // pillFilterHeaderContentHeight says it is.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : null,
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: bar,
    );
  }

  /// One run of pills, evenly spaced, sized to its content.
  static Widget _group(List<Widget> items) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          items[i],
        ],
      ],
    );
  }
}
