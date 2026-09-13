import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/cast/cast_service.dart';

void main() {
  group('CastService.contentTypeFor', () {
    test('HLS and DASH playlists are named as playlists', () {
      // The receiver picks its demuxer from this; a playlist announced as
      // mp4 does not play.
      expect(
        CastService.contentTypeFor('https://x.invalid/stream.m3u8'),
        'application/x-mpegurl',
      );
      expect(
        CastService.contentTypeFor('https://x.invalid/manifest.mpd'),
        'application/dash+xml',
      );
    });

    test('a transport stream is mp2t, not mp4', () {
      // IPTV portals serve MPEG-TS constantly, and this only started
      // mattering when Live TV gained a cast button.
      expect(
        CastService.contentTypeFor('http://portal.invalid/live/1234.ts'),
        'video/mp2t',
      );
    });

    test('matroska is named', () {
      expect(
        CastService.contentTypeFor('https://x.invalid/movie.mkv'),
        'video/x-matroska',
      );
    });

    test('anything else falls back to mp4', () {
      // Most scraper sources are progressive MP4, named or not.
      expect(CastService.contentTypeFor('https://x.invalid/a.mp4'), 'video/mp4');
      expect(CastService.contentTypeFor('https://x.invalid/no-extension'),
          'video/mp4');
    });

    test('the query string is read too', () {
      // Portal URLs routinely carry the real extension in a parameter
      // rather than the path.
      expect(
        CastService.contentTypeFor('http://p.invalid/get?file=x&ext=.m3u8'),
        'application/x-mpegurl',
      );
    });

    test('case does not matter', () {
      expect(
        CastService.contentTypeFor('https://X.invalid/STREAM.M3U8'),
        'application/x-mpegurl',
      );
    });
  });
}
