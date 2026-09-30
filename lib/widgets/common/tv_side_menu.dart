import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/hub_controller.dart';
import 'hover_button.dart';

/// The hub's navigation on a TV: the sections, Search and Settings as a
/// vertical rail on the left, in place of the top bar.
///
/// It is built inside the content's own route (see [TvHubFrame]), not next to
/// it. The top bar sits outside `NestedNavigator`'s `Navigator`, and each
/// route has its own focus scope, which directional traversal cannot cross:
/// the remote could move through the rows but never up to the bar, through
/// two attempts to bridge the gap by hand. Here the rail and the rows are in
/// one scope, so pressing Left from the first card of any row reaches it with
/// nothing but ordinary traversal -- the one thing known to work on the
/// device.
class TvSideMenu extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;

  const TvSideMenu({
    super.key,
    required this.onSearchTap,
    required this.onSettingsTap,
  });

  /// Proportional to the window like the poster cards, not a fixed number:
  /// wide enough for "Live TV" and its icon at couch distance, never more
  /// than a tenth-odd of the screen.
  static double widthFor(BuildContext context) =>
      AppSpacing.cardWidthForScreenWidth(
        MediaQuery.sizeOf(context).width,
        min: context.rem(AppRem.menuMin),
        max: context.rem(AppRem.menuMax),
        factor: 0.11,
      );

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      width: widthFor(context),
      padding: EdgeInsets.fromLTRB(
        context.rem(AppRem.sm),
        MediaQuery.paddingOf(context).top + context.rem(AppRem.md),
        context.rem(AppRem.sm),
        context.rem(AppRem.md),
      ),
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border(
          right: BorderSide(color: AppColors.inkAlpha(0.14)),
        ),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final sections = HubController.instance.currentSections;
          final activeId = HubController.instance.currentSectionId;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in sections)
                _MenuItem(
                  icon: section.icon,
                  label: section.localizedLabel(context),
                  selected: section.id == activeId,
                  onTap: () => HubController.instance.setCurrentSection(section.id),
                ),
              const Spacer(),
              _MenuItem(
                icon: Icons.search_rounded,
                label: context.l10n.commonSearch,
                selected: false,
                onTap: onSearchTap,
              ),
              _MenuItem(
                icon: Icons.settings_rounded,
                label: context.l10n.commonSettings,
                selected: false,
                onTap: onSettingsTap,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final accent = AppThemeService.currentPalette.value.primaryColor;
    final foreground = selected ? AppColors.onAccent : AppColors.inkSubtle;
    final radius = context.rem(AppRem.radiusMd);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.xxs)),
      child: HoverButton(
        scaleAmount: 1.03,
        showFocusRing: true,
        focusRingBorderRadius: radius + context.rem(AppRem.xs),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(context.rem(AppRem.ms)),
          decoration: BoxDecoration(
            color: selected ? accent : AppColors.inkAlpha(0.05),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Row(
            children: [
              Icon(icon, size: context.rem(AppRem.icon), color: foreground),
              SizedBox(width: context.rem(AppRem.sm)),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppType.body,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The content route on a TV: [menu] beside [child], in one focus scope.
class TvHubFrame extends StatelessWidget {
  final Widget menu;
  final Widget child;

  const TvHubFrame({super.key, required this.menu, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        menu,
        Expanded(child: child),
      ],
    );
  }
}
