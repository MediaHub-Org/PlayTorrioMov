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
