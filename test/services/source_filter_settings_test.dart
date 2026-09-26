// test/services/source_filter_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/sources/source_filter_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

StreamSource _source(String title) =>
    StreamSource(addonName: 'Test', title: title);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceFilterSettings.audioLanguages.value = const <String>[];
    SourceFilterSettings.qualities.value = const <String>[];
  });

  group('StreamSource.hasAudioLanguage and MULTI', () {
    // A MULTI tag means "more than one dub, which one is not stated". The
    // filter must not hide it from any concrete language, or it reports
    // "nothing found" about a source that very likely plays fine.
    test('a bare MULTI matches any concrete language', () {
      final s = _source('Some Movie 1080p MULTI');
      expect(s.hasAudioLanguage('multi'), isTrue);
      expect(s.hasAudioLanguage('english'), isTrue);
      expect(s.hasAudioLanguage('spanish'), isTrue);
      expect(s.hasAudioLanguage('japanese'), isTrue);
    });

    test('naming a second language does not remove the MULTI match', () {
      // The regression this covers: 'MULTI · Spanish' used to match Spanish
      // only, because the English fallback stopped firing once any other
      // language was named.
      final s = _source('Some Movie MULTI · Spanish 1080p');
      expect(s.hasAudioLanguage('english'), isTrue);
      expect(s.hasAudioLanguage('spanish'), isTrue);
      expect(s.hasAudioLanguage('french'), isTrue);
    });

    test('a single-language source matches only its language', () {
      final s = _source('Some Movie German DL 1080p');
      expect(s.hasAudioLanguage('german'), isTrue);
      expect(s.hasAudioLanguage('french'), isFalse);
      expect(s.hasAudioLanguage('multi'), isFalse);
    });
  });

  group('hasAnyAudioLanguage', () {
    test('an empty selection is no filter at all', () {
      expect(
        _source('Some Movie German DL').hasAnyAudioLanguage(const []),
        isTrue,
      );
    });

    test('matches when any one of the selected languages matches', () {
      final s = _source('Some Movie German DL 1080p');
      expect(s.hasAnyAudioLanguage(const ['french', 'german']), isTrue);
      expect(s.hasAnyAudioLanguage(const ['french', 'italian']), isFalse);
    });

    test('a MULTI source matches a selection of concrete languages', () {
      final s = _source('Some Movie MULTI 1080p');
      expect(s.hasAnyAudioLanguage(const ['korean', 'turkish']), isTrue);
    });
  });

  group('hasAnyQuality', () {
    test('an empty selection is no filter at all', () {
      expect(_source('Some stream').hasAnyQuality(const []), isTrue);
    });

    test('matches when any one of the selected qualities matches', () {
      final s = _source('Movie 1080p WEB-DL');
      expect(s.hasAnyQuality(const ['720p', '1080p']), isTrue);
      expect(s.hasAnyQuality(const ['720p', '480p']), isFalse);
    });
  });

  group('the five languages added to the detector', () {
    // These were offered by the preferred-audio ranking before the two lists
    // merged, and the ranking never needed a release-name pattern because it
    // reads a file's own track tags. As a *filter* the same key would have
    // hidden every source, so each one needs a pattern that fires.
    test('each is detected from a release name', () {
      expect(
        _source('Movie Arabic Dub 1080p').hasAudioLanguage('arabic'),
        isTrue,
      );
      expect(_source('Movie Chinese 1080p').hasAudioLanguage('chinese'), isTrue);
      expect(_source('Movie Korean 1080p').hasAudioLanguage('korean'), isTrue);
      expect(
        _source('Movie Portuguese 1080p').hasAudioLanguage('portuguese'),
        isTrue,
      );
      expect(_source('Movie Turkish 1080p').hasAudioLanguage('turkish'), isTrue);
    });

    test('a subtitle listing does not read as an audio language', () {
      // The detector strips "subs: ..." listings before matching, so a
      // release that only *subtitles* Korean must not match a Korean filter.
      final s = _source('Movie 1080p\nSubs: Korean, Arabic');
      expect(s.hasAudioLanguage('korean'), isFalse);
      expect(s.hasAudioLanguage('arabic'), isFalse);
    });

    test('every offered key is one the detector can look for', () {
      // The invariant that keeps the merged list honest: a key with no
      // pattern would filter the list down to nothing.
      for (final key in kAudioFilterKeys) {
        final s = _source('Movie $key 1080p');
        expect(
          s.hasAudioLanguage(key),
          isTrue,
          reason: '$key is offered but not detectable',
        );
      }
    });
  });

  group('preferredAudioTrackIndex', () {
    test('an empty ranking never overrides the file default', () {
      expect(preferredAudioTrackIndex(['eng', 'spa']), isNull);
    });

    test('walks the ranking in priority order, not track order', () {
      SourceFilterSettings.audioLanguages.value = const [
        'spanish',
        'english',
      ];
      // English comes first in the file; Spanish is ranked higher.
      expect(preferredAudioTrackIndex(['eng', 'spa']), 1);
    });

    test('falls through to the next ranked language when absent', () {
      SourceFilterSettings.audioLanguages.value = const [
        'spanish',
        'english',
      ];
      expect(preferredAudioTrackIndex(['eng', 'fre']), 0);
    });

    test('null when no track carries a ranked language', () {
      SourceFilterSettings.audioLanguages.value = const ['japanese'];
      expect(preferredAudioTrackIndex(['eng', 'spa']), isNull);
    });

    test('matches a full language name, not only an ISO code', () {
      SourceFilterSettings.audioLanguages.value = const ['english'];
      expect(preferredAudioTrackIndex(['Spanish', 'English']), 1);
    });

    test('a track with no language tag is skipped, not matched', () {
      SourceFilterSettings.audioLanguages.value = const ['english'];
      expect(preferredAudioTrackIndex([null, 'eng']), 1);
    });
  });

  group('audio list persistence', () {
    test('toggle adds to the end, and toggling again removes', () async {
      await SourceFilterSettings.toggleAudioLanguage('spanish');
      await SourceFilterSettings.toggleAudioLanguage('english');
      expect(SourceFilterSettings.audioLanguages.value, ['spanish', 'english']);

      await SourceFilterSettings.toggleAudioLanguage('spanish');
      expect(SourceFilterSettings.audioLanguages.value, ['english']);
    });

    test('promote and demote move one place and clamp at the ends', () async {
      SourceFilterSettings.audioLanguages.value = const [
        'english',
        'spanish',
        'french',
      ];

      await SourceFilterSettings.promoteAudioLanguage('spanish');
      expect(SourceFilterSettings.audioLanguages.value, [
        'spanish',
        'english',
        'french',
      ]);

      await SourceFilterSettings.demoteAudioLanguage('spanish');
      expect(SourceFilterSettings.audioLanguages.value, [
        'english',
        'spanish',
        'french',
      ]);

      // At the ends, both are no-ops rather than wrapping.
      await SourceFilterSettings.promoteAudioLanguage('english');
      await SourceFilterSettings.demoteAudioLanguage('french');
      expect(SourceFilterSettings.audioLanguages.value, [
        'english',
        'spanish',
        'french',
      ]);
    });

    test('the list survives a fresh initialize', () async {
      await SourceFilterSettings.toggleAudioLanguage('japanese');
      await SourceFilterSettings.toggleAudioLanguage('english');

      SourceFilterSettings.audioLanguages.value = const <String>[];
      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, [
        'japanese',
        'english',
      ]);
    });

    test('a stored language this build does not know is dropped', () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': ['english', 'klingon'],
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, ['english']);
    });

    test('an unknown key passed to a toggle is not stored', () async {
      await SourceFilterSettings.toggleAudioLanguage('klingon');

      expect(SourceFilterSettings.audioLanguages.value, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('source_filter_audio_language'), isNull);
    });
  });

  group('quality list persistence', () {
    test('toggle adds and removes, and the list survives a reload', () async {
      await SourceFilterSettings.toggleQuality('1080p');
      await SourceFilterSettings.toggleQuality('720p');
      expect(SourceFilterSettings.qualities.value, ['1080p', '720p']);

      SourceFilterSettings.qualities.value = const <String>[];
      await SourceFilterSettings.initialize();
      expect(SourceFilterSettings.qualities.value, ['1080p', '720p']);

      await SourceFilterSettings.toggleQuality('1080p');
      expect(SourceFilterSettings.qualities.value, ['720p']);
    });

    test('an unknown key passed to a toggle is not stored', () async {
      await SourceFilterSettings.toggleQuality('9000p');

      expect(SourceFilterSettings.qualities.value, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('source_filter_quality'), isNull);
    });
  });

  group('migration from the single-value keys', () {
    // The previous build stored one string per filter. A viewer who had
    // picked Spanish should not have to pick it again after updating.
    test('a stored single audio language becomes a one-item list', () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': 'spanish',
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, ['spanish']);
    });

    test('a stored single quality becomes a one-item list', () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_quality': '1080p',
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.qualities.value, ['1080p']);
    });

    test("the old 'all' sentinel migrates to an empty list", () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': 'all',
        'source_filter_quality': 'all',
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, isEmpty);
      expect(SourceFilterSettings.qualities.value, isEmpty);
    });

    test('the old ranking is folded into the audio list, after the filter', () async {
      // The ranking was its own key and its own list. It is the same list
      // now, so a language that was ranked but not filtered on still belongs
      // in it -- and appending keeps the ranking's own order intact.
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': 'english',
        'source_preferred_audio_languages': ['japanese', 'english'],
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, [
        'english',
        'japanese',
      ]);
    });

    test('a language in both the filter and the ranking is not duplicated', () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': 'english',
        'source_preferred_audio_languages': ['english', 'japanese'],
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, [
        'english',
        'japanese',
      ]);
    });

    test('a new-style list wins over a stale single value', () async {
      // Both keys present: the list is what this build writes, so it is the
      // one that is current.
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': ['french'],
        'source_preferred_audio_languages': ['japanese'],
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguages.value, ['french', 'japanese']);
    });
  });

  group('clearFilters and reset', () {
    test('clearFilters empties both lists', () async {
      SourceFilterSettings.audioLanguages.value = const ['spanish'];
      SourceFilterSettings.qualities.value = const ['1080p'];

      await SourceFilterSettings.clearFilters();

      expect(SourceFilterSettings.audioLanguages.value, isEmpty);
      expect(SourceFilterSettings.qualities.value, isEmpty);
    });

    test('reset clears the values and what was stored', () async {
      await SourceFilterSettings.toggleAudioLanguage('german');
      await SourceFilterSettings.toggleQuality('720p');

      await SourceFilterSettings.reset();

      expect(SourceFilterSettings.audioLanguages.value, isEmpty);
      expect(SourceFilterSettings.qualities.value, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('source_filter_audio_language'), isNull);
      expect(prefs.getStringList('source_filter_quality'), isNull);
      expect(prefs.getStringList('source_preferred_audio_languages'), isNull);
    });
  });

  group('StreamSource.hasQuality', () {
    test("'all' matches everything, including a source with no resolution", () {
      expect(_source('Some stream').hasQuality('all'), isTrue);
    });

    test('matches the detected resolution exactly', () {
      expect(_source('Movie 1080p WEB-DL').hasQuality('1080p'), isTrue);
      expect(_source('Movie 1080p WEB-DL').hasQuality('720p'), isFalse);
    });

    test('4K covers 2160, 4k and uhd alike', () {
      for (final tag in ['2160p', '4K', 'UHD']) {
        expect(
          _source('Movie $tag HDR').hasQuality('4K'),
          isTrue,
          reason: '$tag should read as 4K',
        );
      }
    });

    test('a source with no resolution never matches a specific quality', () {
      // Exact match, not "at least": an unknown resolution is not quietly
      // treated as 480p.
      final s = _source('Some stream');
      expect(s.quality, isNull);
      for (final key in kQualityFilterKeys) {
        expect(s.hasQuality(key), isFalse);
      }
    });
  });
}