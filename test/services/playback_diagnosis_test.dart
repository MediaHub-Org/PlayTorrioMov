// Slow playback has two different causes that need different fixes: a link
// that cannot carry the file, and a device that cannot decode it. The verdict
// is what tells them apart.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/playback_diagnosis.dart';

void main() {
  test('nothing known yet is unknown, not healthy', () {
    expect(diagnose().verdict, PlaybackVerdict.unknown);
  });

  group('the link', () {
    test('a starved cache fed less than the video needs is the link', () {
      final d = diagnose(needKbps: 18000, haveKbps: 9000, bufferedSeconds: 2);
      expect(d.verdict, PlaybackVerdict.linkTooSlow);
      expect(d.needKbps, 18000);
      expect(d.haveKbps, 9000);
    });

    test('bare equality is still too slow: there is no headroom', () {
      final d = diagnose(needKbps: 10000, haveKbps: 10500, bufferedSeconds: 2);
      expect(d.verdict, PlaybackVerdict.linkTooSlow);
    });

    test('a full cache says nothing about the link, however low the rate', () {
      // The player stopped asking: the fill rate falls to nothing when there
      // is nothing left to fetch.
      final d = diagnose(needKbps: 18000, haveKbps: 100, bufferedSeconds: 40);
      expect(d.verdict, PlaybackVerdict.healthy);
    });

    test('a starved cache with a fast link is not the link', () {
      final d = diagnose(needKbps: 8000, haveKbps: 30000, bufferedSeconds: 2);
      expect(d.verdict, PlaybackVerdict.healthy);
    });

    test('without a bitrate to compare there is no verdict on the link', () {
      final d = diagnose(haveKbps: 500, bufferedSeconds: 1);
      expect(d.verdict, PlaybackVerdict.healthy);
    });
  });

  group('the decoder', () {
    test('frames dropped with a healthy cache are the device', () {
      final d = diagnose(
        needKbps: 8000,
        haveKbps: 30000,
        bufferedSeconds: 30,
        droppedRecently: 40,
      );
      expect(d.verdict, PlaybackVerdict.decoderStruggling);
    });

    test('a few dropped frames are noise', () {
      final d = diagnose(bufferedSeconds: 30, droppedRecently: 3);
      expect(d.verdict, PlaybackVerdict.healthy);
    });

    test('frames dropped while starved are blamed on the link, not the device',
        () {
      final d = diagnose(
        needKbps: 18000,
        haveKbps: 6000,
        bufferedSeconds: 1,
        droppedRecently: 60,
      );
      expect(d.verdict, PlaybackVerdict.linkTooSlow);
    });
  });
}
