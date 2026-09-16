// test/models/subtitle_variant_classification_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';

SubtitleVariant v(String title, {bool? hi, bool? forced}) => SubtitleVariant(
  providerName: 'Test',
  language: 'English',
  title: title,
  downloadUrl: 'https://example.invalid/${title.hashCode}.srt',
  format: 'srt',
  isHearingImpaired: hi,
  isForced: forced,
);

void main() {
  group('SubtitleVariant classification', () {
    // The picker's HI/CC and Forced filters were dead: they sniffed the
    // title at render time for words like "SDH" and "forced", but the one
    // provider that marks hearing-impaired tracks directly (Wyzie) put its
    // flag in a separate field the model never carried. The flag now lives
    // on the variant, so the filter and the row badges read the same source.

    test('a provider flag wins over whatever the title says', () {
      expect(v('Plain release', hi: true).isHearingImpaired, isTrue);
      // "White.House" contains "HI" as a substring; a provider flag of
      // false must survive that.
      expect(v('White.House', hi: false).isHearingImpaired, isFalse);
    });

    test('falls back to the title when the provider says nothing', () {
      expect(v('Release [CC]').isHearingImpaired, isTrue);
      expect(v('Release SDH').isHearingImpaired, isTrue);
      expect(v('Release forced').isForced, isTrue);
      expect(v('Release Forced').isForced, isTrue);
    });

    test('title sniffing is word-boundary, not substring', () {
      // "White.House" and "Childhood" both contain "hi"; neither is a
      // hearing-impaired marker. This is the bug the old code had.
      expect(v('White.House').isHearingImpaired, isFalse);
      expect(v('Childhood').isHearingImpaired, isFalse);
      expect(v('Thirteen').isForced, isFalse);
    });

    test('an ordinary release name is neither', () {
      final plain = v('Movie.2023.1080p.WEB-DL.DD5.1.H.264');
      expect(plain.isHearingImpaired, isFalse);
      expect(plain.isForced, isFalse);
    });
  });
}
