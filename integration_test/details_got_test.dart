import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/pages/details/details_page.dart';

/// On-device twin of the widget repro that cannot run under `flutter test`:
/// the widget-test binding answers every HTTP request with a 400, so the
/// meta fetch fails there by construction. Here the HTTP is real, the page
/// is real, and the artwork bytes really arrive.
///
/// Run with: flutter test integration_test/details_got_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GoT details renders seasons and episode cards',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DetailsPage(
            movie: Movie(
              id: 'tt0944947',
              name: 'Game of Thrones',
              type: 'series',
              addonBaseUrl: 'https://v3-cinemeta.strem.io',
            ),
          ),
        ),
      );

      // Real time for the meta fetch and the animations to play out.
      await Future<void>.delayed(const Duration(seconds: 25));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // ignore: avoid_print
      print(
        'Specials pill: ${find.text('Specials').evaluate().length}, '
        'Season 1 pill: ${find.text('Season 1').evaluate().length}, '
        'EP cards: ${find.textContaining('EP ').evaluate().length}',
      );

      // Specials exist in the data but the page opens on Season 1.
      expect(find.text('Specials'), findsOneWidget);
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.textContaining('EP '), findsWidgets);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
