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

    test('a region in one title numbers the whole group', () {
      // Regions are used throughout or not at all. "Spanish (LATAM)" beside
      // "Spanish #1" reads as two different kinds of thing when they are the
      // same kind of thing, and the number says nothing a viewer can act on.
      // One title naming no region means the group is numbered.
      expect(
        uniqueTrackLanguageNames(
          ['spa', 'spa'],
          ['Spanish (Latin America)', 'Spanish'],
        ),
        ['Spanish #1', 'Spanish #2'],
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

  group('language codes a provider actually sends', () {
    test('Norwegian is recognized from nb, not rendered as "NB"', () {
      // `nb` is Bokmål, which is what a provider means by "Norwegian". It
      // was missing from the table, so the row read "NB".
      for (final code in ['nb', 'nob', 'no', 'nor']) {
        expect(subtitleLanguageName(code), 'Norwegian', reason: code);
      }
    });

    test('Nynorsk is kept apart from Bokmål', () {
      // A different written form, not a spelling of the same one.
      expect(subtitleLanguageName('nn'), 'Norwegian (Nynorsk)');
      expect(subtitleLanguageName('nno'), 'Norwegian (Nynorsk)');
    });

    test('the long tail of codes renders as names, not raw codes', () {
      // Each of these was rendering as a three-letter code -- "MAR", "YUE",
      // "AFR" -- which reads as noise rather than as a language.
      const expected = {
        'mar': 'Marathi',
        'guj': 'Gujarati',
        'kan': 'Kannada',
        'pan': 'Punjabi',
        'urd': 'Urdu',
        'nep': 'Nepali',
        'mya': 'Burmese',
        'khm': 'Khmer',
        'lao': 'Lao',
        'yue': 'Cantonese',
        'cmn': 'Mandarin',
        'afr': 'Afrikaans',
        'amh': 'Amharic',
        'yor': 'Yoruba',
        'hau': 'Hausa',
        'zul': 'Zulu',
        'aze': 'Azerbaijani',
        'kaz': 'Kazakh',
        'uzb': 'Uzbek',
        'kat': 'Georgian',
        'hye': 'Armenian',
        'bel': 'Belarusian',
        'gle': 'Irish',
        'cym': 'Welsh',
        'eus': 'Basque',
        'glg': 'Galician',
        'mlt': 'Maltese',
        'asm': 'Assamese',
        'snd': 'Sindhi',
        'tat': 'Tatar',
        'tuk': 'Turkmen',
        'kir': 'Kyrgyz',
        'tgk': 'Tajik',
      };
      for (final entry in expected.entries) {
        expect(
          subtitleLanguageName(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('a genuinely unknown code still renders as itself', () {
      // The fallback has to survive: a code we do not know is better shown
      // than dropped.
      expect(subtitleLanguageName('zzz'), 'ZZZ');
    });
  });
}