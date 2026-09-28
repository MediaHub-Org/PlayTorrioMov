// test/widgets/player_icon_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PlayerIconButton', () {
    testWidgets('the select key activates onPressed while it holds focus',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrap(
        PlayerIconButton(
          autofocus: true,
          icon: const Icon(Icons.play_arrow),
          onPressed: () => pressed++,
        ),
      ));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(pressed, 1);
    });

    testWidgets('Enter activates it the same way, for a desktop keyboard',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrap(
        PlayerIconButton(
          autofocus: true,
          icon: const Icon(Icons.play_arrow),
          onPressed: () => pressed++,
        ),
      ));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(pressed, 1);
    });

    testWidgets('a disabled button (onPressed null) ignores the select key',
        (tester) async {
      await tester.pumpWidget(wrap(
        const PlayerIconButton(
          autofocus: true,
          icon: Icon(Icons.play_arrow),
        ),
      ));
      await tester.pump();

      // No onPressed to call; this must not throw.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
    });

    testWidgets('shows a focus ring while focused', (tester) async {
      await tester.pumpWidget(wrap(
        PlayerIconButton(
          autofocus: true,
          icon: const Icon(Icons.play_arrow),
          onPressed: () {},
        ),
      ));
      await tester.pump();

      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
    });
  });
}
