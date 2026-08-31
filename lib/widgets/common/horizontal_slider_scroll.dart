import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Scroll-state logic shared by every horizontal card slider with desktop
/// arrow buttons (Movies, IPTV channels, ...): tracks whether the arrows
/// should show, and drives the "scroll by 80% of the viewport" animation.
///
/// Mix into a `State` and use [sliderScrollController] as the `ScrollController`
/// for the slider's `ListView`, [canScrollLeft]/[canScrollRight] to show/hide
/// the arrows, and [scrollSlider] for the arrows' `onTap`.
mixin HorizontalSliderScroll<T extends StatefulWidget> on State<T> {
  final ScrollController sliderScrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = true;

  @override
  void initState() {
    super.initState();
    sliderScrollController.addListener(_updateScrollButtons);
    // Defer the initial check until after first frame so maxScrollExtent is
    // calculated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    sliderScrollController.removeListener(_updateScrollButtons);
    sliderScrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!sliderScrollController.hasClients) return;
    final canLeft = sliderScrollController.position.pixels > 10;
    final canRight = sliderScrollController.position.pixels <
        sliderScrollController.position.maxScrollExtent - 10;
    if (canLeft != canScrollLeft || canRight != canScrollRight) {
      setState(() {
        canScrollLeft = canLeft;
        canScrollRight = canRight;
      });
    }
  }

  void scrollSlider(double directionMultiplier) {
    if (!sliderScrollController.hasClients) return;
    final viewportWidth = sliderScrollController.position.viewportDimension;
    // Scroll by 80% of the viewport width to leave some context.
    final scrollAmount = viewportWidth * 0.8 * directionMultiplier;
    final target = (sliderScrollController.position.pixels + scrollAmount)
        .clamp(0.0, sliderScrollController.position.maxScrollExtent);
    sliderScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  bool isDesktopPlatform() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }
}
