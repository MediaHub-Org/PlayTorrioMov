import 'package:flutter/material.dart';

import '../../models/my_list/my_list_item.dart';
import '../../services/my_list/my_list_service.dart';
import 'like_button.dart';

/// The app's one set of library actions: **Watchlist**, **Watched**, **Like**.
///
/// Watchlist and Watched are mutually exclusive -- setting one clears the
/// other -- while Like is an independent toggle, so something can be both
/// Watched and Liked.
///
/// This exists so Movies, Series and Anime offer the same three actions,
/// spelled the same way, writing to the same store. Anime used to carry a
/// different vocabulary entirely (a `PopupMenuButton` over AniList's
/// Watching / Plan to Watch / Completed / Dropped) that wrote only to
/// `AnimeLibraryService` -- which meant the Library page's own "Anime"
/// filter, which reads `MyListItem.type == 'anime'`, could never match
/// anything a user saved.
class LibraryActionsRow extends StatelessWidget {
  /// Builds the item these buttons act on. A callback rather than a value
  /// because a details page's metadata can still be loading when the row
  /// first builds.
  final MyListItem Function() itemBuilder;

  /// Called after a toggle is applied, with the item's state as it now
  /// stands. Anime uses this to mirror Watchlist/Watched onto
  /// `AnimeLibraryService`, which owns per-episode progress and the anime
  /// carousels, so the two stores cannot drift apart.
  final void Function(MyListItem? entry)? onChanged;

  const LibraryActionsRow({
    super.key,
    required this.itemBuilder,
    this.onChanged,
  });

  /// The entry in My List matching [itemBuilder]'s item, or null if it has
  /// never been saved.
  static MyListItem? entryFor(List<MyListItem> items, MyListItem probe) {
    for (final i in items) {
      if (i.uniqueKey == probe.uniqueKey || i.matches(probe)) return i;
    }
    return null;
  }

  void _apply(void Function(MyListItem) action) {
    final item = itemBuilder();
    action(item);
    onChanged?.call(entryFor(MyListService.items.value, item));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MyListItem>>(
      valueListenable: MyListService.items,
      builder: (context, items, _) {
        final entry = entryFor(items, itemBuilder());
        final isWatchlist = entry?.isWatchlist ?? false;
        final isWatched = entry?.isWatched ?? false;
        final isLiked = entry?.isLiked ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusButton(
              icon: isWatchlist
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              label: isWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
              active: isWatchlist,
              color: const Color(0xFF7C5CFF),
              onTap: () => _apply(MyListService.setWatchlist),
            ),
            const SizedBox(width: 10),
            _StatusButton(
              icon: isWatched
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              label: isWatched ? 'Mark as unwatched' : 'Mark as watched',
              active: isWatched,
              color: const Color(0xFF00D294),
              onTap: () => _apply(MyListService.setWatched),
            ),
            const SizedBox(width: 10),
            LikeButton(
              isLiked: isLiked,
              onTap: () => _apply(MyListService.toggleLiked),
              style: LikeButtonStyle.boxedIcon,
            ),
          ],
        );
      },
    );
  }
}

/// Icon-only with a hover [Tooltip] for the label: once three buttons share
/// a details page's action row there is no width left for "Add to
/// watchlist" as text, and an icon cannot overflow the way that label did.
class _StatusButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  State<_StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<_StatusButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovering ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.active
                    ? widget.color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.active
                      ? widget.color.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Icon(
                widget.icon,
                color: widget.active ? widget.color : Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
