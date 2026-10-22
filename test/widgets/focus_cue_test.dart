// A mouse viewer never asked for focus, but FirstFocusScope and autofocus hand
// it to the first control of every section. That control must not zoom until a
// key has been pressed.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/widgets/common/hover_button.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

Widget focusedOnOpen({double scaleAmount = 1.2}) => HoverButton(
      autofocus: true,
      scaleAmount: scaleAmount,
      onTap: () {},
      child: const SizedBox(width: 40, height: 40),
    );

double scaleOf(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  setUp(TvModeService.installFocusPolicy);
  tearDown(TvModeService.resetFocusPolicy);

  testWidgets('a control that takes focus on open does not zoom until a key is pressed',
      (tester) async {
    await tester.pumpWidget(wrap(focusedOnOpen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scaleOf(tester), 1.0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 200));

    expect(scaleOf(tester), 1.2,
        reason: 'the key moved nothing, and the card still has to show focus');
  });

  testWidgets('a mouse hover still leans the control before any key is pressed',
      (tester) async {
    await tester.pumpWidget(wrap(focusedOnOpen()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester), 1.0);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(HoverButton)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scaleOf(tester), 1.2);
  });
}
