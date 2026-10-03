import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations_en.dart';
import 'package:playtorriomov/services/browse/home_rows_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Home-rows visibility store: everything shows by default, toggles
/// persist, and rows that appear later (addon catalogs) show until hidden
/// without ever resurrecting a hidden one.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomeRowsSettings.initialize();
  });

  group('defaults', () {
    test('every built-in row is visible in every section', () {
      for (final section in HomeSection.values) {
        expect(
          HomeRowsSettings.visibleFor(section).value,
          HomeRowsSettings.defaultsFor(section),
        );
      }
    });
  });

  group('toggleRow', () {
    test('hides and shows a row, surviving a restart', () async {
      await HomeRowsSettings.toggleRow(
        HomeSection.anime,
        'romance',
        visible: false,
      );
      expect(
        HomeRowsSettings.isVisible(HomeSection.anime, 'romance'),
        isFalse,
      );

      await HomeRowsSettings.initialize();
      expect(
        HomeRowsSettings.isVisible(HomeSection.anime, 'romance'),
        isFalse,
        reason: 'the choice must come back from storage',
      );

      await HomeRowsSettings.toggleRow(
        HomeSection.anime,
        'romance',
        visible: true,
      );
      expect(
        HomeRowsSettings.isVisible(HomeSection.anime, 'romance'),
        isTrue,
      );
    });

    test('refuses to hide the last visible row', () async {
      for (final id in HomeRowsSettings.defaultsFor(HomeSection.movies)) {
        await HomeRowsSettings.toggleRow(
          HomeSection.movies,
          id,
          visible: false,
        );
      }
      expect(
        HomeRowsSettings.visibleFor(HomeSection.movies).value.length,
        1,
        reason: 'a page with no rows reads as broken, not minimal',
      );
    });
  });

  group('registerRows', () {
    test('a new catalog row shows at once', () async {
      await HomeRowsSettings.registerRows(
        HomeSection.movies,
        ['catalog:Top Films'],
      );
      expect(
        HomeRowsSettings.isVisible(HomeSection.movies, 'catalog:Top Films'),
        isTrue,
      );
      expect(
        HomeRowsSettings.displayIds(HomeSection.movies).last,
        'catalog:Top Films',
      );
    });

    test('hiding a row survives seeing it again', () async {
      await HomeRowsSettings.registerRows(
        HomeSection.movies,
        ['catalog:Top Films'],
      );
      await HomeRowsSettings.toggleRow(
        HomeSection.movies,
        'catalog:Top Films',
        visible: false,
      );
      await HomeRowsSettings.registerRows(
        HomeSection.movies,
        ['catalog:Top Films'],
      );
      expect(
        HomeRowsSettings.isVisible(HomeSection.movies, 'catalog:Top Films'),
        isFalse,
        reason: 're-registering must not resurrect a hidden row',
      );
      expect(
        HomeRowsSettings.displayIds(HomeSection.movies),
        contains('catalog:Top Films'),
        reason: '...but it must stay listed so it can come back',
      );
    });

    test('reset restores the defaults', () async {
      await HomeRowsSettings.toggleRow(
        HomeSection.series,
        'topRated',
        visible: false,
      );
      await HomeRowsSettings.resetSection(HomeSection.series);
      expect(
        HomeRowsSettings.visibleFor(HomeSection.series).value,
        HomeRowsSettings.defaultsFor(HomeSection.series),
      );
    });
  });

  group('labelOf', () {
    test('every built-in id resolves to a translated label', () {
      final l10n = AppLocalizationsEn();
      for (final section in HomeSection.values) {
        for (final id in HomeRowsSettings.defaultsFor(section)) {
          expect(
            HomeRowsSettings.labelOf(section, id, l10n),
            isNot(id),
            reason: '$section/$id has no label and would show a raw id',
          );
        }
      }
    });

    test('a catalog row shows its own title', () {
      final l10n = AppLocalizationsEn();
      expect(
        HomeRowsSettings.labelOf(
          HomeSection.movies,
          'catalog:Top Films',
          l10n,
        ),
        'Top Films',
      );
    });
  });
}
