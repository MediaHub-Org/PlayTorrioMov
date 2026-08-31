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

  const TopBar({super.key, this.height = 60, this.onSettingsTap});

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
              child: _settingsButton(onTap: onSettingsTap!),
            ),
        ],
      ),
    );
  }

  Widget _settingsButton({required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        foregroundColor: Colors.white70,
      ),
      icon: const Icon(Icons.settings_rounded, size: 20),
    );
  }
}
