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
      expect(subtitleLanguageName('klingon'), 'Klingon');
      expect(subtitleLanguageName('pt-brazil'), 'Pt-brazil');
    });

    test('Brazilian Portuguese is distinguished from Portuguese', () {
      expect(subtitleLanguageName('pob'), 'Portuguese (BR)');
      expect(subtitleLanguageName('por'), isNot('Portuguese (BR)'));
    });

    test('keeps regional variants apart, and names them', () {
      // Spanish (ES) and Spanish (LATAM) are different recordings, not two
      // spellings of one label, so they are two groups -- a viewer who wants
      // one does not want the other.
      expect(subtitleLanguageName('es-es'), 'Spanish (ES)');
      expect(subtitleLanguageName('es-419'), 'Spanish (LATAM)');
      expect(canonicalLanguageGroup('Spanish (ES)'), 'Spanish (ES)');
      expect(canonicalLanguageGroup('Spanish (LATAM)'), 'Spanish (LATAM)');
      expect(
        canonicalLanguageGroup('Spanish (ES)'),
        isNot(canonicalLanguageGroup('Spanish (LATAM)')),
      );
    });

    test('Portuguese (BR) and (PT) are two groups', () {
      expect(subtitleLanguageName('pt-br'), 'Portuguese (BR)');
      expect(subtitleLanguageName('pt-pt'), 'Portuguese (PT)');
      expect(
        canonicalLanguageGroup('Portuguese (BR)'),
        isNot(canonicalLanguageGroup('Portuguese (PT)')),
      );
    });

    test('English (US) and (UK) are two groups', () {
      expect(subtitleLanguageName('en-us'), 'English (US)');
      expect(subtitleLanguageName('en-gb'), 'English (UK)');
      expect(
        canonicalLanguageGroup('English (US)'),
        isNot(canonicalLanguageGroup('English (UK)')),
      );
    });

    test('a bare code still groups with its own language', () {
      // Untagged provider Spanish is Castilian until it says otherwise, so
      // it joins the ES group rather than sitting beside it. LATAM-tagged
      // results keep their own group.
      expect(canonicalLanguageGroup('Spanish'), 'Spanish (ES)');
      expect(canonicalLanguageGroup('es'), 'Spanish (ES)');
    });

    test('muxer spellings of the Chinese tags join Chinese', () {
      // Containers write "chs" and "cht" where mpv reports "zhc" and "zht".
      expect(subtitleTrackLanguageName('chs'), 'Chinese (Simplified)');
      expect(subtitleTrackLanguageName('cht'), 'Chinese (Traditional)');
      expect(canonicalLanguageGroup('cht'), 'Chinese');
    });

    test('does not expose signs-only mpv tracks as a language', () {
      expect(subtitleTrackLanguageName('spl'), isEmpty);
      expect(canonicalLanguageGroup('spl'), isEmpty);
    });

    test('does not label monolingual mpv tracks "Same as audio"', () {
      expect(subtitleTrackLanguageName('mon'), isEmpty);
      expect(canonicalLanguageGroup('MON'), isEmpty);
    });

    test('does not offer mpv\'s "auto" pseudo-track as a language', () {
      // It reached the picker as a row reading "Auto", which is not
      // something anyone can choose deliberately -- there is nothing to
      // choose it by.
      expect(subtitleTrackLanguageName('auto'), isEmpty);
      expect(subtitleTrackLanguageName('AUTO'), isEmpty);
      expect(subtitleTrackLanguageName(' auto '), isEmpty);
    });
  });
}
