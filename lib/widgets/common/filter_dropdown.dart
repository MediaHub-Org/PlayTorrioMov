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
class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T?> onSelected;

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
    this.showLabel,
  });

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
      child: PopupMenuButton<T>(
      itemBuilder: (context) => items,
      onSelected: onSelected,
      color: AppColors.raised,
      // The pill's own corner and edge (see headerPillDecoration), so the
      // menu that opens from it reads as the same shape grown, not a
      // rounder box that starts somewhere else.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
        side: BorderSide(color: tint.withValues(alpha: 0.10)),
      ),
      tooltip: isMobile ? label : '',
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
      ),
    );
  }
}
