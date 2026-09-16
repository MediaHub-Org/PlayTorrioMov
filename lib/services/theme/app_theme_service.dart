import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemePalette {
  final String id;
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color scaffoldBackgroundColor;
  final Color cardBackgroundColor;
  final Color appBarBackgroundColor;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    this.scaffoldBackgroundColor = const Color(0xFF080A0F),
    this.cardBackgroundColor = const Color(0xFF12151E),
    this.appBarBackgroundColor = const Color(0xFF0D1017),
  });
}

abstract final class AppThemeService {
  static const _storageKey = 'app_theme_id';
  static const _modeStorageKey = 'app_theme_mode';
  static const _textScaleStorageKey = 'app_text_scale';

  /// The in-app text zoom's allowed range (#69).
  ///
  /// Capped at 1.3x on purpose, not left open-ended: that is the same
  /// ceiling the high-traffic chrome this control actually reaches
  /// (AdaptiveNavShell's bottom tab bar, SidebarLogo's wordmark,
  /// PillTabRow, and the details page credit cards) was individually
  /// audited and clamped to, so this slider can never ask them to render
  /// past what has actually been verified not to overflow. The rest of the
  /// app was not exhaustively audited at this range -- see #69 in
  /// docs/ROADMAP.md -- so this stays the ceiling until more of it has.
  /// System-level accessibility text scale is unrelated and uncapped, as
  /// it already was before this setting existed.
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;

  static const List<AppThemePalette> palettes = [
    AppThemePalette(
      id: 'amethyst',
      name: 'Amethyst Violet',
      primaryColor: Color(0xFF7C5CFF),
      accentColor: Color(0xFF00E5FF),
      scaffoldBackgroundColor: Color(0xFF080A0F),
      cardBackgroundColor: Color(0xFF12151E),
      appBarBackgroundColor: Color(0xFF0D1017),
    ),
    AppThemePalette(
      id: 'cyberpunk',
      name: 'Cyberpunk Neon',
      primaryColor: Color(0xFFFF2A85),
      accentColor: Color(0xFF00F0FF),
      scaffoldBackgroundColor: Color(0xFF0C0812),
      cardBackgroundColor: Color(0xFF160E1E),
      appBarBackgroundColor: Color(0xFF100A17),
    ),
    AppThemePalette(
      id: 'emerald',
      name: 'Emerald Aurora',
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF34D399),
      scaffoldBackgroundColor: Color(0xFF060F0B),
      cardBackgroundColor: Color(0xFF0E1A14),
      appBarBackgroundColor: Color(0xFF09140F),
    ),
    AppThemePalette(
      id: 'sunset',
      name: 'Sunset Crimson',
      primaryColor: Color(0xFFFF3366),
      accentColor: Color(0xFFFF9900),
      scaffoldBackgroundColor: Color(0xFF0F080B),
      cardBackgroundColor: Color(0xFF1A0E13),
      appBarBackgroundColor: Color(0xFF130A0E),
    ),
    AppThemePalette(
      id: 'sapphire',
      name: 'Midnight Sapphire',
      primaryColor: Color(0xFF3B82F6),
      accentColor: Color(0xFF60A5FA),
      scaffoldBackgroundColor: Color(0xFF060B14),
      cardBackgroundColor: Color(0xFF0E1726),
      appBarBackgroundColor: Color(0xFF09101C),
    ),
    AppThemePalette(
      id: 'amber',
      name: 'Golden Amber',
      primaryColor: Color(0xFFF59E0B),
      accentColor: Color(0xFFFCD34D),
      scaffoldBackgroundColor: Color(0xFF0F0C06),
      cardBackgroundColor: Color(0xFF1A160E),
      appBarBackgroundColor: Color(0xFF141009),
    ),
    AppThemePalette(
      id: 'vampire',
      name: 'Vampire Red',
      primaryColor: Color(0xFFE50914),
      accentColor: Color(0xFFFF4D4D),
      scaffoldBackgroundColor: Color(0xFF0E0607),
      cardBackgroundColor: Color(0xFF1A0C0E),
      appBarBackgroundColor: Color(0xFF14080A),
    ),
    AppThemePalette(
      id: 'barbie',
      name: 'Pink Barbie',
      primaryColor: Color(0xFFFF1493),
      accentColor: Color(0xFFFF80BF),
      scaffoldBackgroundColor: Color(0xFF14050E),
      cardBackgroundColor: Color(0xFF220A18),
      appBarBackgroundColor: Color(0xFF1A0713),
    ),
  ];

  static final ValueNotifier<AppThemePalette> currentPalette =
      ValueNotifier<AppThemePalette>(palettes[0]);

  /// Light, dark, or whatever the device is set to.
  ///
  /// [ThemeMode.system] is the default, and is the honest one: the app has
  /// no business overriding a preference the user already expressed to
  /// their OS. It only becomes an explicit light or dark once they pick
  /// one in Appearance & Interface.
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  /// In-app text zoom, on top of whatever the system's own accessibility
  /// text size already applies. 1.0 = off (the default): the app scales
  /// with the system size alone, same as before this setting existed.
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_storageKey);
    if (id != null) {
      final found = palettes.firstWhere(
        (p) => p.id == id,
        orElse: () => palettes[0],
      );
      currentPalette.value = found;
    }
    themeMode.value = decodeMode(prefs.getString(_modeStorageKey));
    final storedScale = prefs.getDouble(_textScaleStorageKey);
    if (storedScale != null) {
      textScale.value = storedScale.clamp(minTextScale, maxTextScale);
    }
  }

  static Future<void> setTextScale(double scale) async {
    final clamped = scale.clamp(minTextScale, maxTextScale);
    if (textScale.value == clamped) return;
    textScale.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleStorageKey, clamped);
  }

  static Future<void> setPalette(AppThemePalette palette) async {
    currentPalette.value = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, palette.id);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeStorageKey, encodeMode(mode));
  }

  /// Stored as a stable string rather than an enum index, so reordering
  /// ThemeMode upstream cannot silently flip everyone's saved choice.
  @visibleForTesting
  static String encodeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  /// Anything unrecognised -- including null, which is a fresh install --
  /// means follow the system.
  @visibleForTesting
  static ThemeMode decodeMode(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// The palette's surfaces for a given brightness.
  ///
  /// Light surfaces are derived rather than hand-written: each is the
  /// palette's own hue at low saturation and high lightness, so Emerald's
  /// light theme reads green-tinted and Sunset's warm, the same way their
  /// dark surfaces do. Hand-writing twenty-four more constants would have
  /// let them drift from the primary they are supposed to belong to.
  static Color surfaceFor(
    AppThemePalette palette,
    Brightness brightness, {
    required AppThemeSurface surface,
  }) {
    if (brightness == Brightness.dark) {
      return switch (surface) {
        AppThemeSurface.scaffold => palette.scaffoldBackgroundColor,
        AppThemeSurface.card => palette.cardBackgroundColor,
        AppThemeSurface.appBar => palette.appBarBackgroundColor,
      };
    }
    final hsl = HSLColor.fromColor(palette.primaryColor);
    final lightness = switch (surface) {
      AppThemeSurface.scaffold => 0.955,
      AppThemeSurface.card => 0.995,
      AppThemeSurface.appBar => 0.92,
    };
    // Saturation 0.45, not something subtler. At this lightness an 8-bit
    // channel is the limit: at 0.22 the tint rounded away and Cyberpunk,
    // Sunset and Pink Barbie all resolved to the same #F9F6F7, which would
    // have collapsed three palettes into one in light mode. 0.45 survives
    // the rounding and still reads as a white page, not a coloured one.
    return HSLColor.fromAHSL(1, hsl.hue, 0.45, lightness).toColor();
  }

  static ThemeData createThemeData(
    AppThemePalette palette, [
    Brightness brightness = Brightness.dark,
  ]) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: surfaceFor(
        palette,
        brightness,
        surface: AppThemeSurface.scaffold,
      ),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primaryColor,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceFor(
          palette,
          brightness,
          surface: AppThemeSurface.appBar,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceFor(palette, brightness, surface: AppThemeSurface.card),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// The three surfaces a palette paints. Public because [AppThemeService.surfaceFor]
/// takes one, and a private type in a public signature is both a lint and a
/// method nobody outside this library can call.
enum AppThemeSurface { scaffold, card, appBar }
