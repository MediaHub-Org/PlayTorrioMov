import 'package:flutter/widgets.dart';

/// The three responsive tiers used by nav chrome across the app.
enum ScreenTier { mobile, tablet, desktop }

/// Single source of truth for the width cutoffs used to pick [ScreenTier].
/// Replaces the ad-hoc `MediaQuery.sizeOf(context).width >= 900`-style
/// checks scattered across the app.
abstract final class AppBreakpoints {
  /// Below this width is [ScreenTier.mobile].
  static const double tablet = 600;

  /// At/above this width is [ScreenTier.desktop]. Between [tablet] and
  /// this is [ScreenTier.tablet].
  static const double desktop = 900;

  /// Pure width-to-tier mapping, kept separate from [of] so it's directly
  /// unit-testable without pumping a widget tree.
  static ScreenTier tierForWidth(double width) {
    if (width >= desktop) return ScreenTier.desktop;
    if (width >= tablet) return ScreenTier.tablet;
    return ScreenTier.mobile;
  }

  static ScreenTier of(BuildContext context) =>
      tierForWidth(MediaQuery.sizeOf(context).width);
}
