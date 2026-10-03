import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/pages/settings/appearance/home_rows_settings_page.dart';
import 'package:playtorriomov/services/browse/home_rows_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Home-rows settings page: one group per section, a checkbox per row.
Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomeRowsSettings.initialize();
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
      await HomeRowsSettings.initialize();
    });
  });

  group('HomeRowsSettingsPage', () {
    testWidgets('lists the three sections with their rows', (tester) async {
      await tester.pumpWidget(wrap(const HomeRowsSettingsPage()));
      await tester.pump();

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      // The anime card starts below the fold at this viewport -- scroll to
      // it the way a viewer would, rather than peeking offstage.
      await tester.scrollUntilVisible(find.text('Anime'), 300);
      await tester.pump();
      expect(find.text('Anime'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Trending Anime'), 300);
      await tester.pump();
      expect(find.text('Trending Anime'), findsOneWidget);
    });

    testWidgets('unchecking a row hides it on its home page', (tester) async {
      await tester.pumpWidget(wrap(const HomeRowsSettingsPage()));
      await tester.pump();

      // Two rows share the label (Films and Series); the Films card comes
      // first on the page, so the topmost match is its checkbox.
      await tester.tap(find.text('Latest Releases').first);
      await tester.pumpAndSettle();

      expect(
        HomeRowsSettings.isVisible(HomeSection.movies, 'latestReleases'),
        isFalse,
      );
      expect(
        HomeRowsSettings.isVisible(HomeSection.series, 'latestReleases'),
        isTrue,
        reason: 'sections are independent stores',
      );
    });
  });
}
