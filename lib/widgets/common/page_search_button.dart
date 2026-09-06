import 'package:flutter/material.dart';

import '../../pages/search/search_page.dart';
import '../../utils/navigation/route_transitions.dart';
import 'header_pill_style.dart';

/// A search icon button meant for each catalog/section page's own header
/// pill row. Replaces the old global header search bar — search is now
/// scoped to whatever page it's pressed from (via [SearchScope]).
///
/// Shares [headerPillDecoration] with [FilterDropdown] and
/// [HeaderPillIconButton] so it reads as part of the same pill row instead
/// of a bare, undecorated icon next to controls that do have a
/// background/border.
class PageSearchButton extends StatelessWidget {
  /// Overrides the default navigation to the app-wide [SearchPage] --
  /// Anime and Live TV route to their own scoped search page instead.
  /// Receives the tap position so the destination's reveal animation can
  /// originate from it, same as the default.
  final void Function(Offset? tapPosition)? onTap;

  const PageSearchButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Search',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            final offset = box?.localToGlobal(box.size.center(Offset.zero));
            if (onTap != null) {
              onTap!(offset);
            } else {
              Navigator.push(
                context,
                LiquidRevealRoute(
                  page: const SearchPage(),
                  tapPosition: offset,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: headerPillDecoration,
            child: const Icon(
              Icons.search_rounded,
              size: headerPillIconSize,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
