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
    SourceFilterSettings.audioLanguage.value = 'all';
    SourceFilterSettings.quality.value = 'all';
    SourceFilterSettings.preferredAudioLanguages.value = const <String>[];
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

  group('preferredAudioTrackIndex', () {
    test('an empty ranking never overrides the file default', () {
      expect(preferredAudioTrackIndex(['eng', 'spa']), isNull);
    });

    test('walks the ranking in priority order, not track order', () {
      SourceFilterSettings.preferredAudioLanguages.value = const [
        'spanish',
        'english',
      ];
      // English comes first in the file; Spanish is ranked higher.
      expect(preferredAudioTrackIndex(['eng', 'spa']), 1);
    });

    test('falls through to the next ranked language when absent', () {
      SourceFilterSettings.preferredAudioLanguages.value = const [
        'spanish',
        'english',
      ];
      expect(preferredAudioTrackIndex(['eng', 'fre']), 0);
    });

    test('null when no track carries a ranked language', () {
      SourceFilterSettings.preferredAudioLanguages.value = const ['japanese'];
      expect(preferredAudioTrackIndex(['eng', 'spa']), isNull);
    });

    test('matches a full language name, not only an ISO code', () {
      SourceFilterSettings.preferredAudioLanguages.value = const ['english'];
      expect(preferredAudioTrackIndex(['Spanish', 'English']), 1);
    });

    test('a track with no language tag is skipped, not matched', () {
      SourceFilterSettings.preferredAudioLanguages.value = const ['english'];
      expect(preferredAudioTrackIndex([null, 'eng']), 1);
    });
  });

  group('preferred audio ranking persistence', () {
    test('toggle adds to the end, and toggling again removes', () async {
      await SourceFilterSettings.togglePreferredAudio('spanish');
      await SourceFilterSettings.togglePreferredAudio('english');
      expect(SourceFilterSettings.preferredAudioLanguages.value,
          ['spanish', 'english']);

      await SourceFilterSettings.togglePreferredAudio('spanish');
      expect(SourceFilterSettings.preferredAudioLanguages.value, ['english']);
    });

    test('promote and demote move one place and clamp at the ends', () async {
      SourceFilterSettings.preferredAudioLanguages.value = const [
        'english',
        'spanish',
        'french',
      ];

      await SourceFilterSettings.promotePreferredAudio('spanish');
      expect(SourceFilterSettings.preferredAudioLanguages.value,
          ['spanish', 'english', 'french']);

      await SourceFilterSettings.demotePreferredAudio('spanish');
      expect(SourceFilterSettings.preferredAudioLanguages.value,
          ['english', 'spanish', 'french']);

      // At the ends, both are no-ops rather than wrapping.
      await SourceFilterSettings.promotePreferredAudio('english');
      await SourceFilterSettings.demotePreferredAudio('french');
      expect(SourceFilterSettings.preferredAudioLanguages.value,
          ['english', 'spanish', 'french']);
    });

    test('the ranking survives a fresh initialize', () async {
      await SourceFilterSettings.togglePreferredAudio('japanese');
      await SourceFilterSettings.togglePreferredAudio('english');

      SourceFilterSettings.preferredAudioLanguages.value = const <String>[];
      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.preferredAudioLanguages.value,
          ['japanese', 'english']);
    });

    test('a stored language this build does not know is dropped', () async {
      SharedPreferences.setMockInitialValues({
        'source_preferred_audio_languages': ['english', 'klingon'],
      });

      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.preferredAudioLanguages.value, ['english']);
    });

    test('clearFilters leaves the ranking alone', () async {
      SourceFilterSettings.preferredAudioLanguages.value = const ['spanish'];
      await SourceFilterSettings.setAudioLanguage('spanish');

      await SourceFilterSettings.clearFilters();

      expect(SourceFilterSettings.audioLanguage.value, 'all');
      // Not a filter that can empty a list, so "clear filters" must not
      // silently discard it.
      expect(SourceFilterSettings.preferredAudioLanguages.value, ['spanish']);
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
        expect(_source('Movie $tag HDR').hasQuality('4K'), isTrue,
            reason: '$tag should read as 4K');
      }
    });

    test('a source with no resolution never matches a specific quality', () {
      // Exact match, not "at least": an unknown resolution is not quietly
      // treated as 480p.
      final s = _source('Some stream');
      expect(s.quality, isNull);
      for (final key in kQualityFilterKeys.where((k) => k != 'all')) {
        expect(s.hasQuality(key), isFalse);
      }
    });
  });

  group('SourceFilterSettings persistence', () {
    test('a saved value is restored on the next initialize', () async {
      await SourceFilterSettings.setAudioLanguage('spanish');
      await SourceFilterSettings.setQuality('1080p');

      // Simulate a fresh launch: the in-memory notifiers reset, the prefs
      // stay.
      SourceFilterSettings.audioLanguage.value = 'all';
      SourceFilterSettings.quality.value = 'all';
      await SourceFilterSettings.initialize();

      expect(SourceFilterSettings.audioLanguage.value, 'spanish');
      expect(SourceFilterSettings.quality.value, '1080p');
    });

    test('an unknown stored key is ignored, not applied', () async {
      SharedPreferences.setMockInitialValues({
        'source_filter_audio_language': 'klingon',
        'source_filter_quality': '9000p',
      });

      await SourceFilterSettings.initialize();

      // Applying these would filter the source list to nothing with no
      // dropdown entry able to explain why.
      expect(SourceFilterSettings.audioLanguage.value, 'all');
      expect(SourceFilterSettings.quality.value, 'all');
    });

    test('reset clears both the value and what was stored', () async {
      await SourceFilterSettings.setAudioLanguage('german');
      await SourceFilterSettings.setQuality('720p');

      await SourceFilterSettings.reset();

      expect(SourceFilterSettings.audioLanguage.value, 'all');
      expect(SourceFilterSettings.quality.value, 'all');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('source_filter_audio_language'), isNull);
      expect(prefs.getString('source_filter_quality'), isNull);
    });

    test('an unknown key passed to a setter is not stored', () async {
      await SourceFilterSettings.setQuality('9000p');

      expect(SourceFilterSettings.quality.value, 'all');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('source_filter_quality'), isNull);
    });
  });
}