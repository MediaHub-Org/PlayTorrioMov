import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/utils/search_scope.dart';

void main() {
  group('SearchFilter.fromScope', () {
    test('picks the filter matching the section the user came from', () {
      expect(SearchFilter.fromScope('movie'), SearchFilter.movie);
      expect(SearchFilter.fromScope('series'), SearchFilter.series);
      expect(SearchFilter.fromScope('anime'), SearchFilter.anime);
    });

    test('falls back to All for scopes with no chip of their own', () {
      // Live TV keeps its own search, and the Library sets a null scope --
      // opening on a filter with no visible chip would leave the user with
      // results they cannot explain or widen.
      expect(SearchFilter.fromScope('iptv'), SearchFilter.all);
      expect(SearchFilter.fromScope(null), SearchFilter.all);
      expect(SearchFilter.fromScope('audiobook'), SearchFilter.all);
    });
  });

  group('where a query is sent', () {
    test('All asks both catalogues, with no addon type restriction', () {
      expect(SearchFilter.all.searchesAddons, isTrue);
      expect(SearchFilter.all.searchesAnime, isTrue);
      expect(SearchFilter.all.addonContentType, isNull);
    });

    test('Movies and Series ask only the addons, scoped to their type', () {
      expect(SearchFilter.movie.searchesAddons, isTrue);
      expect(SearchFilter.movie.searchesAnime, isFalse);
      expect(SearchFilter.movie.addonContentType, 'movie');

      expect(SearchFilter.series.searchesAddons, isTrue);
      expect(SearchFilter.series.searchesAnime, isFalse);
      expect(SearchFilter.series.addonContentType, 'series');
    });

    test('Anime asks AniList only', () {
      // The addons have no anime catalog to answer with, so asking them is
      // a request that can only come back empty.
      expect(SearchFilter.anime.searchesAddons, isFalse);
      expect(SearchFilter.anime.searchesAnime, isTrue);
    });

    test('every filter is reachable from its own id', () {
      for (final filter in SearchFilter.values) {
        expect(SearchFilter.fromScope(filter.id), filter);
        expect(filter.label, isNotEmpty);
        expect(filter.scopeLabel, isNotEmpty);
      }
    });
  });
}
