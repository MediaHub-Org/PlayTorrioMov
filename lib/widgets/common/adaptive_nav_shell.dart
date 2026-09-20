import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/hub_controller.dart';
import 'top_bar.dart';
import '../../services/theme/app_colors.dart';

/// Tier-aware nav chrome wrapping the Media hub's content area.
///
/// Desktop/tablet use one [TopBar] row: logo, the sections as chips in the
/// middle (see [SectionChips]), settings on the right.
///
/// Mobile mirrors that hierarchy: the bottom bar -- the easiest thing to
/// reach on a phone -- carries the hub's four sections. The header is just
/// the wordmark and a settings button.
class AdaptiveNavShell extends StatelessWidget {
  /// Height of the mobile bottom tab bar. Callers positioning other
  /// bottom-anchored chrome (e.g. a mini player) above it on mobile
  /// should offset by at least this much.
  static const double mobileBottomBarHeight = 64;

  /// Total space the mobile bottom tab bar occupies on screen, including
  /// the device's bottom safe-area inset (e.g. the iOS home indicator).
  /// Callers positioning other bottom-anchored chrome above it on mobile
  /// (e.g. a mini player) should use this instead of [mobileBottomBarHeight]
  /// alone, or their chrome will overlap the inset.
  static double mobileBottomBarInset(BuildContext context) =>
      mobileBottomBarHeight + MediaQuery.paddingOf(context).bottom;

  final Widget child;
  final VoidCallback? onSettingsTap;

  const AdaptiveNavShell({
    super.key,
    required this.child,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    // Both bars below are handed down const, so they will not rebuild on a
    // theme change on their own -- see AppColors.dependOn.
    AppColors.dependOn(context);
    final tier = AppBreakpoints.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (tier == ScreenTier.mobile) {
      return Column(
        children: [
          SizedBox(height: topPadding),
          TopBar(onSettingsTap: onSettingsTap),
          Expanded(child: child),
          const SafeArea(top: false, child: _MobileSectionTabBar()),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topPadding),
        // Outside `child` (NestedNavigator) on purpose: a page pushed within
        // the hub's own nested Navigator (Details, Search, ...) replaces
        // everything inside that navigator, which used to include the
        // section bar when it lived inside MediaHub -- hiding the 5 sections
        // behind every detail/search page. Sitting here, as a sibling above
        // the navigated content, mirrors how the mobile bottom tab bar
        // already sits outside `child` and so never gets covered either.
        // The sections are inside this bar now, so that holds for them too.
        TopBar(onSettingsTap: onSettingsTap),
        Expanded(child: child),
      ],
    );
  }
}

/// The four sections of the hub, in the bottom bar where they are easiest to
/// reach.
class _MobileSectionTabBar extends StatelessWidget {
  const _MobileSectionTabBar();

  @override
  Widget build(BuildContext context) {
    // Built as `const _MobileSectionTabBar()`, so this is what makes the bar
    // repaint when the theme changes rather than at the next navigation.
    AppColors.dependOn(context);
    return Container(
      key: const Key('adaptiveNavMobileBar'),
      height: AdaptiveNavShell.mobileBottomBarHeight,
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border(top: BorderSide(color: AppColors.inkAlpha(0.12))),
      ),
      child: ListenableBuilder(
        listenable: HubController.instance,
        builder: (context, _) {
          final sections = HubController.instance.currentSections;
          final activeId = HubController.instance.currentSectionId;
          return Row(
            children: [
              for (final section in sections)
                Expanded(
                  child: _SectionTab(
                    section: section,
                    selected: section.id == activeId,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final HubSection section;
  final bool selected;

  const _SectionTab({required this.section, required this.selected});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final color = selected ? AppColors.ink : AppColors.inkSubtle;
    // Clamped, not left to follow the system/in-app scale 1:1: this Column
    // sits inside AdaptiveNavShell.mobileBottomBarHeight, a fixed 64 — a
    // constant other chrome (the mini player) positions itself above via
    // mobileBottomBarInset. Left unclamped, a large accessibility text size
    // grows the label past what that fixed height has room for and this
    // Column overflows it (#69). Icon + label still grow together, just
    // capped short of that point.
    final labelScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return InkWell(
      onTap: () => HubController.instance.setCurrentSection(section.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.icon, color: color, size: 21),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              section.localizedLabel(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: labelScaler,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
