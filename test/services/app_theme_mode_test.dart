import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppThemeService.themeMode.value = ThemeMode.system;
  });

  group('theme mode', () {
    test('a fresh install follows the system', () async {
      // The app has no business overriding a preference the user already
      // expressed to their OS.
      await AppThemeService.initialize();
      expect(AppThemeService.themeMode.value, ThemeMode.system);
    });

    test('a choice survives a restart', () async {
      await AppThemeService.setThemeMode(ThemeMode.light);

      AppThemeService.themeMode.value = ThemeMode.system;
      await AppThemeService.initialize();

      expect(AppThemeService.themeMode.value, ThemeMode.light);
    });

    test('it is stored by name, not by enum index', () {
      // Reordering ThemeMode upstream would silently flip everyone's saved
      // choice if this were an index.
      expect(AppThemeService.encodeMode(ThemeMode.system), 'system');
      expect(AppThemeService.encodeMode(ThemeMode.light), 'light');
      expect(AppThemeService.encodeMode(ThemeMode.dark), 'dark');
    });

    test('an unreadable stored value falls back to system', () {
      expect(AppThemeService.decodeMode(null), ThemeMode.system);
      expect(AppThemeService.decodeMode(''), ThemeMode.system);
      expect(AppThemeService.decodeMode('sepia'), ThemeMode.system);
      expect(AppThemeService.decodeMode('2'), ThemeMode.system);
    });

    test('every mode round-trips', () {
      for (final mode in ThemeMode.values) {
        expect(
          AppThemeService.decodeMode(AppThemeService.encodeMode(mode)),
          mode,
        );
      }
    });

    test('setting the same mode twice notifies once', () async {
      var notifications = 0;
      void listener() => notifications++;
      AppThemeService.themeMode.addListener(listener);
      addTearDown(() => AppThemeService.themeMode.removeListener(listener));

      await AppThemeService.setThemeMode(ThemeMode.dark);
      await AppThemeService.setThemeMode(ThemeMode.dark);

      expect(notifications, 1);
    });
  });

  group('light and dark theme data', () {
    test('both brightnesses are buildable for every palette', () {
      // MaterialApp builds both and lets themeMode choose, so a palette
      // that only works in one is a crash waiting for a toggle.
      for (final palette in AppThemeService.palettes) {
        for (final brightness in Brightness.values) {
          final theme = AppThemeService.createThemeData(palette, brightness);
          expect(theme.brightness, brightness);
          expect(theme.colorScheme.brightness, brightness);
        }
      }
    });

    test('dark stays the exact palette that shipped', () {
      // The dark theme is what every existing user sees; deriving it would
      // have quietly restyled the whole app.
      for (final palette in AppThemeService.palettes) {
        final theme = AppThemeService.createThemeData(palette, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, palette.scaffoldBackgroundColor);
        expect(theme.cardTheme.color, palette.cardBackgroundColor);
        expect(
          theme.appBarTheme.backgroundColor,
          palette.appBarBackgroundColor,
        );
      }
    });

    test('dark is the default brightness, as it always was', () {
      final theme = AppThemeService.createThemeData(
        AppThemeService.palettes.first,
      );
      expect(theme.brightness, Brightness.dark);
    });

    test('light surfaces are actually light', () {
      for (final palette in AppThemeService.palettes) {
        for (final surface in AppThemeSurface.values) {
          final color = AppThemeService.surfaceFor(
            palette,
            Brightness.light,
            surface: surface,
          );
          expect(
            color.computeLuminance(),
            greaterThan(0.7),
            reason: '${palette.id} $surface is too dark for a light theme',
          );
        }
      }
    });

    test('dark surfaces are actually dark', () {
      for (final palette in AppThemeService.palettes) {
        for (final surface in AppThemeSurface.values) {
          final color = AppThemeService.surfaceFor(
            palette,
            Brightness.dark,
            surface: surface,
          );
          expect(color.computeLuminance(), lessThan(0.1));
        }
      }
    });

    test('a light card sits above its scaffold, not below it', () {
      // Cards have to read as raised. In dark that means lighter than the
      // background; in light it means the reverse would look sunken.
      for (final palette in AppThemeService.palettes) {
        final scaffold = AppThemeService.surfaceFor(
          palette,
          Brightness.light,
          surface: AppThemeSurface.scaffold,
        );
        final card = AppThemeService.surfaceFor(
          palette,
          Brightness.light,
          surface: AppThemeSurface.card,
        );
        expect(
          card.computeLuminance(),
          greaterThanOrEqualTo(scaffold.computeLuminance()),
          reason: '${palette.id}: a light card must not be darker than the page',
        );
      }
    });

    test('light surfaces are tinted, not one shared grey', () {
      // The whole reason the app has eight palettes is that they look
      // different. Deriving light surfaces from the primary keeps that;
      // a fixed off-white would have collapsed all eight into one.
      Color scaffoldOf(AppThemePalette palette) => AppThemeService.surfaceFor(
        palette,
        Brightness.light,
        surface: AppThemeSurface.scaffold,
      );

      final scaffolds = AppThemeService.palettes.map(scaffoldOf).toSet();
      expect(
        scaffolds.length,
        AppThemeService.palettes.length,
        reason: 'two palettes produced the same light background',
      );

      // And the tint leans the right way: a green palette's page is
      // greener than it is red. Asserted as a channel comparison rather
      // than a hue, because at this lightness 8-bit rounding moves the
      // recovered hue by several degrees -- that would be a test of
      // quantisation, not of the design.
      final emerald = scaffoldOf(
        AppThemeService.palettes.firstWhere((p) => p.id == 'emerald'),
      );
      expect(emerald.g, greaterThan(emerald.r));

      final vampire = scaffoldOf(
        AppThemeService.palettes.firstWhere((p) => p.id == 'vampire'),
      );
      expect(vampire.r, greaterThan(vampire.g));
    });
  });
}
