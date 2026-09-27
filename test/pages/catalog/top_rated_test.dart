// test/pages/catalog/top_rated_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/pages/catalog/top_rated.dart';

Movie movie(String id, String? rating) => Movie(
      id: id,
      name: id,
      type: 'movie',
      addonBaseUrl: '',
      imdbRating: rating,
    );

void main() {
  group('topRated', () {
    test('sorts by rating descending', () {
      final result = topRated([
        movie('mid', '7.5'),
        movie('best', '9.1'),
        movie('low', '7.0'),
        movie('great', '8.8'),
      ]);

      expect(
        result.map((m) => m.id).toList(),
        ['best', 'great', 'mid', 'low'],
      );
    });

    test('reads the leading number whatever shape the addon sent', () {
      final result = topRated([
        movie('slash', '8.7/10'),
        movie('plain', '9.0'),
        movie('junk', 'N/A'),
        movie('none', null),
        movie('third', '7.2'),
        movie('fourth', '7.8'),
      ]);

      // Unrated titles never make the row: without a score there is no
      // claim to acclaim.
      expect(
        result.map((m) => m.id).toList(),
        ['plain', 'slash', 'fourth', 'third'],
      );
    });

    test('a shelf of low scores is not top anything', () {
      // Four-plus titles but nothing acclaimed: the caller skips the row
      // rather than showing it.
      expect(
        topRated([
          movie('a', '6.9'),
          movie('b', '6.5'),
          movie('c', '6.1'),
          movie('d', '5.8'),
        ]),
        isEmpty,
      );
      // And a thin catalog does not get a row of two either.
      expect(
        topRated([movie('a', '9.2'), movie('b', '8.9')]),
        isEmpty,
      );
    });

    test('truncates to limit', () {
      final items = [
        for (var i = 0; i < 30; i++)
          movie('m$i', (7.0 + i / 10).toStringAsFixed(1)),
      ];
      final result = topRated(items, limit: 5);
      expect(result.length, 5);
      expect(result.first.id, 'm29');
    });
  });
}
