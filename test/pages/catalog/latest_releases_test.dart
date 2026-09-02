// test/pages/catalog/latest_releases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/pages/catalog/latest_releases.dart';

Movie movie(String id, String? year) =>
    Movie(id: id, name: id, year: year, type: 'movie', addonBaseUrl: '');

void main() {
  group('latestReleases', () {
    test('sorts by year descending', () {
      final result = latestReleases([
        movie('old', '1999'),
        movie('newest', '2026'),
        movie('mid', '2010'),
      ]);

      expect(result.map((m) => m.id).toList(), ['newest', 'mid', 'old']);
    });

    test('items with no parseable year sort last, without crashing', () {
      final result = latestReleases([
        movie('has-year', '2020'),
        movie('no-year', null),
        movie('garbage-year', 'TBA'),
      ]);

      expect(result.first.id, 'has-year');
      expect(result.map((m) => m.id).toSet(), {
        'has-year',
        'no-year',
        'garbage-year',
      });
    });

    test('truncates to limit', () {
      final items = [for (var i = 0; i < 30; i++) movie('m$i', '${2000 + i}')];
      final result = latestReleases(items, limit: 5);
      expect(result.length, 5);
      expect(result.first.id, 'm29'); // 2029, the newest
    });
  });
}
