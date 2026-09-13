import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
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

  const FilterDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.of(context) == ScreenTier.mobile;
    return PopupMenuButton<T>(
      itemBuilder: (context) => items,
      onSelected: onSelected,
      color: AppColors.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: isMobile ? label : '',
      child: Container(
        constraints: const BoxConstraints(
          minWidth: headerPillMinSize,
          minHeight: headerPillMinSize,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: 8,
        ),
        decoration: headerPillDecoration,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: headerPillIconSize, color: AppColors.inkMuted),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.inkSubtle,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
