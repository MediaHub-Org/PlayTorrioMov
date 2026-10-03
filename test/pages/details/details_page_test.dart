import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/pages/details/details_page.dart';

/// The season a details page opens on. Season 0 is specials, and most shows
/// carry little or nothing there -- opening on it reads as an empty episode
/// rail, which is how "no episodes" reports started.
void main() {
  group('DetailsPage.initialSeason', () {
    test('skips the specials for the first real season', () {
      expect(
        DetailsPage.initialSeason([0, 1, 2, 3, 4, 5, 6, 7, 8]),
        1,
      );
    });

    test('a title with only specials still opens on what it has', () {
      expect(DetailsPage.initialSeason([0]), 0);
    });

    test('no seasons is no selection', () {
      expect(DetailsPage.initialSeason(const []), isNull);
    });

    test('a sorted list without specials opens on its first season', () {
      expect(DetailsPage.initialSeason([1, 2, 3]), 1);
      expect(DetailsPage.initialSeason([2]), 2);
    });

    test('null entries are ignored, not selected', () {
      expect(DetailsPage.initialSeason([null, 0, 2]), 2);
      expect(DetailsPage.initialSeason([null]), isNull);
    });
  });

  group('DetailsPage.splitSeasons', () {
    test('specials split off, numbered seasons sorted from 1', () {
      final split = DetailsPage.splitSeasons([0, 8, 1, 2, 0, null]);
      expect(split.numbered, [1, 2, 8]);
      expect(split.hasSpecials, isTrue);
    });

    test('no specials, no special pill', () {
      final split = DetailsPage.splitSeasons([1, 2, 3]);
      expect(split.numbered, [1, 2, 3]);
      expect(split.hasSpecials, isFalse);
    });

    test('only specials leaves the numbered list empty', () {
      final split = DetailsPage.splitSeasons([0, null]);
      expect(split.numbered, isEmpty);
      expect(split.hasSpecials, isTrue);
    });

    test('nothing at all splits to nothing', () {
      final split = DetailsPage.splitSeasons(const <int?>[]);
      expect(split.numbered, isEmpty);
      expect(split.hasSpecials, isFalse);
    });
  });
}
