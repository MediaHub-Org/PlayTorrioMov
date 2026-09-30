import 'package:flutter/widgets.dart';

/// The app's size unit: one `rem` is 16 logical pixels at the default text
/// size, and grows or shrinks with the user's text size -- the system's and
/// the in-app zoom together, which is what `MediaQuery.textScalerOf` already
/// holds -- exactly as a CSS `rem` follows the browser's root font size.
///
/// Why this exists: the codebase measured layout in bare numbers
/// (`SizedBox(width: 12)`, `height: 40`), so a larger text size grew the text
/// and left every gap, bar and button where it was. A size written as
/// `context.rem(AppRem.md)` moves with the text instead, and a change of
/// spacing is made in one place.
///
/// Text itself is NOT run through [RemContext.rem]. Flutter already multiplies
/// a `fontSize` by the text scaler when it paints, so scaling it here too
/// would apply the setting twice. Font sizes come from [AppType], which are
/// plain constants.
///
/// The factor is clamped to the range the layouts were probed to hold (#69,
/// see `AppThemeService.minTextScale`/`maxTextScale` and `ClampedTextScale`):
/// system text at 3x should grow the text, not triple every margin on a screen
/// that cannot take it.
abstract final class AppUnits {
  /// Logical pixels in one rem at the default text size.
  static const double remPixels = 16;

  static const double minScale = 0.85;
  static const double maxScale = 1.3;

  /// The current text-size factor, within [minScale]..[maxScale].
  static double scaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(minScale, maxScale);
}

extension RemContext on BuildContext {
  /// [units] rem as logical pixels for this context's text size.
  double rem(double units) =>
      units * AppUnits.remPixels * AppUnits.scaleOf(this);
}

/// Named sizes, in rem. Use these instead of a number: `context.rem(AppRem.md)`.
///
/// The steps match [AppSpacing]'s pixel scale at the default text size
/// (`xs` 4, `sm` 8, `md` 16, `lg` 24, `xl` 32), so a screen moved from one to
/// the other does not change at 1x.
abstract final class AppRem {
  // Space.
  static const double xxs = 0.125;
  static const double xs = 0.25;
  static const double snug = 0.375;
  static const double sm = 0.5;
  static const double ms = 0.75;
  static const double md = 1;
  static const double lg = 1.5;
  static const double xl = 2;

  // Corner radii.
  static const double radiusSm = 0.5;
  static const double radiusPill = 0.625;
  static const double radiusMd = 0.75;
  static const double radiusLg = 1;

  // Icons.
  static const double iconXs = 1;
  static const double iconSm = 1.125;
  static const double icon = 1.25;
  static const double iconLg = 1.5;

  // A tap target: the smallest square a finger or a remote's focus ring should
  // be asked to hit.
  static const double target = 2.5;

  // The slim bar across the top of the hub.
  static const double bar = 3.5;

  // Shadow blur.
  static const double blurSm = 0.625;
  static const double blur = 0.75;

  // The TV side menu's width bounds, which the window width sits between.
  static const double menuMin = 9.25;
  static const double menuMax = 13.75;

  // Control padding: a button's or a tile's inner space.
  static const double controlX = 1.5;
  static const double controlY = 0.875;
  static const double controlXCompact = 1;
  static const double controlYCompact = 0.625;
}

/// Font sizes, as plain constants -- see [AppUnits] for why these are not in
/// rem. The text scaler applies the user's setting when the text is painted.
abstract final class AppType {
  static const double caption = 12;
  static const double small = 13;
  static const double body = 14;
  static const double bodyLg = 16;
  static const double title = 21;
}
