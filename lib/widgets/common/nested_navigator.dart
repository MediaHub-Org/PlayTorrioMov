import 'package:flutter/material.dart';

/// Wraps a hub's content area in its own nested [Navigator] so that detail
/// pages pushed from within the hub (movies, artists, albums, etc.) render
/// inside the content box — keeping the left sidebar and top header visible —
/// instead of taking over the full screen.
///
/// Only routes that explicitly use the root navigator (e.g. the fullscreen
/// player) escape this scope.
class NestedNavigator extends StatefulWidget {
  final Widget child;

  /// Optional external key so a parent (e.g. [HubPage]) can pop this
  /// navigator back to its root -- used to clear a pushed detail page when
  /// the hub pills or bottom bar switch section out from under it.
  final GlobalKey<NavigatorState>? navigatorKey;

  const NestedNavigator({super.key, this.navigatorKey, required this.child});

  @override
  State<NestedNavigator> createState() => _NestedNavigatorState();
}

class _NestedNavigatorState extends State<NestedNavigator> {
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // A plain Navigator never sees the Android system back button -- that
    // goes to the app's root Navigator, which has nothing to pop while a
    // page pushed in here is on top, so back would exit the app instead of
    // popping the pushed page. NavigatorPopHandler is Flutter's own fix for
    // this exact nested-Navigator case.
    return NavigatorPopHandler<void>(
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        onGenerateInitialRoutes: (navigator, initialRoute) {
          return [MaterialPageRoute(builder: (_) => widget.child)];
        },
      ),
    );
  }
}
