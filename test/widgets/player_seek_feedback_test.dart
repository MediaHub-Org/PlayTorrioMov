import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_seek_feedback.dart';

Widget wrap(SeekFlash? flash) => MaterialApp(
  home: Scaffold(
    body: Stack(children: [PlayerSeekFeedback(flash: flash)]),
  ),
);

/// Scoped to the overlay: MaterialApp's own page transition contributes a
/// FadeTransition of its own, so a bare byType would be ambiguous.
final fade = find.descendant(
  of: find.byType(PlayerSeekFeedback),
  matching: find.byType(FadeTransition),
);

void main() {
  group('SeekFlash.next', () {
    test('a first seek reads as its own step', () {
      final flash = SeekFlash.next(null, 10, id: 1);
      expect(flash.totalSeconds, 10);
      expect(flash.isForward, isTrue);
    });

    test('repeat taps the same way keep counting', () {
      // Three quick +10s taps is a viewer asking for 30 seconds, not for
      // the same 10 seconds three times.
      var flash = SeekFlash.next(null, 10, id: 1);
      flash = SeekFlash.next(flash, 10, id: 2);
      flash = SeekFlash.next(flash, 10, id: 3);
      expect(flash.totalSeconds, 30);
    });

    test('mixing step sizes still adds up', () {
      var flash = SeekFlash.next(null, 30, id: 1);
      flash = SeekFlash.next(flash, 10, id: 2);
      expect(flash.totalSeconds, 40);
    });

    test('turning around starts a new count rather than canceling out', () {
      // Going back after going forward should read "10 seconds" back, not
      // "0 seconds" -- the total is a description of the latest gesture,
      // not a running sum of the whole session.
      var flash = SeekFlash.next(null, 30, id: 1);
      flash = SeekFlash.next(flash, -10, id: 2);
      expect(flash.totalSeconds, -10);
      expect(flash.isForward, isFalse);
    });

    test('each fold carries the id it was given', () {
      final first = SeekFlash.next(null, 10, id: 7);
      final second = SeekFlash.next(first, 10, id: 8);
      expect(first.id, 7);
      expect(second.id, 8);
    });
  });

  group('PlayerSeekFeedback', () {
    testWidgets('shows nothing until a seek happens', (tester) async {
      await tester.pumpWidget(wrap(null));
      expect(find.byType(Icon), findsNothing);
      expect(find.textContaining('seconds'), findsNothing);
    });

    testWidgets('a forward seek flashes on the right', (tester) async {
      await tester.pumpWidget(wrap(const SeekFlash(id: 1, totalSeconds: 30)));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('30 seconds'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      final screen = tester.getCenter(find.byType(Scaffold));
      expect(
        tester.getCenter(find.text('30 seconds')).dx,
        greaterThan(screen.dx),
      );
    });

    testWidgets('a backward seek flashes on the left, unsigned', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SeekFlash(id: 1, totalSeconds: -10)));
      await tester.pump(const Duration(milliseconds: 200));

      // The direction is carried by the side and the icon; a minus sign in
      // the label would say it twice.
      expect(find.text('10 seconds'), findsOneWidget);
      expect(find.byIcon(Icons.fast_rewind_rounded), findsOneWidget);

      final screen = tester.getCenter(find.byType(Scaffold));
      expect(tester.getCenter(find.text('10 seconds')).dx, lessThan(screen.dx));
    });

    testWidgets('fades out on its own', (tester) async {
      await tester.pumpWidget(wrap(const SeekFlash(id: 1, totalSeconds: 10)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        greaterThan(0.5),
      );

      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0.0);
    });

    testWidgets('a repeat seek re-runs the animation', (tester) async {
      // Without the id, two identical flashes are the same widget
      // configuration and the second tap would show nothing.
      await tester.pumpWidget(wrap(const SeekFlash(id: 1, totalSeconds: 10)));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0.0);

      await tester.pumpWidget(wrap(const SeekFlash(id: 2, totalSeconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        greaterThan(0.5),
      );
      expect(find.text('20 seconds'), findsOneWidget);
    });
  });
}
