import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';

PlayerEmbeddedSubtitle track(
  int index, {
  String? language,
  String title = '',
  bool isDefault = false,
}) => PlayerEmbeddedSubtitle(
  index: index,
  title: title,
  language: language,
  isDefault: isDefault,
);

SubtitleVariant variant(String language) => SubtitleVariant(
  providerName: 'Test',
  language: language,
  title: '$language subtitle',
  downloadUrl: 'https://example.invalid/$language.srt',
  format: 'srt',
);

void main() {
  group('SubtitleAutoPick.embedded', () {
    test('no tracks means no answer', () {
      expect(SubtitleAutoPick.embedded([]), isNull);
    });

    test("the file's own default wins", () {
      // The closest thing to an authored answer about which track belongs
      // to this release.
      final picked = SubtitleAutoPick.embedded([
        track(0, language: 'eng'),
        track(1, language: 'spa', isDefault: true),
      ]);

      expect(picked!.index, 1);
    });

    test('English comes next when nothing is marked default', () {
      final picked = SubtitleAutoPick.embedded([
        track(0, language: 'fre'),
        track(1, language: 'eng'),
        track(2, language: 'ger'),
      ]);

      expect(picked!.index, 1);
    });

    test('English is recognised however it is spelled', () {
      for (final spelling in ['en', 'eng', 'English', 'en-US', 'en_GB']) {
        final picked = SubtitleAutoPick.embedded([
          track(0, language: 'jpn'),
          track(1, language: spelling),
        ]);
        expect(picked!.index, 1, reason: 'should match "$spelling"');
      }
    });

    test('a language merely containing those letters is not English', () {
      // Without this, the first of these wins on a naive `contains('en')`.
      final picked = SubtitleAutoPick.embedded([
        track(0, language: 'slovenian'),
        track(1, language: 'eng'),
      ]);

      expect(picked!.index, 1);
    });

    test('the title is read when the language field is empty', () {
      final picked = SubtitleAutoPick.embedded([
        track(0, language: null, title: 'Deutsch'),
        track(1, language: null, title: 'English (SDH)'),
      ]);

      expect(picked!.index, 1);
    });

    test('failing everything, the first track still turns on', () {
      // A subtitle in the wrong language is a better answer to "turn
      // subtitles on" than nothing happening.
      final picked = SubtitleAutoPick.embedded([
        track(3, language: 'jpn'),
        track(4, language: 'kor'),
      ]);

      expect(picked!.index, 3);
    });
  });

  group('SubtitleAutoPick.variant', () {
    test('no groups means no answer', () {
      expect(SubtitleAutoPick.variant([]), isNull);
    });

    test('English is preferred', () {
      final picked = SubtitleAutoPick.variant([
        SubtitleLanguageGroup(language: 'Spanish', variants: [variant('es')]),
        SubtitleLanguageGroup(language: 'English', variants: [variant('en')]),
      ]);

      expect(picked!.language, 'en');
    });

    test('any language beats none', () {
      final picked = SubtitleAutoPick.variant([
        SubtitleLanguageGroup(language: 'Japanese', variants: [variant('ja')]),
      ]);

      expect(picked!.language, 'ja');
    });

    test('an empty group is skipped rather than picked', () {
      final picked = SubtitleAutoPick.variant([
        SubtitleLanguageGroup(language: 'English', variants: []),
        SubtitleLanguageGroup(language: 'Italian', variants: [variant('it')]),
      ]);

      expect(picked!.language, 'it');
    });
  });
}
