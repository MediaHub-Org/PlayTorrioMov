// When playback is going badly the app should notice, in three ways: learn
// what the link carries, learn when it carries more than it was thought to,
// and say so when the picture keeps stopping. The thresholds are what keep
// a single hiccup from being any of those.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/playback_health.dart';

class Harness {
  final slow = <int>[];
  var smooth = 0;
  var offers = 0;
  late final PlaybackHealth health = PlaybackHealth(
    onSlowLink: slow.add,
    onSmooth: () => smooth++,
    onRepeatedStalls: () => offers++,
  );
  DateTime clock = DateTime(2026, 1, 1);

  void play(int seconds) {
    for (var i = 0; i < seconds; i++) {
      clock = clock.add(const Duration(seconds: 1));
      health.tick(isBuffering: false, observedKbps: 500, now: clock);
    }
  }

  /// A stall of [seconds], downloading at [kbps] throughout.
  void stall(int seconds, {int kbps = 3000}) {
    for (var i = 0; i < seconds; i++) {
      clock = clock.add(const Duration(seconds: 1));
      health.tick(isBuffering: true, observedKbps: kbps, now: clock);
    }
    // The tick that ends it.
    clock = clock.add(const Duration(seconds: 1));
    health.tick(isBuffering: false, observedKbps: 0, now: clock);
  }
}

void main() {
  test('a long starved wait reports the rate the link delivered', () {
    final h = Harness()..play(5);
    h.stall(8, kbps: 3000);

    expect(h.slow, [3000]);
  });

  test('the median is reported, so one burst does not decide', () {
    final h = Harness()..play(5);
    for (final kbps in [2000, 2200, 40000, 2100, 2300, 2150]) {
      h.clock = h.clock.add(const Duration(seconds: 1));
      h.health.tick(isBuffering: true, observedKbps: kbps, now: h.clock);
    }
    h.clock = h.clock.add(const Duration(seconds: 1));
    h.health.tick(isBuffering: false, observedKbps: 0, now: h.clock);

    expect(h.slow.single, lessThan(3000));
  });

  test('a short dip is the cache doing its job, not the link', () {
    final h = Harness()..play(5);
    h.stall(2);

    expect(h.slow, isEmpty);
  });

  test('a stall with no readings teaches nothing', () {
    final h = Harness()..play(5);
    for (var i = 0; i < 6; i++) {
      h.clock = h.clock.add(const Duration(seconds: 1));
      h.health.tick(isBuffering: true, observedKbps: null, now: h.clock);
    }
    h.clock = h.clock.add(const Duration(seconds: 1));
    h.health.tick(isBuffering: false, observedKbps: null, now: h.clock);

    expect(h.slow, isEmpty);
  });

  group('smooth playback', () {
    test('two clean minutes report once, then again for each further span', () {
      final h = Harness()..play(130);
      expect(h.smooth, 1);
      h.play(120);
      expect(h.smooth, 2);
    });

    test('a stall restarts the count', () {
      final h = Harness()..play(100);
      h.stall(3);
      h.play(100);

      expect(h.smooth, 0, reason: 'never 120 clean seconds in a row');
    });
  });

  group('the offer to choose another source', () {
    test('three stalls inside three minutes ask once', () {
      final h = Harness()..play(5);
      h.stall(3);
      h.play(20);
      h.stall(3);
      h.play(20);
      h.stall(3);

      expect(h.offers, 1);
    });

    test('stalls spread over a long time do not', () {
      final h = Harness()..play(5);
      h.stall(3);
      h.play(150);
      h.stall(3);
      h.play(150);
      h.stall(3);

      expect(h.offers, 0);
    });

    test('a one-second hiccup is not a stall', () {
      final h = Harness()..play(5);
      for (var i = 0; i < 4; i++) {
        h.stall(1);
        h.play(10);
      }

      expect(h.offers, 0);
    });

    test('does not ask again straight away', () {
      final h = Harness()..play(5);
      for (var i = 0; i < 3; i++) {
        h.stall(3);
        h.play(15);
      }
      expect(h.offers, 1);

      for (var i = 0; i < 3; i++) {
        h.stall(3);
        h.play(15);
      }
      expect(h.offers, 1, reason: 'inside the cooldown');
    });
  });
}
