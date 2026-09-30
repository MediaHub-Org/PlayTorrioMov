import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common/nested_navigator.dart';
import '../../widgets/common/universal_play_bar.dart';
import '../../utils/hub_controller.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../widgets/common/adaptive_nav_shell.dart';
import '../iptv/iptv_search_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'media_hub.dart';
import '../../widgets/common/tv_focus_bridge.dart';
import '../../widgets/common/tv_side_menu.dart';
import '../../services/tv_mode_service.dart';
import '../../services/theme/app_colors.dart';

/// HubPage: the top-level container hosting the app's single Media hub
/// (Movies, Series, Anime, Live TV, Profile).
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

  // A fast double-click on the gear (easy to do with a mouse) fired this
  // handler twice before the first push's transition finished, stacking
  // two SettingsPage instances -- back had to be pressed twice to actually
  // leave. Guards against a second push while one is already in flight.
  bool _openingSettings = false;

  // Same double-push guard as Settings, for the same reason.
  bool _openingSearch = false;

  void _onHubControllerChanged() {
    final section = HubController.instance.mediaSection;
    if (section == _lastMediaSection) return;
    _lastMediaSection = section;
    _navKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    _lastMediaSection = HubController.instance.mediaSection;
    HubController.instance.addListener(_onHubControllerChanged);
  }

  @override
  void dispose() {
    HubController.instance.removeListener(_onHubControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    // Same root-navigator escape every back-button page uses (see pushPage)
    // -- covers the top bar and section chips instead of leaving them drawn
    // around Settings.
    await pushPage(context, const SettingsPage());
    _openingSettings = false;
    // Addons may have changed in Settings — remount the hub so it rebuilds
    // and refetches on next show.
    if (mounted) {
      setState(() => _rebuildKey++);
    }
  }

  Future<void> _openSearch() async {
    if (_openingSearch) return;
    _openingSearch = true;
    // Live TV searches a portal's stream list by keyword, not a title
    // catalog, so it keeps its own page -- same split each catalog page's own
    // search button used to make.
    await pushPage(
      context,
      HubController.instance.mediaSection == 'iptv'
          ? const IptvSearchPage()
          : const SearchPage(),
    );
    _openingSearch = false;
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
    AppColors.dependOn(context);
    final tier = AppBreakpoints.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            // Nav chrome + content: TopBar on tablet/desktop, a collapsed
            // top bar + bottom tab bar on mobile. See AdaptiveNavShell.
            Positioned.fill(
              // On a TV the top bar and the phone's bottom tab bar give way
              // to a side menu inside the content itself (see TvSideMenu for
              // why it has to be inside). Listened to, not read once: the
              // answer arrives from the platform channel and the first frame
              // may precede it.
              child: ValueListenableBuilder<bool>(
                valueListenable: TvModeService.isTv,
                builder: (context, isTv, _) => TvFocusBridge(
                  child: AdaptiveNavShell(
                    tvLayout: isTv,
                    onSettingsTap: _openSettings,
                    onSearchTap: _openSearch,
                    child: ClipRRect(
                      borderRadius: isTv
                          ? BorderRadius.zero
                          : const BorderRadius.only(
                              topLeft: Radius.circular(AppRadii.lg),
                            ),
                      child: NestedNavigator(
                        // The initial route is built once, so a change of
                        // layout needs a fresh navigator.
                        key: ValueKey('$_rebuildKey-$isTv'),
                        navigatorKey: _navKey,
                        child: isTv
                            ? TvHubFrame(
                                menu: TvSideMenu(
                                  onSearchTap: _openSearch,
                                  onSettingsTap: _openSettings,
                                ),
                                child: const MediaHub(),
                              )
                            : const MediaHub(),
                      ),
                    ),
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
