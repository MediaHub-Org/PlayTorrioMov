// test/services/subtitle_languages_test.dart additions are in the existing
// file; this covers the duplicate-track naming that file did not.
//
// A file with two Spanish subtitle tracks rendered both as "Spanish", so the
// list showed the same word twice and the choice between them was invisible.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';

void main() {
  group('uniqueTrackLanguageNames', () {
    test('leaves a single track of a language alone', () {
      expect(
        uniqueTrackLanguageNames(['spa'], ['Spanish']),
        ['Spanish'],
      );
    });

    test('names duplicates from their own titles when the titles say', () {
      // The case that matters: a file with both Spanish dubs. The titles are
      // what tell them apart, and a region is a better label than a number.
      expect(
        uniqueTrackLanguageNames(
          ['spa', 'spa'],
          ['Spanish (Castilian)', 'Spanish (Latin America)'],
        ),
        ['Spanish (ES)', 'Spanish (LATAM)'],
      );
    });

    test('numbers duplicates when the titles say nothing', () {
      // Numbering is the honest answer: the tracks really are
      // indistinguishable from their metadata, and a viewer picking between
      // them is picking by trial.
      expect(
        uniqueTrackLanguageNames(['spa', 'spa'], ['Spanish', 'Spanish']),
        ['Spanish #1', 'Spanish #2'],
      );
    });

    test('numbers only the duplicates, not every track', () {
      expect(
        uniqueTrackLanguageNames(
          ['eng', 'spa', 'spa'],
          ['English', 'Spanish', 'Spanish'],
        ),
        ['English', 'Spanish #1', 'Spanish #2'],
      );
    });

    test('a region in one title does not number the other', () {
      // One is named by its region; the other is still a duplicate of the
      // bare name, so it takes a number. The two rows are distinguishable,
      // which is the whole point.
      expect(
        uniqueTrackLanguageNames(
          ['spa', 'spa'],
          ['Spanish (Latin America)', 'Spanish'],
        ),
        ['Spanish (LATAM)', 'Spanish #1'],
      );
    });

    test('a bracketed region code is read too', () {
      expect(
        uniqueTrackLanguageNames(['spa', 'spa'], ['Spanish [ES]', 'Spanish [MX]']),
        ['Spanish (ES)', 'Spanish (MX)'],
      );
    });

    test('an unknown language is left alone, not numbered', () {
      // There is nothing to disambiguate, and numbering "Track 3" would
      // invent a language.
      expect(
        uniqueTrackLanguageNames([null, null], [null, null]),
        ['', ''],
      );
    });

    test('three of a kind number in order', () {
      expect(
        uniqueTrackLanguageNames(
          ['por', 'por', 'por'],
          ['Portuguese', 'Portuguese', 'Portuguese'],
        ),
        ['Portuguese #1', 'Portuguese #2', 'Portuguese #3'],
      );
    });

    test('a wrong region is not guessed from an unrelated word', () {
      // "Standard" names no region, so the fallback is the number rather
      // than a label the track does not claim.
      expect(
        uniqueTrackLanguageNames(['spa', 'spa'], ['Standard', 'Standard']),
        ['Spanish #1', 'Spanish #2'],
      );
    });
  });
}