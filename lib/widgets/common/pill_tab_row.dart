// lib/widgets/common/pill_tab_row.dart
import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/app_units.dart';

/// One choice inside a [PillTabRow].
class SubTab {
  final String id;
  final String label;
  final IconData icon;

  const SubTab({required this.id, required this.label, required this.icon});
}

/// A segmented pill control a page can position inline, beside other
/// filter controls, rather than in a row of its own above everything.
///
/// This was once the inner half of a `SectionSubTabs` wrapper that owned
/// the whole page layout. The wrapper was never used by any hub section --
/// Movies and Series, the case it was built for, became two top-level
/// sections instead -- so it has been removed and this is what remains.
class PillTabRow extends StatelessWidget {
  final List<SubTab> tabs;
  final String activeId;
  final ValueChanged<String> onSelected;

  const PillTabRow({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // Scrolls rather than overflows. Two short labels always fit, but a
    // three-way split with longer ones ("Audiobooks / Books / Manga")
    // runs past a 360px phone, and further still at a large text scale.
    // Centered when it fits: the pills are the page's tabs, and tabs sit
    // in the middle. The min-width box is what makes both true -- narrow
    // content centers inside the viewport width, wide content keeps its
    // size and scrolls.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(context.rem(0.1875)),
              decoration: BoxDecoration(
                color: AppColors.inkAlpha(0.05),
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                border: Border.all(color: AppColors.inkAlpha(0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs)
                    _SubTabButton(
                      tab: tab,
                      selected: tab.id == activeId,
                      onTap: () => onSelected(tab.id),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final SubTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.4375)),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeService.currentPalette.value.primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: context.rem(0.9375),
              // White on the accent fill; theme ink when there is no fill.
              color: selected ? AppColors.onAccent : AppColors.inkSubtle,
            ),
            SizedBox(width: context.rem(AppRem.snug)),
            Text(
              tab.label,
              // Clamped: LibraryTabs hosts this row in AppBar.bottom, a
              // PreferredSize fixed at 52 tall. Unclamped, a large
              // accessibility text size grows this label past that fixed
              // height and overflows it (#69).
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              style: TextStyle(
                color: selected ? AppColors.onAccent : AppColors.inkAlpha(0.60),
                fontSize: AppType.captionPlus,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
