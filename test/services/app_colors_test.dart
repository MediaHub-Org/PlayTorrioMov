import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_colors.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppThemeService.themeMode.value = ThemeMode.dark);
  tearDown(() => AppThemeService.themeMode.value = ThemeMode.system);

  group('AppColors in dark', () {
    test('ink is exactly the white it replaced', () {
      // Every migrated site used to read Colors.white. A dark build has to
      // be unchanged pixel for pixel, or the migration is a redesign.
      expect(AppColors.ink, const Color(0xFFFFFFFF));
    });

    test('the muted ramp matches the Colors.whiteNN it replaced', () {
      expect(AppColors.inkMuted.a, closeTo(0.70, 0.01));
      expect(AppColors.inkSubtle.a, closeTo(0.54, 0.01));
      expect(AppColors.inkDisabled.a, closeTo(0.38, 0.01));
      expect(AppColors.inkFaint.a, closeTo(0.24, 0.01));
    });

    test('surfaces are the palette values that shipped', () {
      final palette = AppThemeService.currentPalette.value;
      expect(AppColors.canvas, palette.scaffoldBackgroundColor);
      expect(AppColors.surface, palette.cardBackgroundColor);
      expect(AppColors.bar, palette.appBarBackgroundColor);
      expect(AppColors.raised, const Color(0xFF151822));
    });
  });

  group('AppColors in light', () {
    setUp(() => AppThemeService.themeMode.value = ThemeMode.light);

    test('ink inverts to a near-black, not pure black', () {
      // Pure black on white is harsher than Material's own onSurface at
      // small sizes, which is most of this app's text.
      expect(AppColors.ink.computeLuminance(), lessThan(0.05));
      expect(AppColors.ink, isNot(const Color(0xFF000000)));
    });

    test('surfaces invert to light', () {
      for (final c in [AppColors.canvas, AppColors.surface, AppColors.bar]) {
        expect(c.computeLuminance(), greaterThan(0.7));
      }
    });

    test('a raised surface still reads above the card under it', () {
      // In dark, raised is lighter than surface. In light it has to go the
      // other way or a menu looks like a hole.
      expect(
        AppColors.raised.computeLuminance(),
        lessThan(AppColors.surface.computeLuminance()),
      );
    });

    test('borders and fills stay subtle rather than becoming solid', () {
      expect(AppColors.edge.a, closeTo(0.08, 0.01));
      expect(AppColors.fill.a, closeTo(0.06, 0.01));
    });
  });

  group('theme-independent colours', () {
    test('onAccent and scrim do not move', () {
      // What sits behind them -- an accent fill, a poster -- does not change
      // with the theme, so neither do they. They are also const, which is
      // what lets const widget trees survive the migration.
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        AppThemeService.themeMode.value = mode;
        expect(AppColors.onAccent, const Color(0xFFFFFFFF));
        expect(AppColors.scrim, const Color(0xCC000000));
      }
    });
  });

  group('mode resolution', () {
    test('explicit light and dark win over the platform', () {
      AppThemeService.themeMode.value = ThemeMode.light;
      expect(AppColors.isLight, isTrue);
      AppThemeService.themeMode.value = ThemeMode.dark;
      expect(AppColors.isLight, isFalse);
    });

    test('ink flips with the mode', () {
      AppThemeService.themeMode.value = ThemeMode.dark;
      final darkInk = AppColors.ink;
      AppThemeService.themeMode.value = ThemeMode.light;
      expect(AppColors.ink, isNot(darkInk));
    });
  });
}
