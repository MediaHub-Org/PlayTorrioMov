import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/hub_controller.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';

/// The section switcher for tablet and desktop, driven by
/// [HubController.currentSections]: one chip per section, centered, and
/// scrolling sideways when the width cannot hold them all.
///
/// It sits in the middle of [TopBar], between the logo and Settings. It used
/// to be a bar of its own under the top bar; the two shared one row of
/// content's worth of height for nothing, so the second row was dropped
/// rather than the sections moved anywhere new.
///
/// Renders nothing on mobile. Phones show the same sections in the bottom
/// tab bar (see [AdaptiveNavShell]), where they are easier to reach; drawing
/// them here as well would be a second copy of the same control.
class SectionChips extends StatelessWidget {
  const SectionChips({super.key});

  @override
  Widget build(BuildContext context) {
    // Built as `const SectionChips()` by TopBar.
    AppColors.dependOn(context);
    // Mobile shows these in the bottom tab bar instead.
    if (AppBreakpoints.of(context) == ScreenTier.mobile) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: HubController.instance,
      builder: (context, _) {
        final sections = HubController.instance.currentSections;
        final activeId = HubController.instance.currentSectionId;
        if (sections.isEmpty) return const SizedBox.shrink();

        // Center over a scroll view: centered when the chips fit, scrollable
        // (and D-pad focus scrolls it into view) when they do not.
        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _Chip(
                    label: sections[i].localizedLabel(context),
                    icon: sections[i].icon,
                    selected: sections[i].id == activeId,
                    onTap: () =>
                        HubController.instance.setCurrentSection(sections[i].id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatefulWidget {
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
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final selected = widget.selected;
    AppColors.dependOn(context);
    // The accent used to be a hardcoded violet, so the selected section
    // stayed the same color whichever of the eight palettes was chosen --
    // the one control on screen that ignored the theme.
    final accent = AppThemeService.currentPalette.value.primaryColor;
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (focused) => setState(() => _focused = focused),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          // A remote's focus needs to read from across a room, and the
          // InkWell's own overlay is a faint tint. A ring in the ink color
          // shows on the selected chip's accent fill and on the bar alike.
          border: Border.all(
            color: _focused ? AppColors.ink : Colors.transparent,
            width: 2,
          ),
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
              // Clamped: the chip sits in TopBar's fixed height, which
              // callers inset content by, so it cannot grow with the text
              // (#69). The label still scales, up to that ceiling.
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              maxLines: 1,
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
