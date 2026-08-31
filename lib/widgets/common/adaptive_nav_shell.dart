import 'package:flutter/material.dart';

import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../utils/app_hub.dart';
import '../../utils/hub_controller.dart';
import 'sidebar_logo.dart';
import 'top_bar.dart';

/// Tier-aware nav chrome wrapping a hub's content area.
///
/// Desktop/tablet keep the existing [TopBar]: hub switcher centred, sections
/// as a chip row beneath it.
///
/// Mobile mirrors that hierarchy rather than inverting it. The bottom bar --
/// the easiest thing to reach on a phone -- carries the four sections of the
/// current hub, because that is what you switch between constantly. Hubs are
/// the rarer, coarser choice, so they sit in the header as icon-only pills;
/// three glyphs cost far less width than three labels, which is what makes
/// room for the wordmark beside them.
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
    final tier = AppBreakpoints.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    if (tier == ScreenTier.mobile) {
      return Column(
        children: [
          SizedBox(height: topPadding),
          _MobileTopBar(onSettingsTap: onSettingsTap),
          Expanded(child: child),
          const SafeArea(top: false, child: _MobileSectionTabBar()),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: topPadding),
        TopBar(onSettingsTap: onSettingsTap),
        Expanded(child: child),
      ],
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const _MobileTopBar({this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Flexible(child: SidebarLogo()),
          const SizedBox(width: AppSpacing.sm),
          const _MobileHubPills(),
          const Spacer(),
          if (onSettingsTap != null)
            IconButton(
              onPressed: onSettingsTap,
              tooltip: 'Settings',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MobileHubPills extends StatelessWidget {
  const _MobileHubPills();

  static const _hubs = [AppHub.media, AppHub.music, AppHub.books];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HubController.instance,
      builder: (context, _) {
        final current = HubController.instance.currentHub;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final hub in _hubs)
              _HubPill(hub: hub, selected: hub == current),
          ],
        );
      },
    );
  }
}

/// Icon-only so all three hubs plus the wordmark fit a narrow phone header.
/// The tooltip and semantics label carry the name for anyone who needs it.
class _HubPill extends StatelessWidget {
  final AppHub hub;
  final bool selected;

  const _HubPill({required this.hub, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: hub.navLabel,
        child: InkWell(
          onTap: () => HubController.instance.setHub(hub),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF7C5CFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              hub.navIcon,
              size: 18,
              color: selected ? Colors.white : Colors.white54,
              semanticLabel: hub.navLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// The four sections of the active hub, in the bottom bar where they are
/// easiest to reach. Every hub has exactly four, so the row divides evenly
/// and the tabs never change width between hubs.
class _MobileSectionTabBar extends StatelessWidget {
  const _MobileSectionTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('adaptiveNavMobileBar'),
      height: AdaptiveNavShell.mobileBottomBarHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D15),
        border: Border(top: BorderSide(color: Colors.white12)),
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
    final color = selected ? Colors.white : Colors.white54;
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
              section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
