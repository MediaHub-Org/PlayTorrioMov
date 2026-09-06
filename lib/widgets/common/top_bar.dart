import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'sidebar_logo.dart';

/// The slim global top bar shown above the hub's content.
///
/// Holds the PlayTorrio logo and a Settings button. The section switcher for
/// the hub's four sections renders below it, in the content area — see
/// [SectionTopBar].
class TopBar extends StatelessWidget {
  /// The height available to the bar. Callers should inset their content by
  /// this amount so nothing sits beneath the bar.
  final double height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  /// Shared with [AdaptiveNavShell]'s mobile top bar so the header itself is
  /// the same height on every tier -- the Settings button previously sat at
  /// a slightly different vertical position on mobile vs. desktop purely
  /// because the two bars picked different heights independently.
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(alignment: Alignment.centerLeft, child: SidebarLogo()),
          if (onSettingsTap != null)
            Align(
              alignment: Alignment.centerRight,
              child: SettingsIconButton(onTap: onSettingsTap!),
            ),
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
