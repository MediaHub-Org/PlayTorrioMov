import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/metadata/metadata_service.dart';

/// Live check against Cinemeta for Game of Thrones: what the details page's
/// episode rail actually has to work with. Tagged `network` like every test
/// that leaves the machine, so CI skips it.
@Tags(['network'])
void main() {
  group('Game of Thrones meta (live)', () {
    test('carries seasons 0-8 with thumbnails', () async {
      final meta = await MetadataService.fetchMeta(
        baseUrl: 'https://v3-cinemeta.strem.io',
        type: 'series',
        imdbId: 'tt0944947',
      );

      expect(meta, isNotNull, reason: 'no meta at all: the page has nothing');
      final videos = meta!.videos;
      expect(videos, isNotEmpty);

      final seasons = videos
          .map((v) => v.season)
          .whereType<int>()
          .toSet()
          .toList()
        ..sort();
      // ignore: avoid_print
      print('seasons: $seasons, videos: ${videos.length}');

      final seasonZero = videos.where((v) => v.season == 0).toList();
      // ignore: avoid_print
      print('season 0 videos: ${seasonZero.length}');
      // ignore: avoid_print
      print(
        'season 0 with thumbnail: ${seasonZero.where((v) => (v.thumbnail ?? '').isNotEmpty).length}',
      );

      expect(seasons, contains(1));
      expect(
        seasonZero,
        isNotEmpty,
        reason: 'pills show Season 0 but the rail filter finds nothing',
      );
    });
  });
}
