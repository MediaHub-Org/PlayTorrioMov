import 'package:flutter/material.dart';

/// The filter/search pill row floated over a page's hero, shared by every
/// browse page (Movies, Series, Anime) so the row sits at the same inset
/// and wraps the same way everywhere, instead of each page hand-rolling
/// its own padding and positioning.
///
/// Callers place this as the `header` of `BrowseScaffold(overlayHeader:
/// true, ...)`, or wrap it in their own full-width `Positioned(top: 0,
/// left: 0, right: 0, ...)` when they don't use `BrowseScaffold` (e.g.
/// Anime's bespoke hero page) -- either way the bar itself applies the
/// same inset and safe-area handling, so the pills land in the same place.
class PillFilterHeaderBar extends StatelessWidget {
  final List<Widget> pills;

  const PillFilterHeaderBar({super.key, required this.pills});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: pills,
        ),
      ),
    );
  }
}
