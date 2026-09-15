import 'dart:io';

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

  group('CastService.canCastUrl', () {
    test('a public http(s) stream is castable', () {
      expect(CastService.canCastUrl('https://cdn.example.com/a.mp4'), isTrue);
      expect(CastService.canCastUrl('http://203.0.113.9:8090/stream'), isTrue);
    });

    test('a torrent source on another machine is castable', () {
      // The old test was "is this a torrent", which hid the Cast button on
      // most of this app's sources. A torrent that resolves through a
      // debrid or a torrent server elsewhere on the network is as fetchable
      // by a receiver as any other URL.
      expect(
        CastService.canCastUrl('http://192.168.1.40:8090/stream?link=abc'),
        isTrue,
      );
      expect(
        CastService.canCastUrl('https://debrid.example.net/dl/abc.mkv'),
        isTrue,
      );
    });

    test('loopback is not castable -- the receiver is a separate box', () {
      expect(CastService.canCastUrl('http://127.0.0.1:8090/stream'), isFalse);
      expect(CastService.canCastUrl('http://localhost:9000/v/x.mp4'), isFalse);
    });

    test('the whole 127/8 block is loopback, not just 127.0.0.1', () {
      // Media servers bind to 127.0.0.2 and friends often enough to matter.
      expect(CastService.canCastUrl('http://127.0.0.2:8090/s'), isFalse);
      expect(CastService.canCastUrl('http://127.53.1.9/s'), isFalse);
    });

    test('a local file has no URL a receiver could open', () {
      expect(CastService.canCastUrl('file:///storage/emulated/0/a.mp4'), isFalse);
      expect(CastService.canCastUrl('/storage/emulated/0/a.mp4'), isFalse);
    });

    test('nothing at all is not castable', () {
      expect(CastService.canCastUrl(null), isFalse);
      expect(CastService.canCastUrl(''), isFalse);
    });

    test('a non-http scheme is not castable', () {
      expect(CastService.canCastUrl('magnet:?xt=urn:btih:abc'), isFalse);
      expect(CastService.canCastUrl('rtsp://example.com/live'), isFalse);
    });
  });

  group('the device picker starts discovery', () {
    // The bug this pins: `devicesStream` is a stream the plugin never feeds
    // until something calls `startDiscovery`. Nothing did. On Android the
    // native `onAttachedToEngine` only wires the method channel -- the
    // `MediaRouter.addCallback` that actually scans lives solely inside the
    // native `startDiscovery`, reachable only from Dart -- and iOS is the
    // same through `GCKDiscoveryManager`. So the sheet sat on "Looking for
    // Cast devices..." forever and Cast appeared to be broken.
    //
    // A source scan rather than a widget test because the widget cannot be
    // pumped here: touching `CastService` on a desktop host instantiates a
    // platform channel that does not exist. What matters is that the call is
    // present and paired.
    final sheet = File('lib/widgets/player/player_cast_sheet.dart')
        .readAsStringSync();

    test('the sheet asks the plugin to scan when it opens', () {
      expect(
        sheet.contains('CastService.startDiscovery()'),
        isTrue,
        reason: 'Without this the device list is empty forever.',
      );
    });

    test('and stops scanning when it closes', () {
      // Scanning holds the radio awake; a session already started does not
      // need discovery still running.
      expect(
        sheet.contains('CastService.stopDiscovery()'),
        isTrue,
        reason: 'Discovery left running drains the battery.',
      );
    });

    test('both are wired to the sheet lifecycle, not a build method', () {
      // In build() they would re-fire on every rebuild of the stream.
      expect(sheet.contains('void initState()'), isTrue);
      expect(sheet.contains('void dispose()'), isTrue);
    });
  });
}
