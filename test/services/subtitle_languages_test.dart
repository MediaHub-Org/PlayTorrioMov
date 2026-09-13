import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';

void main() {
  group('subtitleLanguageName', () {
    test('names the languages every provider always handled', () {
      expect(subtitleLanguageName('eng'), 'English');
      expect(subtitleLanguageName('en'), 'English');
      expect(subtitleLanguageName('spa'), 'Spanish');
      expect(subtitleLanguageName('ara'), 'Arabic');
      expect(subtitleLanguageName('fre'), 'French');
    });

    test('names the ones two providers used to miss', () {
      // The reason this table is shared. OpenSubtitles and Wyzie carried a
      // copy 51 entries shorter than Stremio's, so these rendered as raw
      // codes there and as names here -- same subtitle, different label,
      // depending only on which provider found it.
      expect(subtitleLanguageName('hrv'), 'Croatian');
      expect(subtitleLanguageName('bul'), 'Bulgarian');
      expect(subtitleLanguageName('tam'), 'Tamil');
      expect(subtitleLanguageName('ben'), 'Bengali');
      expect(subtitleLanguageName('srp'), 'Serbian');
      expect(subtitleLanguageName('slk'), 'Slovak');
      expect(subtitleLanguageName('cat'), 'Catalan');
      expect(subtitleLanguageName('ice'), 'Icelandic');
    });

    test('the 2- and 3-letter forms of a language agree', () {
      // Providers report whichever they feel like; a viewer should not see
      // "Serbian" from one and "SR" from another.
      for (final pair in const [
        ['hrv', 'hr'],
        ['bul', 'bg'],
        ['tam', 'ta'],
        ['srp', 'sr'],
        ['slv', 'sl'],
        ['est', 'et'],
      ]) {
        expect(
          subtitleLanguageName(pair[0]),
          subtitleLanguageName(pair[1]),
          reason: '${pair[0]} and ${pair[1]} should name the same language',
        );
      }
    });

    test('is case-insensitive, because providers are not consistent', () {
      expect(subtitleLanguageName('ENG'), 'English');
      expect(subtitleLanguageName('Hrv'), 'Croatian');
    });

    test('an unknown short code upper-cases, reading as an abbreviation', () {
      expect(subtitleLanguageName('zzz'), 'ZZZ');
      expect(subtitleLanguageName('qq'), 'QQ');
    });

    test('an unknown long code is left alone, being already a word', () {
      expect(subtitleLanguageName('klingon'), 'klingon');
      expect(subtitleLanguageName('pt-brazil'), 'pt-brazil');
    });

    test('Brazilian Portuguese is distinguished from Portuguese', () {
      expect(subtitleLanguageName('pob'), 'Portuguese (BR)');
      expect(subtitleLanguageName('por'), isNot('Portuguese (BR)'));
    });
  });
}
