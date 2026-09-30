// test/widgets/interactive_card_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/focus_ring.dart';
import 'package:playtorriomov/widgets/common/interactive_card_shell.dart';

void main() {
  testWidgets('a focused card leans in but is not wrapped in a focus ring',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var hoveredSeen = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Focus(
          focusNode: node,
          child: InteractiveCardShell(
            onTap: () {},
            builder: (context, hovered, pressed) {
              hoveredSeen = hoveredSeen || hovered;
              return const SizedBox(key: Key('card'), width: 100, height: 150);
            },
          ),
        ),
      ),
    ));

    // Focus the card itself, not the wrapper above it.
    final card = Focus.of(tester.element(find.byKey(const Key('card'))));
    card.requestFocus();
    await tester.pump(const Duration(milliseconds: 300));

    expect(card.hasPrimaryFocus, isTrue);
    expect(hoveredSeen, isTrue);
    expect(find.byType(FocusRing), findsNothing);
  });
}
