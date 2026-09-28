// test/pages/catalog/distinct_rows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/pages/catalog/type_catalog_page.dart';
import 'package:playtorriomov/widgets/common/browse_scaffold.dart';

Movie movie(String id, {String type = 'movie'}) => Movie(
      id: id,
      name: id,
      type: type,
      addonBaseUrl: '',
    );

BrowseRow<Movie> row(String title, List<Movie> items) =>
    BrowseRow<Movie>(title: title, items: items);

void main() {
  group('distinctBrowseRows', () {
    test('a title appears in its first row only', () {
      final result = distinctBrowseRows([
        row('Popular', [movie('a'), movie('b')]),
        row('Top', [movie('b'), movie('c')]),
      ]);

      expect(result.map((r) => r.title), ['Popular', 'Top']);
      expect(result[0].items.map((m) => m.id), ['a', 'b']);
      expect(result[1].items.map((m) => m.id), ['c']);
    });

    test('a row left with nothing is dropped', () {
      final result = distinctBrowseRows([
        row('Popular', [movie('a')]),
        row('Top', [movie('a')]),
      ]);

      expect(result.map((r) => r.title), ['Popular']);
    });

    test('the same id under another type is another title', () {
      // Trakt-style numeric ids repeat across movies and series; the key
      // is qualified, so one does not eat the other.
      final result = distinctBrowseRows([
        row('Films', [movie('1', type: 'movie')]),
        row('Series', [movie('1', type: 'series')]),
      ]);

      expect(result.length, 2);
    });

    test('an empty list stays empty', () {
      expect(distinctBrowseRows([]), isEmpty);
    });
  });
}
