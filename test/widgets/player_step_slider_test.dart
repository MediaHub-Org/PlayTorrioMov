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

    testWidgets('reports the committed value on change end', (tester) async {
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
      await tester.pump();

      expect(committed.single, closeTo(1.25, 0.001));
    });
  });
}
