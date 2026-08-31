import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import '../../utils/app_hub.dart';
import '../../utils/hub_controller.dart';
import 'sidebar_logo.dart';

/// The slim global top bar shown above every hub.
///
/// Holds the PlayTorrio logo (so the icon stays visible), the
/// Watch / Listen / Read hub switcher, and a Settings button. The per-hub
/// sidebar below it shows only the sections of the current hub, and replaces
/// its own logo/switcher with the name of the currently selected section.
class TopBar extends StatelessWidget {
  /// The height available to the bar. Callers should inset their content by
  /// this amount so nothing sits beneath the bar.
  final double height;

  /// Invoked when the settings (gear) button is tapped.
  final VoidCallback? onSettingsTap;

  const TopBar({super.key, this.height = 60, this.onSettingsTap});

  static const _hubOrder = [AppHub.media, AppHub.music, AppHub.books];

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
          Center(
            child: ListenableBuilder(
              listenable: HubController.instance,
              builder: (context, _) {
                final current = HubController.instance.currentHub;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final hub in _hubOrder) _hubTab(context, hub, current),
                  ],
                );
              },
            ),
          ),
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

  /// A top-level "you are here" tab: label + icon with an animated underline,
  /// no fill or border — sits visually above the section chip bar beneath it.
  Widget _hubTab(
    BuildContext context,
    AppHub hub,
    AppHub current,
  ) {
    final selected = current == hub;
    final color = selected ? Colors.white : Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: InkWell(
        onTap: () => HubController.instance.setHub(hub),
        borderRadius: BorderRadius.circular(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(hub.navIcon, color: color, size: 17),
                const SizedBox(width: 6),
                Text(
                  hub.navLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 2,
              width: selected ? 22 : 0,
              decoration: const BoxDecoration(
                color: Color(0xFF7C5CFF),
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}