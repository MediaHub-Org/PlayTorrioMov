// The source list opens on what will play, not on what answered first:
// in the viewer's language, at a size the connection carries, then by quality
// tier and seeders. Nothing is ever hidden by it.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/player/video_quality_preference.dart';
import 'package:playtorriomov/services/sources/source_ranking.dart';

StreamSource source(String title) =>
    StreamSource(title: title, addonName: 'test');

List<String> titles(List<StreamSource> list) =>
    list.map((s) => s.title!).toList();

void main() {
  group('language comes first, and only orders', () {
    final english4k = source('Movie 2160p English');
    final spanish720 = source('Movie 720p Spanish');
    final multi1080 = source('Movie 1080p MULTI');
    final untagged = source('Movie 1080p');

    test('a release in the preferred language leads a better-looking one', () {
      final ranked = rankSources(
        [english4k, multi1080, spanish720],
        tier: VideoQualityTier.best,
        preferredAudio: const ['spanish'],
      );
      expect(titles(ranked), [
        'Movie 720p Spanish',
        'Movie 1080p MULTI',
        'Movie 2160p English',
      ]);
    });

    test('MULTI sits between a named match and the rest', () {
      final ranked = rankSources(
        [english4k, multi1080, spanish720],
        tier: VideoQualityTier.best,
        preferredAudio: const ['spanish'],
      );
      expect(ranked[1].title, contains('MULTI'),
          reason: 'it plausibly carries the dub but does not say so');
    });

    test('with no preference the order is the quality tier alone', () {
      final ranked = rankSources(
        [spanish720, untagged, english4k],
        tier: VideoQualityTier.best,
      );
      expect(titles(ranked).first, 'Movie 2160p English');
    });

    test('a ranked list is walked in order: first choice before second', () {
      final ranked = rankSources(
        [source('Movie 1080p English'), source('Movie 1080p German'),
         source('Movie 1080p Spanish')],
        tier: VideoQualityTier.best,
        preferredAudio: const ['german', 'spanish'],
      );
      expect(titles(ranked), [
        'Movie 1080p German',
        'Movie 1080p Spanish',
        'Movie 1080p English',
      ]);
    });

    test('never hides: every source comes back', () {
      final input = [english4k, multi1080, spanish720, untagged];
      final ranked = rankSources(
        input,
        tier: VideoQualityTier.good,
        preferredAudio: const ['spanish'],
        maxKbps: 1000,
      );
      expect(ranked.toSet(), input.toSet());
    });
  });

  group('weight', () {
    test('a release known to be too heavy goes behind the ones that fit', () {
      final heavy = source('Movie 2160p REMUX 60 Mbps');
      final fits = source('Movie 1080p WEB 8 Mbps');
      final ranked = rankSources(
        [heavy, fits],
        tier: VideoQualityTier.best,
        maxKbps: 15000,
      );
      expect(ranked.first, fits);
    });

    test('an unknown bitrate is not penalized', () {
      final unknown = source('Movie 2160p');
      final fits = source('Movie 1080p 8 Mbps');
      final ranked = rankSources(
        [fits, unknown],
        tier: VideoQualityTier.best,
        maxKbps: 15000,
      );
      expect(ranked.first, unknown, reason: 'no evidence it is too heavy');
    });

    test('no cap means weight is ignored', () {
      final heavy = source('Movie 2160p 60 Mbps');
      final light = source('Movie 1080p 8 Mbps');
      final ranked = rankSources([light, heavy], tier: VideoQualityTier.best);
      expect(ranked.first, heavy);
    });

    test('a size and a runtime stand in for a bitrate that is not stated', () {
      // 40 GB over 120 minutes is about 44 Mb/s.
      final remux = source('Movie 2160p REMUX 40 GB');
      final web = source('Movie 1080p WEB 4 GB');
      final ranked = rankSources(
        [remux, web],
        tier: VideoQualityTier.best,
        maxKbps: 15000,
        runtimeMinutes: 120,
      );
      expect(ranked.first, web);
    });
  });

  group('the rest', () {
    test('seeders break a tie, more first', () {
      final few = source('Movie 1080p 3 seeds');
      final many = source('Movie 1080p 250 seeds');
      final ranked = rankSources([few, many], tier: VideoQualityTier.best);
      expect(ranked.first, many);
    });

    test('equal sources keep their arrival order', () {
      final a = source('Movie 1080p A');
      final b = source('Movie 1080p B');
      final c = source('Movie 1080p C');
      expect(
        rankSources([a, b, c], tier: VideoQualityTier.best),
        [a, b, c],
      );
    });

    test('the tier still decides between equals on language and weight', () {
      final ranked = rankSources(
        [source('Movie 480p'), source('Movie 720p'), source('Movie 1080p')],
        tier: VideoQualityTier.good,
      );
      expect(titles(ranked).first, 'Movie 720p');
    });
  });
}
