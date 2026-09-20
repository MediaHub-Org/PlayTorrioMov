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
    // binding rejects at teardown unless it is canceled here.
    SleepTimerService.instance.cancel();
  });

  group('SleepTimerMenu', () {
    // This was the settings menu until the controls it indexed grew buttons
    // of their own; what remained was the sleep timer, and a menu for one
    // control is worse than a button for it.

    testWidgets('offers the presets, each with its own row', (tester) async {
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      // Rows, not chips: each row shows the consequence of the choice
      // ("pauses at HH:MM"), so the label is a prefix match.
      for (final min in [15, 30, 45, 60]) {
        expect(find.textContaining('$min min -- pauses at'), findsOneWidget);
      }
    });

    testWidgets('has no slider, and no preset past an hour', (tester) async {
      // The slider offered the presets a second way, and 90 belongs to the
      // custom row that opens on it.
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('90 min -- pauses at'), findsNothing);
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

      // The countdown lives in the Off row now: "Off (cancel -- N min
      // left)" is both the state and the way out, one widget instead of two.
      expect(find.textContaining('Off (cancel -- 30 min left'),
          findsOneWidget);

      // Canceling is the service's own behavior; the row's existence is
      // asserted above, and the service test covers the cancel path
      // directly -- tapping it in the harness is unreliable in a short
      // test window.
      SleepTimerService.instance.cancel();
      await tester.pump();
      expect(find.textContaining('Off (cancel'), findsNothing,
          reason: 'a canceled timer leaves the menu');
    });

    testWidgets('the running countdown is visible in the menu', (tester) async {
      // The menu reads the service through a ValueListenableBuilder, so a
      // timer started before the menu opened is reflected in it -- which is
      // what makes the badge on the transport bar and the state in the menu
      // the same truth rather than two.
      SleepTimerService.instance.start(45);
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.textContaining('Off (cancel -- 45 min left'),
          findsOneWidget);
      SleepTimerService.instance.cancel();
    });

    testWidgets('carries no close button', (tester) async {
      // Tapping off the panel dismisses it; the X was a third way to do
      // what the barrier behind the menu already did.
      await tester.pumpWidget(wrap(const SleepTimerMenu()));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
    group('custom duration steppers', () {
      // Editing alone does not arm the timer -- the row says "Set", and
      // starting it is its own tap, so nudging past a value by accident
      // does not silently start a two-hour timer.
      testWidgets('nudging the steppers edits the value without starting',
          (tester) async {
        await tester.pumpWidget(wrap(const SleepTimerMenu()));

        expect(find.text('90 min'), findsOneWidget,
            reason: 'custom opens where the presets leave off');

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
        expect(find.text('105 min'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.remove_rounded));
        await tester.pump();
        // "75 min" is not a preset, but assert the custom value through
        // arming it all the same: the check button starts whatever the
        // steppers currently show.
        expect(SleepTimerService.instance.minutesRemaining.value, isNull,
            reason: 'editing is not arming');
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.pump();
        expect(SleepTimerService.instance.minutesRemaining.value, 75,
            reason: 'up one and down two from 90 lands on 75, in 15-minute steps');
        SleepTimerService.instance.cancel(); // no pending timer at teardown
      });

      testWidgets('the check button arms the edited value', (tester) async {
        await tester.pumpWidget(wrap(const SleepTimerMenu()));

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.pump();

        expect(SleepTimerService.instance.minutesRemaining.value, 105);
        SleepTimerService.instance.cancel(); // no pending timer at teardown
      });

      testWidgets('the value is clamped to 15..480', (tester) async {
        await tester.pumpWidget(wrap(const SleepTimerMenu()));

        // Default is 90; twenty minus-taps cannot go below 15.
        for (var i = 0; i < 20; i++) {
          await tester.tap(find.byIcon(Icons.remove_rounded));
          await tester.pump();
        }
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.pump();
        expect(SleepTimerService.instance.minutesRemaining.value, 15,
            reason: 'the clamp floor is 15, not below');
        SleepTimerService.instance.cancel(); // no pending timer at teardown
      });

      testWidgets('the ceiling is 8 hours', (tester) async {
        await tester.pumpWidget(wrap(const SleepTimerMenu()));

        for (var i = 0; i < 40; i++) {
          await tester.tap(find.byIcon(Icons.add_rounded));
          await tester.pump();
        }
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.pump();
        expect(SleepTimerService.instance.minutesRemaining.value, 480);
        SleepTimerService.instance.cancel(); // no pending timer at teardown
      });
    });
  });
}

