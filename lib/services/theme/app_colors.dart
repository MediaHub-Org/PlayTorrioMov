import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme_service.dart';

/// The app's semantic colours, resolved against whichever theme is active.
///
/// ## Why these are top-level and not `Theme.of(context)`
///
/// The app was written dark-only: roughly a thousand `Colors.white` literals
/// for text and a hundred hardcoded surface hexes, spread across sixty-odd
/// files, many of them inside helper methods that never took a
/// `BuildContext` and inside `const` widget trees. Threading a context to
/// every one of those is a far larger and riskier change than reading the
/// one global the app already has.
///
/// It is also honest about what this app is: there is exactly one theme at
/// a time. `AppThemeService.themeMode` is a global `ValueNotifier` that
/// `MaterialApp` already listens to, so the whole tree rebuilds when it
/// changes, and `platformBrightness` changes rebuild it too. A per-subtree
/// theme override would not work through these -- and the one place that
/// wants a different brightness from the rest of the app, the video player,
/// gets it by *not* using these at all. Player chrome sits over video and
/// stays dark whatever the app is set to, which is what every other video
/// app does.
///
/// If a per-subtree override is ever needed, this becomes an
/// `InheritedWidget` and the call sites gain a context. Until then this is
/// the smaller thing that works.
///
/// ## When a white is not ink
///
/// Not every `Colors.white` in the old code meant "primary text". A white
/// on a red pill, on the accent fill of an `ElevatedButton`, or over a
/// poster is white because of what is *behind* it, and what is behind it
/// does not change with the theme. Those are [onAccent], not [ink] --
/// making them [ink] paints them near-black over an unchanged dark
/// background, which is exactly as unreadable as it sounds.
///
/// Two whole surfaces are excluded for the same reason, rather than
/// token by token: the video player (chrome over video) and the three
/// details pages (a full-height backdrop image behind every control).
/// Both stay dark in either theme and so keep their literals.
abstract final class AppColors {
  /// Whether the app is currently painting light.
  ///
  /// `ThemeMode.system` defers to the platform, which is readable without a
  /// context and which `MaterialApp` rebuilds on.
  static bool get isLight {
    final mode = AppThemeService.themeMode.value;
    if (mode == ThemeMode.light) return true;
    if (mode == ThemeMode.dark) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.light;
  }

  // ── Ink: text and iconography ──────────────────────────────────────────
  //
  // The dark values are exactly what the literals they replace were, so a
  // dark build is unchanged pixel for pixel. The light values are a near
  // black rather than pure black, which is easier to read at small sizes
  // and is what Material's own onSurface does.

  /// Primary text. Was `Colors.white`.
  static Color get ink =>
      isLight ? const Color(0xFF0F1115) : const Color(0xFFFFFFFF);

  /// Secondary text. Was `Colors.white70`.
  static Color get inkMuted => ink.withValues(alpha: 0.70);

  /// Tertiary text, captions, metadata. Was `Colors.white54`.
  static Color get inkSubtle => ink.withValues(alpha: 0.54);

  /// Disabled text and inactive icons. Was `Colors.white38`.
  static Color get inkDisabled => ink.withValues(alpha: 0.38);

  /// Hairlines and dividers. Was `Colors.white24`.
  static Color get inkFaint => ink.withValues(alpha: 0.24);

  /// Ink at an arbitrary opacity, for the many
  /// `Colors.white.withValues(alpha: x)` sites.
  static Color inkAlpha(double alpha) => ink.withValues(alpha: alpha);

  // ── Surfaces ───────────────────────────────────────────────────────────
  //
  // Light surfaces come from the active palette so the eight themes stay
  // distinguishable in light mode, the same way they are in dark.

  /// The page behind everything. Was `Color(0xFF080A0F)`.
  static Color get canvas => _surface(AppThemeSurface.scaffold);

  /// Cards, sheets, list tiles. Was `Color(0xFF12151E)`.
  static Color get surface => _surface(AppThemeSurface.card);

  /// App bars and the nav chrome. Was `Color(0xFF0D1017)`.
  static Color get bar => _surface(AppThemeSurface.appBar);

  /// A surface one step above [surface] -- menus, dialogs, popovers over a
  /// card. Was `Color(0xFF151822)`.
  static Color get raised => isLight
      ? Color.alphaBlend(ink.withValues(alpha: 0.04), surface)
      : const Color(0xFF151822);

  /// A hairline border on a surface. Was `Colors.white.withValues(alpha:
  /// 0.08)`, the single most common border in the app.
  static Color get edge => inkAlpha(0.08);

  /// A slightly stronger border, for a focused or selected surface.
  static Color get edgeStrong => inkAlpha(0.15);

  /// A tint laid over a surface to mark hover or selection. Was
  /// `Colors.white.withValues(alpha: 0.06)`.
  static Color get fill => inkAlpha(0.06);

  static Color _surface(AppThemeSurface which) => AppThemeService.surfaceFor(
    AppThemeService.currentPalette.value,
    isLight ? Brightness.light : Brightness.dark,
    surface: which,
  );

  // ── Fixed colours ──────────────────────────────────────────────────────

  /// Text and icons that sit on the accent colour, or over artwork. Always
  /// white, in both themes, because what is behind it does not change with
  /// the theme -- a poster is a poster.
  static const Color onAccent = Color(0xFFFFFFFF);

  /// The scrim over artwork behind hero text. Always dark for the same
  /// reason.
  static const Color scrim = Color(0xCC000000);
}
