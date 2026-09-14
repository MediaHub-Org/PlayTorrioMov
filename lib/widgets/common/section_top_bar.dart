import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/hub_controller.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';

/// The section switcher shown at the top of each hub's content area on tablet
/// and desktop, driven by [HubController.currentSections].
///
/// Renders nothing on mobile. Phones show the same four sections in the bottom
/// tab bar (see [AdaptiveNavShell]), where they are easier to reach; drawing
/// them here as well would be a second copy of the same control and 44px of
/// duplicate chrome.
class SectionTopBar extends StatelessWidget {
  const SectionTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Built as `const SectionTopBar()` by AdaptiveNavShell.
    AppColors.dependOn(context);
    // Mobile shows these in the bottom tab bar instead.
    if (AppBreakpoints.of(context) == ScreenTier.mobile) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border(bottom: BorderSide(color: AppColors.inkAlpha(0.10))),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final sections = HubController.instance.currentSections;
          final activeId = HubController.instance.currentSectionId;
          if (sections.isEmpty) return const SizedBox.shrink();

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final section = sections[index];
              return _Chip(
                label: section.label,
                icon: section.icon,
                selected: section.id == activeId,
                onTap: () =>
                    HubController.instance.setCurrentSection(section.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The accent used to be a hardcoded violet, so the selected section
    // stayed the same colour whichever of the eight palettes was chosen --
    // the one control on screen that ignored the theme.
    final accent = AppThemeService.currentPalette.value.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              // Selected sits on the accent fill, so it is white in both
              // themes; unselected sits on the bar and follows the ink.
              color: selected ? AppColors.onAccent : AppColors.inkDisabled,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onAccent : AppColors.inkSubtle,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
