// test/widgets/header_pill_surface_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_colors.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/header_pill_style.dart';
import 'package:playtorriomov/widgets/common/over_artwork.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Icon _icon(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first);

void main() {
  tearDown(() => AppThemeService.themeMode.value = ThemeMode.system);

  group('OverArtwork', () {
    testWidgets('pills over a hero stay white in light mode', (tester) async {
      // Live TV's header floats over the hero on a dark scrim. Following the
      // theme's ink there paints black glyphs onto a photograph.
      AppThemeService.themeMode.value = ThemeMode.light;
      await tester.pumpWidget(_wrap(
        OverArtwork.yes(
          child: HeaderPillIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onTap: () {},
          ),
        ),
      ));

      expect(_icon(tester).color?.r, AppColors.onAccent.r);
      expect(AppColors.ink, isNot(AppColors.onAccent),
          reason: 'light-mode ink must differ, or this proves nothing');
    });

    testWidgets('pills in their own band follow the theme', (tester) async {
      AppThemeService.themeMode.value = ThemeMode.light;
      await tester.pumpWidget(_wrap(
        HeaderPillIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onTap: () {},
        ),
      ));

      // No OverArtwork ancestor: the default is "not over artwork",
      // which is right for every pill row outside a hero.
      expect(_icon(tester).color?.r, AppColors.ink.r);
    });

    testWidgets('a pill and its decoration draw from one tint',
        (tester) async {
      // The bug this guards is a pill with a light border and a dark glyph:
      // two colors picked from different sources for the same control.
      for (final overArtwork in [true, false]) {
        AppThemeService.themeMode.value = ThemeMode.light;
        await tester.pumpWidget(_wrap(
          OverArtwork(
            value: overArtwork,
            child: const HeaderPillLabel(
              label: 'LIVE TV',
              icon: Icons.live_tv_rounded,
            ),
          ),
        ));

        // Scoped to the pill: Material and Scaffold put their own
        // DecoratedBoxes above it in the tree.
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(HeaderPillLabel),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        final expected = overArtwork ? AppColors.onAccent : AppColors.ink;
        expect(decoration.color?.r, expected.r,
            reason: 'fill disagrees with the tint (overArtwork: $overArtwork)');
        expect(_icon(tester).color?.r, expected.r,
            reason: 'glyph disagrees with the tint (overArtwork: $overArtwork)');
      }
    });
  });
}
