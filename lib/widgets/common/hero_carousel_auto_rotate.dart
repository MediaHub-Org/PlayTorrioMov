import 'dart:async';

import 'package:flutter/material.dart';

/// The `PageController` + auto-rotate `Timer` plumbing shared by every hero
/// carousel in the app (Anime, IPTV, ...): advances to the next page on an
/// interval, pausing while [isHoveringCarousel] is true, and exposes
/// [goToHeroPage] for dot indicators / arrow buttons.
///
/// Everything that actually varies between carousels -- rotation interval,
/// animation curve/duration, height formula, arrow button styling, when to
/// show desktop arrows -- stays with the caller. This only centralizes the
/// timer bookkeeping, not the visual design.
mixin HeroCarouselAutoRotate<T extends StatefulWidget> on State<T> {
  final PageController heroPageController = PageController();
  Timer? _autoRotateTimer;
  bool isHoveringCarousel = false;
  int currentHeroIndex = 0;

  /// Starts (or restarts) the auto-rotate timer. Call from `initState` and
  /// again if [itemCount] changes. No-ops with fewer than 2 items.
  void startHeroAutoRotate({
    required int itemCount,
    required Duration interval,
    Duration transitionDuration = const Duration(milliseconds: 700),
    Curve transitionCurve = Curves.easeOutCubic,
  }) {
    _autoRotateTimer?.cancel();
    if (itemCount < 2) return;
    _autoRotateTimer = Timer.periodic(interval, (_) {
      if (!mounted || !heroPageController.hasClients || isHoveringCarousel) {
        return;
      }
      final next = (currentHeroIndex + 1) % itemCount;
      heroPageController.animateToPage(
        next,
        duration: transitionDuration,
        curve: transitionCurve,
      );
    });
  }

  /// Stops the auto-rotate timer without disposing the controller. Call
  /// this when a caller-side setting turns auto-rotate off at runtime.
  void stopHeroAutoRotate() {
    _autoRotateTimer?.cancel();
  }

  void goToHeroPage(
    int index, {
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!heroPageController.hasClients) return;
    heroPageController.animateToPage(index, duration: duration, curve: curve);
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    heroPageController.dispose();
    super.dispose();
  }
}
