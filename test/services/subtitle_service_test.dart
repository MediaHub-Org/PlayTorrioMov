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
    test('keeps regional variants as separate groups', () {
      // These used to collapse to the parent language. They are different
      // recordings -- a viewer who wants Spanish (LATAM) does not want
      // Spanish (ES) -- so collapsing them hid the choice rather than
      // simplifying it.
      expect(canonicalLanguageGroup('Spanish'), 'Spanish');
      expect(canonicalLanguageGroup('Spanish (ES)'), 'Spanish (ES)');
      expect(canonicalLanguageGroup('Spanish (LATAM)'), 'Spanish (LATAM)');
      expect(canonicalLanguageGroup('Portuguese (BR)'), 'Portuguese (BR)');
      expect(canonicalLanguageGroup('Portuguese (PT)'), 'Portuguese (PT)');
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
    test('the same title from two providers is two choices', () {
      // It used to collapse to one, on the theory that the same subtitle
      // from two providers is one choice. But they are different downloads
      // from different hosts, and the survivor was whichever answered first
      // -- so a SubtitleCat file could be dropped in favour of an
      // OpenSubtitles one with no way to tell. The provider is part of the
      // identity; what the viewer sees repeated is one provider's own rows.
      final deduped = dedupe(
        [
          variant(provider: 'Wyzie', language: 'English', title: 'Standard'),
          variant(provider: 'OpenSubtitles', language: 'eng', title: 'Standard'),
        ],
        'Some Movie',
      );

      expect(deduped.length, 2);
      expect(
        deduped.map((v) => v.providerName),
        containsAll(['Wyzie', 'OpenSubtitles']),
      );
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

    test('two providers offering the same title are two choices', () {
      // The provider is part of the identity. Without it the survivor was
      // whichever answered first, so a SubtitleCat file could be dropped in
      // favour of an OpenSubtitles one with no way to tell.
      final deduped = dedupe(
        [
          variant(provider: 'SubtitleCat', language: 'English', title: 'Standard'),
          variant(provider: 'OpenSubtitles', language: 'English', title: 'Standard'),
        ],
        'Some Movie',
      );

      expect(deduped.length, 2);
      expect(
        deduped.map((v) => v.providerName),
        containsAll(['SubtitleCat', 'OpenSubtitles']),
      );
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

  group('dedupeVariants', () {
    test('collapses the same file offered twice by one provider', () {
      // SubtitleCat lists a file once per language it has been translated
      // into, and the translations share a title *and* a URL. Those are one
      // choice, not four.
      final collapsed = SubtitleService.dedupeVariants([
        variant(
          provider: 'SubtitleCat',
          language: 'English',
          title: 'Standard',
          url: 'https://x/same.srt',
        ),
        variant(
          provider: 'SubtitleCat',
          language: 'English',
          title: 'Standard',
          url: 'https://x/same.srt',
        ),
        variant(
          provider: 'SubtitleCat',
          language: 'English',
          title: 'Standard',
          url: 'https://x/same.srt',
        ),
      ]);

      expect(collapsed.length, 1);
    });

    test('numbers what is left when the names are identical', () {
      // Four rows reading "SubtitleCat" give a viewer nothing to choose
      // between them by.
      final numbered = SubtitleService.dedupeVariants([
        variant(
          provider: 'SubtitleCat',
          language: 'English',
          title: 'Standard',
          url: 'https://x/1.srt',
        ),
        variant(
          provider: 'SubtitleCat',
          language: 'English',
          title: 'Standard',
          url: 'https://x/2.srt',
        ),
      ]);

      expect(numbered.map((v) => v.title), ['Standard #1', 'Standard #2']);
    });

    test('leaves distinct titles alone', () {
      final kept = SubtitleService.dedupeVariants([
        variant(provider: 'SubDL', language: 'English', title: 'BluRay'),
        variant(provider: 'SubDL', language: 'English', title: 'WEB-DL'),
      ]);

      expect(kept.map((v) => v.title), ['BluRay', 'WEB-DL']);
    });

    test('a different format is a different file', () {
      final kept = SubtitleService.dedupeVariants([
        variant(provider: 'SubDL', language: 'English', title: 'Standard'),
        SubtitleVariant(
          providerName: 'SubDL',
          language: 'English',
          title: 'Standard',
          downloadUrl: 'https://x/2.vtt',
          format: 'vtt',
        ),
      ]);

      expect(kept.length, 2);
    });

    test('numbering does not leak across providers', () {
      // Each provider's own duplicates are numbered from one, so two
      // providers each offering one file do not become "#1" and "#2".
      final kept = SubtitleService.dedupeVariants([
        variant(provider: 'SubtitleCat', language: 'English', title: 'Standard'),
        variant(provider: 'OpenSubtitles', language: 'English', title: 'Standard'),
      ]);

      expect(kept.map((v) => v.title), ['Standard', 'Standard']);
    });
  });
}
