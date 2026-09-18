// test/services/accent_token_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_colors.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';

/// Files allowed to name the default palette's primary as a literal, and why.
const _allowed = {
  // The palette definition itself: this literal *is* Amethyst Violet.
  'lib/services/theme/app_theme_service.dart',
  // A saved channel's tile gradient. Data on a model whose other rows carry
  // broadcasters' own brand colors, so it is not app chrome and must not
  // move when the palette does.
  'lib/services/iptv/custom_channels_service.dart',
};

void main() {
  tearDown(() => AppThemeService.themeMode.value = ThemeMode.system);

  test('the accent token follows the selected palette', () {
    // The whole point of the token. Eight palettes ship; before this the app
    // painted the first one's violet in 159 places regardless of choice.
    const palettes = AppThemeService.palettes;
    expect(palettes.length, greaterThan(1));

    final seen = <Color>{};
    for (final palette in palettes) {
      AppThemeService.currentPalette.value = palette;
      expect(AppColors.accent, palette.primaryColor);
      seen.add(AppColors.accent);
    }
    expect(seen.length, greaterThan(1),
        reason: 'the accent must actually differ between palettes');
    AppThemeService.currentPalette.value = palettes.first;
  });

  test('the accent does not move with the theme mode', () {
    // A palette carries one primary for both brightnesses, unlike ink and
    // the surfaces. Anything drawn *on* it is onAccent, never ink.
    AppThemeService.themeMode.value = ThemeMode.dark;
    final dark = AppColors.accent;
    AppThemeService.themeMode.value = ThemeMode.light;
    expect(AppColors.accent, dark);
  });

  test('no page hardcodes the default palette instead of the token', () {
    // Each of these was a place the eight-palette theme picker silently did
    // not reach.
    final violet = RegExp(r'Color\(\s*0xFF7C5CFF\s*,?\s*\)');
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (_allowed.contains(file.path)) continue;
      final matches = violet.allMatches(file.readAsStringSync()).length;
      if (matches > 0) offenders.add('${file.path} ($matches)');
    }

    expect(offenders, isEmpty,
        reason: 'use AppColors.accent so the palette picker reaches this');
  });
}
