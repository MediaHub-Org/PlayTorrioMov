import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_display.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';

SubtitleVariant _variant(
  String title, {
  String provider = 'OpenSubtitles',
  Map<String, dynamic> extra = const {},
}) => SubtitleVariant(
  providerName: provider,
  language: 'Arabic',
  title: title,
  downloadUrl: 'https://example.com/$title',
  format: 'srt',
  extraData: extra,
);

void main() {
  group('describeSubtitle', () {
    test('a bare OpenSubtitles id shows no title', () {
      expect(describeSubtitle(_variant('13628256')).title, isEmpty);
    });

    test('what is left of a SubtitleCat name once the movie is stripped', () {
      final d = describeSubtitle(_variant('t 2026 1080p -', provider: 'subtitlecat'));
      expect(d.title, isEmpty);
      expect(d.tags, ['1080p']);
      expect(d.provider, 'SubtitleCat');
    });

    test('the fallbacks the service writes are not names', () {
      for (final t in ['Standard', 'CC - Forced', 'Translated', 'Stremio Addon']) {
        expect(describeSubtitle(_variant(t)).title, isEmpty, reason: t);
      }
    });

    test('a release name survives, its quality moves to tags', () {
      final d = describeSubtitle(_variant('Dune.Part.Two.2024.1080p.WEB-DL.x264-GROUP.srt'));
      expect(d.tags, ['1080p', 'WEB-DL', 'x264']);
      expect(d.title, contains('GROUP'));
      expect(d.title, isNot(contains('1080p')));
    });

    test('auto-translated is a flag, not words in the title', () {
      final d = describeSubtitle(_variant('Arabic (Auto Translated)', extra: {'isTranslate': true}));
      expect(d.isTranslated, isTrue);
      expect(d.title, isNot(contains('Translated')));
    });

    test('downloads read from the provider extras', () {
      expect(describeSubtitle(_variant('x', extra: {'downloads': 1234})).downloads, 1234);
      expect(describeSubtitle(_variant('x')).downloads, isNull);
    });
  });

  group('numberedRowTitles', () {
    test('numbers rows that would look identical, and only those', () {
      final titles = numberedRowTitles([
        _variant('13624072'),
        _variant('13628256'),
        _variant('Dune.Part.Two-GRP'),
        _variant('13647914', provider: 'subtitlecat'),
      ], fallback: 'Standard');
      expect(titles, ['Standard #1', 'Standard #2', 'Dune Part Two-GRP', 'Standard']);
    });
  });

  test('compactCount abbreviates', () {
    expect(compactCount(34), '34');
    expect(compactCount(1234), '1.2k');
    expect(compactCount(15000), '15k');
    expect(compactCount(2500000), '2.5M');
  });
}
