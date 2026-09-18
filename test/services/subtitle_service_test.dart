// test/services/subtitle_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';
import 'package:playtorriomov/services/subtitles/subtitle_service.dart';

SubtitleVariant variant({
  required String provider,
  required String language,
  required String title,
  String url = 'https://example.com/a.srt',
  bool? hi,
  bool? forced,
  Map<String, dynamic> extra = const {},
}) =>
    SubtitleVariant(
      providerName: provider,
      language: language,
      title: title,
      downloadUrl: url,
      format: 'srt',
      isHearingImpaired: hi,
      isForced: forced,
      extraData: extra,
    );

/// Runs the service's own grouping + dedupe path over [variants], the same
/// way `fetchAllSubtitles` does once the providers have answered.
List<SubtitleVariant> dedupe(List<SubtitleVariant> variants, String movieName) {
  final seen = <String>{};
  final out = <SubtitleVariant>[];
  for (final v in variants) {
    final language = canonicalLanguageGroup(v.language);
    if (language.isEmpty) continue;
    final cleaned = SubtitleService.cleanVariant(v, movieName, language);
    final key = SubtitleService.variantKey(cleaned, language);
    if (!seen.add(key)) continue;
    out.add(cleaned);
  }
  return out;
}

void main() {
  // The service is the one place every provider's results converge, so the
  // presentation rules live here rather than in five scrapers that would
  // drift apart.
  group('language grouping', () {
    test('groups regional variants under the parent language', () {
      // "Spanish" and "Spanish (latam)" are one language to a viewer
      // choosing what to read; two groups made the language bar a row of
      // near-duplicates.
      expect(canonicalLanguageGroup('Spanish'), 'Spanish');
      expect(canonicalLanguageGroup('Spanish (latam)'), 'Spanish');
      expect(canonicalLanguageGroup('Portuguese (BR)'), 'Portuguese');
    });

    test('drops signs-only tracks instead of offering them as a language', () {
      expect(canonicalLanguageGroup('spl'), isEmpty);
    });

    test('keeps Chinese as one group across its scripts', () {
      expect(canonicalLanguageGroup('zhc'), 'Chinese');
      expect(canonicalLanguageGroup('zht'), 'Chinese');
      expect(canonicalLanguageGroup('Chinese'), 'Chinese');
    });
  });

  group('dedupe', () {
    test('collapses the same subtitle arriving from two providers', () {
      final deduped = dedupe(
        [
          variant(provider: 'Wyzie', language: 'English', title: 'Standard'),
          variant(provider: 'OpenSubtitles', language: 'eng', title: 'Standard'),
        ],
        'Some Movie',
      );

      expect(deduped.length, 1,
          reason: 'same language, same title, same flags is one choice');
    });

    test('keeps variants that differ in a meaningful way', () {
      final deduped = dedupe(
        [
          variant(provider: 'Wyzie', language: 'English', title: 'Standard'),
          variant(
              provider: 'Wyzie',
              language: 'English',
              title: 'Standard',
              hi: true),
          variant(
              provider: 'Wyzie',
              language: 'English',
              title: 'Standard',
              forced: true),
        ],
        'Some Movie',
      );

      expect(deduped.length, 3,
          reason: 'CC and forced are different tracks, not duplicates');
    });

    test('strips the media name from the title', () {
      final deduped = dedupe(
        [
          variant(
            provider: 'SubDL',
            language: 'English',
            title: 'The.Matrix.1999.1080p.BluRay.srt',
          ),
        ],
        'The Matrix',
      );

      expect(deduped.single.title.toLowerCase(), isNot(contains('matrix')));
    });

    test('falls back to a readable label when nothing is left', () {
      final deduped = dedupe(
        [
          variant(provider: 'Wyzie', language: 'English', title: 'English'),
        ],
        'Some Movie',
      );

      expect(deduped.single.title, 'Standard');
    });
  });
}
