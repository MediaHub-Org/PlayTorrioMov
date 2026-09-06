import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'sidebar_logo.dart';

/// The slim global top bar shown above the hub's content, on every tier --
/// mobile included, as of the fix described below. Holds the PlayTorrio
/// logo and a Settings button. The section switcher for the hub's sections
/// renders below it, in [AdaptiveNavShell] — see [SectionTopBar].
///
/// Mobile and tablet/desktop used to be two separate widgets with
/// independently-picked heights, padding, and button sizing, which drifted
/// the Settings icon a few px between tiers despite looking almost the
/// same. Rather than keep two copies in sync by hand, there is now exactly
/// one definition, built mobile-first (a `Row` with the logo in a
/// `Flexible` so it can actually shrink/ellipsize under a real phone
/// width, `Spacer()`, then the button) and reused unchanged on every tier
/// — not just visually matched, but the same widget, so it cannot drift
/// again. The previous tablet/desktop version used `Stack` + `Align`
/// instead, which doesn't bound the logo's width at all; that happened to
/// be safe as long as desktop always had room to spare, but was never a
/// definition mobile could have reused.
class TopBar extends StatelessWidget {
  /// The height available to the bar. Callers should inset their content by
  /// this amount so nothing sits beneath the bar.
  final double height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  static const double sharedHeight = 56;

  const TopBar({super.key, this.height = sharedHeight, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D15),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      // spaceBetween, not a Spacer() alongside Flexible: both default to
      // flex 1, so a Spacer sibling splits the remaining width evenly with
      // the logo's Flexible allocation instead of yielding it all -- since
      // Flexible only shrinks to content (FlexFit.loose) and Flutter's Flex
      // layout doesn't reclaim an undersized flex child's unused
      // allocation for its sibling, that leftover became a growing gap
      // between the logo and the button as the bar got wider. spaceBetween
      // has no such competition: the Flexible logo (alone, no competing
      // flex sibling) shrinks to its own content, and spaceBetween pushes
      // whatever's actually left to the far right.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(child: SidebarLogo()),
          if (onSettingsTap != null) SettingsIconButton(onTap: onSettingsTap!),
        ],
      ),
    );
  }
}

/// The Settings (gear) button, identical wherever it appears -- currently
/// [TopBar] (tablet/desktop) and [AdaptiveNavShell]'s mobile top bar -- so
/// its exact size and icon inset never drift between them.
class SettingsIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const SettingsIconButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Settings',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        foregroundColor: Colors.white70,
      ),
      icon: const Icon(Icons.settings_rounded, size: 20),
    );
  }
}
