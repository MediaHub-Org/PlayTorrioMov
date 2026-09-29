import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// 8pt-grid spacing scale shared across the app's chrome. Replaces magic
/// numbers (12, 16, ...) repeated per widget.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// A page's left/right gutter, mobile first: the phone value is the base
  /// and wider tiers step up from it, rather than a desktop number being
  /// squeezed down.
  ///
  /// One number for everything that has to line up along a page's edge --
  /// the filter pill bar, the floating back button, a header row's leading
  /// control. Each of those used to carry its own (8, 16, 20, 24, 28, 48),
  /// so the same control sat in a different place depending on which page
  /// you reached it from.
  static double pageInset(BuildContext context) =>
      pageInsetForWidth(MediaQuery.sizeOf(context).width);

  /// [pageInset] from a raw width, for the sizing values computed off a
  /// measured width rather than a context (see `MovieCardSizing`).
  static double pageInsetForWidth(double width) {
    switch (AppBreakpoints.tierForWidth(width)) {
      case ScreenTier.mobile:
        return 16;
      case ScreenTier.tablet:
        return 20;
      case ScreenTier.desktop:
        return 24;
    }
  }

  /// Vertical offset for a control floating over a full-bleed hero, always
  /// clearing the status bar. Anime Details used a flat 24, which put its
  /// back button under the system clock on a phone with a notch.
  static double floatingTopInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + sm;

  /// [base] logical pixels of text-bearing height, grown with the text scale
  /// (unchanged at 1x). For the boxes that cannot be a `minHeight` floor:
  /// a horizontal `ListView` needs a bounded height, so a chip or card rail
  /// gets its size from here instead of a bare constant that clips at 2x-3x.
  static double textScaledHeight(BuildContext context, double base) =>
      MediaQuery.textScalerOf(context).scale(base);

  /// A poster/portrait card's width, as a fraction of [screenWidth] instead
  /// of a table of fixed pixel values that jump between breakpoints (#80).
  /// Real-device testing found the old step tables -- six branches in
  /// `MovieCardSizing`, four in `IptvCardSizing` -- landed on the same flat
  /// pixel value for every window from 1400px up, desktop browser and TV
  /// alike, which read as oversized on a TV nobody had checked this against
  /// before. [min]/[max] still bound the result: below [min] a poster stops
  /// being legible, and without [max] it would keep growing on an
  /// arbitrarily wide window instead of leveling off the way the old tables
  /// did on purpose.
  static double cardWidthForScreenWidth(
    double screenWidth, {
    required double min,
    required double max,
    double factor = 0.12,
  }) =>
      (screenWidth * factor).clamp(min, max);
}

/// Corner-radius scale matching the values already in use across the
/// app's cards and panels.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}
