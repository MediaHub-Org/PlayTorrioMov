// test/widgets/hover_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/hover_button.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('Enter activates onTap while the button holds focus',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(
      HoverButton(
        autofocus: true,
        onTap: () => tapped++,
        child: const SizedBox(width: 40, height: 40),
      ),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('the TV remote select key activates onTap the same way',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(
      HoverButton(
        autofocus: true,
        onTap: () => tapped++,
        child: const SizedBox(width: 40, height: 40),
      ),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('a key press does nothing once focus has moved elsewhere',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(
      Column(
        children: [
          HoverButton(
            onTap: () => tapped++,
            child: const SizedBox(width: 40, height: 40),
          ),
          HoverButton(
            autofocus: true,
            onTap: () {},
            child: const SizedBox(width: 40, height: 40),
          ),
        ],
      ),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tapped, 0);
  });

  testWidgets('scales up on focus the same way it does on hover',
      (tester) async {
    await tester.pumpWidget(wrap(
      HoverButton(
        autofocus: true,
        scaleAmount: 1.2,
        onTap: () {},
        child: const SizedBox(width: 40, height: 40),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.2);
  });
}
