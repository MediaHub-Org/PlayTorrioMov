import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common/nested_navigator.dart';
import '../../widgets/common/universal_play_bar.dart';
import '../../utils/hub_controller.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
import '../settings/settings_page.dart';
import 'media_hub.dart';

/// HubPage: the top-level container hosting the app's single Media hub
/// (Movies & Series, Anime, Live TV, Library).
class HubPage extends StatefulWidget {
  const HubPage({super.key});

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  final FocusNode _focusNode = FocusNode();

  // Bumped after Settings closes to force the hub to remount and pick up any
  // addon changes made there — mirrors the old multi-hub cache invalidation,
  // just for the one hub that's left.
  int _rebuildKey = 0;

  // Lets a pushed Details page get popped back to root when the hub pills or
  // bottom bar switch section out from under it -- otherwise HubController's
  // state changes correctly but the Details page stays on top, covering the
  // switch (see NestedNavigator.navigatorKey).
  final _navKey = GlobalKey<NavigatorState>();
  String? _lastMediaSection;
  String? _lastWatchType;

  void _onHubControllerChanged() {
    final section = HubController.instance.mediaSection;
    final watchType = HubController.instance.watchType;
    if (section == _lastMediaSection && watchType == _lastWatchType) return;
    _lastMediaSection = section;
    _lastWatchType = watchType;
    _navKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    _lastMediaSection = HubController.instance.mediaSection;
    _lastWatchType = HubController.instance.watchType;
    HubController.instance.addListener(_onHubControllerChanged);
  }

  @override
  void dispose() {
    HubController.instance.removeListener(_onHubControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  /// TV remote Back/Exit support: Escape pops the current route.
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Only pop if there is actually a route to pop. On the root HubPage
      // there is nothing beneath it, so popping would leave a black screen.
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        body: Stack(
          children: [
            // Nav chrome + content: TopBar on tablet/desktop, a collapsed
            // top bar + bottom tab bar on mobile. See AdaptiveNavShell.
            Positioned.fill(
              child: AdaptiveNavShell(
                onSettingsTap: () async {
                  await Navigator.push(
                    context,
                    LiquidRevealRoute(
                      page: const SettingsPage(),
                      tapPosition: null,
                    ),
                  );
                  // Addons may have changed in Settings — remount the hub so
                  // it rebuilds and refetches on next show.
                  if (mounted) {
                    setState(() => _rebuildKey++);
                  }
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                  ),
                  child: NestedNavigator(
                    key: ValueKey(_rebuildKey),
                    navigatorKey: _navKey,
                    child: const MediaHub(),
                  ),
                ),
              ),
            ),
            // Universal Play Bar. On desktop/tablet it sits 16px above the
            // bottom; on mobile it clears AdaptiveNavShell's bottom tab bar.
            Positioned(
              bottom: tier == ScreenTier.mobile
                  ? AdaptiveNavShell.mobileBottomBarInset(context) + 12
                  : 16,
              left: 12,
              right: 12,
              // UniversalPlayBar hides itself when nothing is playing.
              child: const UniversalPlayBar(),
            ),
          ],
        ),
      ),
    );
  }
}
