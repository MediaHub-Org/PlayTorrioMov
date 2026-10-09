// test/widgets/player_step_slider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PlayerStepSlider', () {
    // Material's Slider is pointer-only, so on a TV the speed and sleep
    // timer sliders were visible but unreachable from a remote. These tests
    // pin the D-pad behavior that fixes it.

    testWidgets('right arrow moves one step up', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: values.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(values, isNotEmpty);
      expect(values.last, closeTo(1.25, 0.001));
    });

    testWidgets('left arrow moves one step down', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: values.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(values.last, closeTo(0.75, 0.001));
    });

    testWidgets('does not move past the ends', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 2.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: values.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(values, isEmpty, reason: 'already at the maximum');
    });

    testWidgets('an arrow does not report a change end', (tester) async {
      // Each arrow was a finished drag, and the speed menu closes on that.
      final committed = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: (_) {},
        onChangeEnd: committed.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(committed, isEmpty);
    });

    testWidgets('OK reports the current value as the change end', (
      tester,
    ) async {
      final committed = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: (_) {},
        onChangeEnd: committed.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(committed.single, closeTo(1.0, 0.001));
    });

    testWidgets('OK is left alone when there is no change end', (tester) async {
      // The volume panel mutes with OK; the slider must not swallow it.
      var outer = 0;
      await tester.pumpWidget(wrap(Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.select) {
            outer++;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: PlayerStepSlider(
          value: 1.0,
          min: 0.25,
          max: 2.0,
          divisions: 7,
          onChanged: (_) {},
        ),
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(outer, 1);
    });

    testWidgets('Up and Down are not taken, so focus can leave', (
      tester,
    ) async {
      final values = <double>[];
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: values.add,
      )));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(values, isEmpty);
    });

    testWidgets('draws no focus ring; focus thickens the track instead', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(PlayerStepSlider(
        value: 1.0,
        min: 0.25,
        max: 2.0,
        divisions: 7,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.byType(FocusRing), findsNothing);
      final theme = tester.widget<SliderTheme>(
        find.descendant(
          of: find.byType(PlayerStepSlider),
          matching: find.byType(SliderTheme),
        ),
      );
      expect(theme.data.trackHeight, 6,
          reason: 'it autofocuses, so it is the focused look that shows');
    });
  });
}
