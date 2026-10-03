import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_units.dart';
import 'focus_highlight.dart';
import 'header_pill_style.dart';
import '../../services/theme/app_colors.dart';

/// A small pill button that opens a popup menu — used for sort/filter
/// controls on catalog pages (e.g. decade filter + sort on Movies/Series,
/// genre filter on Anime). Icon-only on mobile, where several of these in a
/// row with full labels ran too wide; the label comes back once there's
/// room, on tablet/desktop.
///
/// The menu opens through [showMenu] directly rather than a
/// [PopupMenuButton]: a genre list dozens long would grow the menu past the
/// screen, and the button offers no height cap, so the menu carries a
/// rem-based max height and scrolls past it instead.
class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T?> onSelected;

  /// The value ticked in the menu, or null for no tick. This is the sentinel
  /// the caller already shows as its label (`''` for "All genres", `-1` for
  /// "All decades", the sort itself): a null route result means dismissal,
  /// never a choice, so the sentinels are the only values that can arrive.
  final T? selectedValue;

  /// Whether the label shows beside the icon. Null follows the screen tier
  /// (icon-only on a phone); a caller that has measured its own row passes
  /// the answer instead -- the search bar does, so a phone wide enough for
  /// the words gets them and a narrow one gets icons.
  final bool? showLabel;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
    this.selectedValue,
    this.showLabel,
  });

  /// The menu's height ceiling. Past it the route scrolls: uncapped, a long
  /// genre list ran the menu off the screen with no way to reach the far
  /// rows. In rem so it grows with text scale like the rows do.
  static const double _maxMenuHeightRem = 22;

  /// Opens the menu under the pill. Null (a tap outside) is a dismissal and
  /// reports nothing -- matching PopupMenuButton, whose onSelected never
  /// fires for one -- so a dismissed menu cannot reset a filter.
  Future<void> _openMenu(BuildContext buttonContext) async {
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final button = buttonContext.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final result = await showMenu<T>(
      context: buttonContext,
      position: position,
      items: _tickedItems(buttonContext),
      color: AppColors.raised,
      // The pill's own corner and edge (see headerPillDecoration), so the
      // menu that opens from it reads as the same shape grown, not a
      // rounder box that starts somewhere else.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          buttonContext.rem(AppRem.radiusPill),
        ),
        side: BorderSide(
          color: headerPillTint(buttonContext).withValues(alpha: 0.10),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: buttonContext.rem(_maxMenuHeightRem),
      ),
    );
    if (result != null) onSelected(result);
  }

  /// The caller's rows with a tick on the active one. Only plain value rows
  /// are touched -- dividers and custom entries pass through as they are,
  /// and rows the caller already wired with their own tap handler keep it.
  List<PopupMenuEntry<T>> _tickedItems(BuildContext context) {
    final selected = selectedValue;
    if (selected == null) return items;
    return [
      for (final entry in items)
        if (entry is PopupMenuItem<T> &&
            entry.onTap == null &&
            entry.value == selected)
          PopupMenuItem<T>(
            value: entry.value,
            enabled: entry.enabled,
            height: entry.height,
            padding: entry.padding,
            textStyle: entry.textStyle,
            labelTextStyle: entry.labelTextStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: context.rem(AppRem.iconXs),
                  color: AppColors.accent,
                ),
                SizedBox(width: context.rem(AppRem.snug)),
                Flexible(child: entry.child ?? const SizedBox.shrink()),
              ],
            ),
          )
        else
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final isMobile = !(showLabel ??
        AppBreakpoints.of(context) != ScreenTier.mobile);
    // Over a hero this pill sits on a photo, so its glyphs stay white; in
    // its own band they follow the theme. See the OverArtwork marker.
    final tint = headerPillTint(context);
    return FocusHighlight(
      borderRadius: context.rem(AppRem.radiusPill + AppRem.xs),
      child: Builder(
        builder: (buttonContext) {
          final pill = InkWell(
            borderRadius: BorderRadius.circular(
              context.rem(AppRem.radiusPill + AppRem.xs),
            ),
            onTap: () => _openMenu(buttonContext),
            child: Container(
              constraints: BoxConstraints(
                minWidth: context.rem(AppRem.target),
                minHeight: context.rem(AppRem.target),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.rem(isMobile ? AppRem.sm : AppRem.ms),
                vertical: context.rem(AppRem.sm),
              ),
              decoration: headerPillDecoration(context),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: context.rem(AppRem.iconXs),
                    color: tint.withValues(alpha: 0.70),
                  ),
                  if (!isMobile) ...[
                    SizedBox(width: context.rem(AppRem.snug)),
                    Text(
                      label,
                      style: TextStyle(
                        color: tint,
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: tint.withValues(alpha: 0.54),
                    size: context.rem(AppRem.iconSm),
                  ),
                ],
              ),
            ),
          );
          if (!isMobile) return pill;
          return Tooltip(message: label, child: pill);
        },
      ),
    );
  }
}
