import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../pages/search/search_page.dart';
import '../../utils/navigation/route_transitions.dart';
import 'header_pill_style.dart';

/// A search icon button meant for each catalog/section page's own header
/// pill row. It opens the one search page everywhere, arriving with the
/// section it was pressed from pre-selected as a chip (via `SearchScope`) --
/// so the same icon always means the same thing, and the scope is something
/// the user can see and widen rather than a hidden mode.
///
/// Shares [headerPillDecoration] with [FilterDropdown] and
/// [HeaderPillIconButton] so it reads as part of the same pill row instead
/// of a bare, undecorated icon next to controls that do have a
/// background/border.
class PageSearchButton extends StatelessWidget {
  /// Overrides the default navigation to the app-wide [SearchPage]. Only
  /// two callers still need it: Live TV, whose search matches a portal's
  /// streams by keyword rather than searching a title catalog, and Anime
  /// in Arabic mode, whose catalog the unified search has no source for.
  final VoidCallback? onTap;

  const PageSearchButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.commonSearch,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap ?? () => pushPage(context, const SearchPage()),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: headerPillMinSize,
              minHeight: headerPillMinSize,
            ),
            padding: const EdgeInsets.all(8),
            decoration: headerPillDecoration(context),
            alignment: Alignment.center,
            child: Icon(
              Icons.search_rounded,
              size: headerPillIconSize,
              color: headerPillTint(context).withValues(alpha: 0.70),
            ),
          ),
        ),
      ),
    );
  }
}
