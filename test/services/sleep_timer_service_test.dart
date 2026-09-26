// test/services/sleep_timer_service_test.dart
//
// The service owns the clock, so what matters here is the arming states and
// the guard that stops a completion arriving after the player went away from
// calling back into a dead screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/sleep_timer_service.dart';

void main() {
  final timer = SleepTimerService.instance;

  setUp(() {
    timer.cancel();
    timer.onExpired = null;
  });

  tearDown(() {
    timer.cancel();
    timer.onExpired = null;
  });

  group('minute countdown', () {
    test('starting arms a countdown and clears the end-of-video flag', () {
      timer.startUntilEndOfVideo();
      expect(timer.armedForEndOfVideo.value, isTrue);

      timer.start(15);
      expect(timer.minutesRemaining.value, 15);
      // The two are alternatives, not additive.
      expect(timer.armedForEndOfVideo.value, isFalse);
    });

    test('cancel clears both kinds', () {
      timer.start(30);
      timer.cancel();
      expect(timer.minutesRemaining.value, isNull);
      expect(timer.isArmed, isFalse);

      timer.startUntilEndOfVideo();
      timer.cancel();
      expect(timer.armedForEndOfVideo.value, isFalse);
      expect(timer.isArmed, isFalse);
    });
  });

  group('end of video', () {
    test('arming sets the flag without a countdown', () {
      timer.startUntilEndOfVideo();
      expect(timer.armedForEndOfVideo.value, isTrue);
      expect(
        timer.minutesRemaining.value,
        isNull,
        reason: 'there is no number to count down to',
      );
      expect(timer.isArmed, isTrue);
    });

    test('the video ending fires the callback and disarms', () {
      var fired = 0;
      timer.onExpired = () => fired++;
      timer.startUntilEndOfVideo();

      timer.notifyVideoEnded();

      expect(fired, 1);
      expect(timer.armedForEndOfVideo.value, isFalse);
    });

    test('a video ending with nothing armed does not fire', () {
      var fired = 0;
      timer.onExpired = () => fired++;

      timer.notifyVideoEnded();

      expect(fired, 0);
    });

    test('a minute countdown is not fired by the video ending', () {
      var fired = 0;
      timer.onExpired = () => fired++;
      timer.start(15);

      timer.notifyVideoEnded();

      expect(
        fired,
        0,
        reason: 'the countdown is a different promise from end-of-video',
      );
      expect(timer.minutesRemaining.value, 15);
    });

    test('an unmounted player disarms without firing', () {
      // A completion can arrive after the screen is torn down. Firing would
      // call pause() on a disposed State.
      var fired = 0;
      timer.onExpired = () => fired++;
      timer.startUntilEndOfVideo();

      timer.notifyVideoEnded(mounted: false);

      expect(fired, 0);
      expect(timer.armedForEndOfVideo.value, isFalse);
    });

    test('it fires once, not once per completion event', () {
      var fired = 0;
      timer.onExpired = () => fired++;
      timer.startUntilEndOfVideo();

      timer.notifyVideoEnded();
      timer.notifyVideoEnded();

      expect(fired, 1);
    });
  });
}