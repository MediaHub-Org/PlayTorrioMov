// Holding an arrow on a remote asked a network stream to jump thirty times a
// second, each one throwing away the cache. A burst of presses is one seek.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/seek_coalescer.dart';

Duration sec(int n) => Duration(seconds: n);

void main() {
  late List<Duration> seeks;
  late SeekCoalescer coalescer;

  setUp(() {
    seeks = [];
    coalescer = SeekCoalescer(onSeek: seeks.add);
  });
  tearDown(() => coalescer.dispose());

  test('one press seeks once, after a short wait', () async {
    final target = coalescer.nudge(from: sec(100), offset: sec(10));

    expect(target, sec(110));
    expect(seeks, isEmpty, reason: 'not yet: more presses may follow');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(seeks, [sec(110)]);
  });

  test('a burst builds on its own target and seeks once', () async {
    coalescer.nudge(from: sec(100), offset: sec(10));
    coalescer.nudge(from: sec(100), offset: sec(10));
    final last = coalescer.nudge(from: sec(100), offset: sec(10));

    expect(last, sec(130),
        reason: 'the player has not moved, so "from" is stale after the first');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(seeks, [sec(130)]);
  });

  test('forward then back nets out', () async {
    coalescer.nudge(from: sec(100), offset: sec(10));
    coalescer.nudge(from: sec(100), offset: sec(-10));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(seeks, [sec(100)]);
  });

  test('stays within the media', () {
    expect(
      coalescer.nudge(from: sec(5), offset: sec(-30), duration: sec(600)),
      Duration.zero,
    );
    coalescer.cancel();
    expect(
      coalescer.nudge(from: sec(590), offset: sec(30), duration: sec(600)),
      sec(600),
    );
  });

  test('a hold still moves the picture every so often', () async {
    // Presses every 100 ms for 2 seconds never leave a quiet gap of 250 ms,
    // but the first one may only be held back for the maximum wait.
    const tick = Duration(milliseconds: 100);
    for (var i = 0; i < 20; i++) {
      coalescer.nudge(from: sec(100), offset: sec(5));
      await Future<void>.delayed(tick);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(seeks.length, greaterThan(1),
        reason: 'seeks happened during the hold, not only after it');
    expect(seeks.length, lessThan(8), reason: 'and far fewer than 20');
  });

  test('a zero delay seeks on every press', () {
    coalescer.delay = Duration.zero;

    coalescer.nudge(from: sec(100), offset: sec(10));
    expect(seeks, [sec(110)]);
    coalescer.nudge(from: sec(110), offset: sec(10));
    expect(seeks, [sec(110), sec(120)]);
    expect(coalescer.isPending, isFalse);
  });

  test('a seek from somewhere else cancels the pending one', () async {
    coalescer.nudge(from: sec(100), offset: sec(10));
    coalescer.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(seeks, isEmpty);
    expect(coalescer.isPending, isFalse);
  });

  test('flush asks right away', () {
    coalescer.nudge(from: sec(100), offset: sec(10));
    coalescer.flush();

    expect(seeks, [sec(110)]);
  });
}
