// test/widgets/interactive_card_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/focus_ring.dart';
import 'package:playtorriomov/widgets/common/interactive_card_shell.dart';

void main() {
  testWidgets('a focused card leans in but is not wrapped in a focus ring',
      (tester) async {
    // A keyboard/D-pad viewer: focus styling is for them.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });
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

  testWidgets('a focused card stays flat for a mouse viewer', (tester) async {
    // The reported bug: FirstFocusScope hands the first card focus on open
    // so a remote has somewhere to be, and on desktop that arrived looking
    // like the first movie pre-selected and zoomed. Touch/mouse highlight
    // mode draws no focus styling -- the card leans in for hover, not for
    // a focus nobody navigated with.
    expect(
      FocusManager.instance.highlightMode,
      FocusHighlightMode.touch,
    );
    var hoveredSeen = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InteractiveCardShell(
          onTap: () {},
          builder: (context, hovered, pressed) {
            hoveredSeen = hoveredSeen || hovered;
            return const SizedBox(key: Key('card'), width: 100, height: 150);
          },
        ),
      ),
    ));

    final card = Focus.of(tester.element(find.byKey(const Key('card'))));
    card.requestFocus();
    await tester.pump(const Duration(milliseconds: 300));

    expect(card.hasPrimaryFocus, isTrue);
    expect(hoveredSeen, isFalse);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
  });
}
