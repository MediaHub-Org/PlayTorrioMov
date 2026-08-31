import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_hub.dart';
import '../../widgets/common/nested_navigator.dart';
import '../../widgets/common/universal_play_bar.dart';
import '../../utils/hub_controller.dart';
import '../../utils/hub_navigator.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
import '../settings/settings_page.dart';
import 'media_hub.dart';
import 'books_hub.dart';
import 'music_hub.dart';

/// HubPage: the top-level container hosting all primary app hubs
/// (Media, Books, Music) in an IndexedStack. Each hub owns its own sidebar
/// (hub switcher, sections, search, settings) — there's no shared header.
class HubPage extends StatefulWidget {
  const HubPage({super.key});

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  final FocusNode _focusNode = FocusNode();

  // Each hub is lazily wrapped in its own nested Navigator the first time it's
  // shown, so offstage hubs are not laid out at startup (which can crash pages
  // that assume a non-zero width, and stalls first paint with eager network).
  static const List<Widget Function()> _hubBuilders = [
    _buildMediaHub,
    _buildBooksHub,
    _buildMusicHub,
  ];
  final List<Widget?> _built = List<Widget?>.filled(3, null);

  static Widget _buildMediaHub() => const NestedNavigator(child: MediaHub());
  static Widget _buildBooksHub() => const NestedNavigator(child: BooksHub());
  static Widget _buildMusicHub() => const NestedNavigator(child: MusicHub());

  void _setHub(AppHub hub) {
    HubController.instance.setHub(hub);
  }

  @override
  void initState() {
    super.initState();

    // Allow child hub pages to navigate back to the primary media hub.
    HubNavigator.registerGoHome(() => _setHub(AppHub.media));
  }

  @override
  void dispose() {
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
                  // Addons may have changed in Settings — drop the cached
                  // hubs so each rebuilds and refetches on next show.
                  if (mounted) {
                    setState(() => _built.fillRange(0, _built.length, null));
                  }
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.lg),
                  ),
                  child: ListenableBuilder(
                    listenable: HubController.instance,
                    builder: (context, _) {
                      final index = HubController.instance.currentHub.index;
                      // Lazily materialize the active hub on first show.
                      if (_built[index] == null) {
                        _built[index] = _hubBuilders[index]();
                      }
                      return IndexedStack(
                        index: index,
                        children: [
                          _built[0] ?? const SizedBox.shrink(),
                          _built[1] ?? const SizedBox.shrink(),
                          _built[2] ?? const SizedBox.shrink(),
                        ],
                      );
                    },
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
                // UniversalPlayBar hides itself when nothing is playing, so
                // it stays visible across every hub, not just Listen.
                child: const UniversalPlayBar(),
              ),
          ],
        ),
      ),
    );
  }

}
