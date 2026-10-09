import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tmdb/tmdb_service.dart';

void main() {
  group('TmdbService.languageTagFor', () {
    test('regional where the app is regional, bare otherwise', () {
      expect(TmdbService.languageTagFor('es'), 'es-ES');
      expect(TmdbService.languageTagFor('pt'), 'pt-BR');
      expect(TmdbService.languageTagFor('ar'), 'ar');
      expect(TmdbService.languageTagFor('en'), 'en-US');
    });

    test('the description follows the viewer, not just the app languages', () {
      // The app is translated into four languages, but the synopsis is
      // TMDB's, and a French or Japanese viewer was reading English.
      expect(TmdbService.languageTagFor('fr'), 'fr-FR');
      expect(TmdbService.languageTagFor('de'), 'de-DE');
      expect(TmdbService.languageTagFor('ja'), 'ja-JP');
      expect(TmdbService.languageTagFor('ko'), 'ko-KR');
      expect(TmdbService.languageTagFor('zh'), 'zh-CN');
      expect(TmdbService.languageTagFor('no'), 'nb-NO');
    });

    test('unknown codes fall back to English, not to TMDB guessing', () {
      expect(TmdbService.languageTagFor('xx'), 'en-US');
      expect(TmdbService.languageTagFor(null), 'en-US');
    });
  });

  group('TmdbService.parseOverview', () {
    test('reads the overview', () {
      expect(
        TmdbService.parseOverview({'overview': 'A thief steals dreams.'}),
        'A thief steals dreams.',
      );
    });

    test('missing or blank is null, so the caller keeps the addon text', () {
      expect(TmdbService.parseOverview({}), isNull);
      expect(TmdbService.parseOverview({'overview': '   '}), isNull);
    });
  });
}
