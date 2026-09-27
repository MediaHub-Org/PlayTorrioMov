import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/movie/movie_year.dart';

void main() {
  group('startYearOf', () {
    test('reads the start of a range', () {
      expect(startYearOf('2020–2023'), 2020);
      expect(startYearOf('2022–'), 2022);
      expect(startYearOf('2022-2023'), 2020 + 2);
    });

    test('reads plain years and dates', () {
      expect(startYearOf('2024'), 2024);
      expect(startYearOf('2024-03-01'), 2024);
      expect(startYearOf(null), isNull);
      expect(startYearOf('TBA'), isNull);
    });
  });

  group('displayYearRange', () {
    test('joins a closed range with spaced hyphen', () {
      expect(displayYearRange('2020–2023'), '2020 - 2023');
      expect(displayYearRange('2020-2023'), '2020 - 2023');
    });

    test('an open range reads as its bare start year', () {
      expect(displayYearRange('2022–'), '2022');
    });

    test('single years and unknowns pass through', () {
      expect(displayYearRange('2024'), '2024');
      expect(displayYearRange('TBA'), 'TBA');
      expect(displayYearRange(null), isEmpty);
    });
  });
}
