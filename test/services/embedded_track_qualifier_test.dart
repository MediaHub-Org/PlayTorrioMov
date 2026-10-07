// Two embedded tracks of one language used to read the same. Most anime
// releases ship a full English track beside a "Signs & Songs" one, and with
// numbering off for embedded lists the picker showed "English" twice with
// nothing to choose by. The container title is the only place the difference
// is written.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';

/// The labels the player would draw for tracks with these tags and titles.
List<String> labelsFor(
  List<String?> languages,
  List<String?> titles, {
  List<String?> codecs = const [],
}) {
  final names = uniqueTrackLanguageNames(
    languages,
    titles,
    numberDuplicates: false,
  );
  final qualifiers = embeddedTrackQualifiers(
    names,
    titles,
    codecs: codecs,
  );
  return [
    for (var i = 0; i < names.length; i++)
      PlayerEmbeddedSubtitle(
        index: i + 1,
        title: names[i],
        language: names[i],
        qualifier: qualifiers[i],
      ).displayName,
  ];
}

void main() {
  group('embeddedTrackQualifiers', () {
    test('a full track and a Signs & Songs track no longer read the same', () {
      expect(
        labelsFor(['eng', 'eng'], ['Full', 'Signs & Songs']),
        ['English · Full', 'English · Signs & Songs'],
      );
    });

    test('a plain track keeps its bare name beside a described one', () {
      expect(
        labelsFor(['eng', 'eng'], ['English', 'English (Signs/Songs)']),
        ['English', 'English · Signs/Songs'],
      );
    });

    test('a language with one track is just its name', () {
      expect(labelsFor(['eng'], ['Signs & Songs']), ['English']);
    });

    test('the format separates twins the titles cannot', () {
      // Forced and SDH are badges, the language is the name: none of it is
      // a qualifier -- but a PGS beside an SRT really are different things
      // to pick, so the format names the rows instead of nothing doing so.
      expect(
        labelsFor(
          ['eng', 'eng'],
          ['English', 'English [SDH]'],
          codecs: ['hdmv_pgs_subtitle', 'subrip'],
        ),
        ['English · PGS', 'English · SRT'],
      );
      expect(
        labelsFor(
          ['eng', 'eng'],
          ['English (Forced)', 'English'],
          codecs: ['subrip', 'ass'],
        ),
        ['English · SRT', 'English · ASS'],
      );
    });

    test('identical twins with identical formats take numbers', () {
      // Nothing -- title, format, nothing -- tells these apart, so the
      // rows take numbers rather than reading the same word twice.
      expect(
        labelsFor(['eng', 'eng'], ['Commentary', 'Commentary']),
        ['English #1', 'English #2'],
      );
    });

    test('a region already tells two tracks apart, so no qualifier', () {
      expect(
        labelsFor(['spa', 'spa'], ['Spanish (Castilian)', 'Spanish (Latin America)']),
        ['Spanish (ES)', 'Spanish (LATAM)'],
      );
    });

    test('words that are languages or two-letter words are not dropped wrongly',
        () {
      // "no" and "to" are words, not Norwegian or Tonga.
      expect(
        labelsFor(['eng', 'eng'], ['English', 'Songs to sing']),
        ['English', 'English · Songs to sing'],
      );
    });

    test('tracks with no label are skipped', () {
      expect(embeddedTrackQualifiers(['', ''], ['Full', 'Other']), [null, null]);
    });
  });

  group('embedded titles', () {
    test('Chinese written in its own characters keeps its script', () {
      expect(
        labelsFor(['zho', 'chi'], ['简体中文', '繁體中文']),
        ['Chinese (Simplified)', 'Chinese (Traditional)'],
      );
    });

    test('a multi-language tag is named, not shouted', () {
      expect(subtitleTrackLanguageName('mul'), 'Multiple');
    });

    test("a muxer's private-use tag is not a language", () {
      expect(subtitleTrackLanguageName('qaa'), isEmpty);
      expect(subtitleTrackLanguageName('qtz'), isEmpty);
      // The neighbors of the range are real.
      expect(subtitleTrackLanguageName('eng'), 'English');
    });

    test('a title that only says Forced or SDH does not name the track', () {
      expect(
        embeddedFallbackTitle(containerTitle: 'Forced', codec: 'subrip', index: 3),
        'Track 3 · SRT',
      );
      expect(
        embeddedFallbackTitle(containerTitle: '[Forced] SDH', index: 2),
        'Track 2',
      );
      // A title with a real name still wins.
      expect(
        embeddedFallbackTitle(containerTitle: 'Commentary', index: 1),
        'Commentary',
      );
    });
  });

  test('withFlags keeps the qualifier', () {
    const track = PlayerEmbeddedSubtitle(
      index: 1,
      title: 'English',
      language: 'English',
      qualifier: 'Signs & Songs',
    );
    expect(
      track.withFlags(isDefault: true, isForcedTrack: false).displayName,
      'English · Signs & Songs',
    );
  });
}
