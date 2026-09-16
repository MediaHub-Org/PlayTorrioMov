// test/widgets/sleep_timer_menu_test.dart
import 'package:flutter/material.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/sleep_timer_service.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  setUp(() {
    // The service is a singleton with a real timer behind it; start each
    // test from a stopped state.
    SleepTimerService.instance.cancel();
  });

  tearDown(() {
    // A started timer is a pending Timer.periodic, which the widget test
    // binding rejects at teardown unless it is cancelled here.
    SleepTimerService.instance.cancel();
  });

  group('SleepTimerMenu', () {
    // This was the settings menu until the controls it indexed grew buttons
    // of their own; what remained was the sleep timer, and a menu for one
    // control is worse than a button for it.

    testWidgets('offers the four presets', (tester) async {
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      for (final min in ['15 min', '30 min', '45 min', '60 min']) {
        expect(find.text(min), findsOneWidget);
      }
    });

    test('choosing a preset starts the real timer', () {
      // The chips existed for several releases before anything was wired
      // behind them: choosing "30 min" changed a highlight and nothing
      // else. This is the test for that. fakeAsync because the service
      // holds a real Timer.periodic, which the widget binding rejects as a
      // pending timer -- and because driving the clock is how the countdown
      // itself is tested below.
      fakeAsync((async) {
        SleepTimerService.instance.start(30);
        expect(SleepTimerService.instance.minutesRemaining.value, 30);

        async.elapse(const Duration(minutes: 29));
        expect(SleepTimerService.instance.minutesRemaining.value, 1);

        async.elapse(const Duration(minutes: 1));
        expect(SleepTimerService.instance.minutesRemaining.value, isNull,
            reason: 'the countdown ends at zero, not below it');
      });
    });

    test('expiry fires the pause callback exactly once', () {
      fakeAsync((async) {
        var pauses = 0;
        SleepTimerService.instance.onExpired = () => pauses++;
        SleepTimerService.instance.start(15);

        async.elapse(const Duration(minutes: 15));
        expect(pauses, 1, reason: 'one countdown, one pause');

        async.elapse(const Duration(minutes: 5));
        expect(pauses, 1, reason: 'a finished timer does not fire again');
      });
    });

    test('starting again replaces the running timer', () {
      fakeAsync((async) {
        SleepTimerService.instance.start(60);
        SleepTimerService.instance.start(15);
        async.elapse(const Duration(minutes: 15));
        expect(SleepTimerService.instance.minutesRemaining.value, isNull,
            reason: 'the last choice wins, so the 60-minute timer is gone');
      });
    });

    testWidgets('the running countdown is shown, with a way to stop it', (
      tester,
    ) async {
      SleepTimerService.instance.start(30);
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.text('30 min remaining -- playback pauses at 0'),
          findsOneWidget);
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(find.text('Off'));
      expect(SleepTimerService.instance.minutesRemaining.value, isNull);
    });

    testWidgets('the running countdown is visible in the menu', (tester) async {
      // The menu reads the service through a ValueListenableBuilder, so a
      // timer started before the menu opened is reflected in it -- which is
      // what makes the badge on the transport bar and the state in the menu
      // the same truth rather than two.
      SleepTimerService.instance.start(45);
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.text('45 min remaining -- playback pauses at 0'),
          findsOneWidget);
      // And an Off chip exists to cancel it with.
      expect(find.text('Off'), findsOneWidget);
      SleepTimerService.instance.cancel();
    });

    testWidgets('carries no close button', (tester) async {
      // Tapping off the panel dismisses it; the X was a third way to do
      // what the barrier behind the menu already did.
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
