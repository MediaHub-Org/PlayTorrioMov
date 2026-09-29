// test/widgets/tv_focus_bridge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/tv_focus_bridge.dart';

/// The hub's shape: a bar of chips above a nested Navigator, whose route has
/// its own focus scope -- the layout a D-pad could not cross.
Widget hub(List<FocusNode> chips, List<FocusNode> cards) => MaterialApp(
      home: Scaffold(
        body: TvFocusBridge(
          child: Column(
            children: [
              Row(
                children: [
                  for (final c in chips)
                    Focus(
                      focusNode: c,
                      child: const SizedBox(width: 80, height: 40),
                    ),
                ],
              ),
              Expanded(
                child: Navigator(
                  onGenerateInitialRoutes: (_, __) => [
                    MaterialPageRoute<void>(
                      builder: (_) => Column(
                        children: [
                          for (final c in cards)
                            Focus(
                              focusNode: c,
                              child: const SizedBox(width: 100, height: 60),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  late List<FocusNode> chips;
  late List<FocusNode> cards;

  setUp(() {
    // A supplied node's own label is the one the bridge sees; the widget's
    // debugLabel is only used when the widget makes its own node.
    chips = [
      FocusNode(debugLabel: TvFocusBridge.chipLabel),
      FocusNode(debugLabel: TvFocusBridge.chipLabel),
    ];
    cards = [FocusNode(debugLabel: 'k0'), FocusNode(debugLabel: 'k1')];
  });

  tearDown(() {
    for (final n in [...chips, ...cards]) {
      n.dispose();
    }
  });

  testWidgets('Up from the top card crosses to a chip, Down comes back',
      (tester) async {
    await tester.pumpWidget(hub(chips, cards));
    await tester.pump();
    cards[0].requestFocus();
    await tester.pump();
    expect(cards[0].hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(chips.any((c) => c.hasPrimaryFocus), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cards.any((c) => c.hasPrimaryFocus), isTrue);
  });

  testWidgets('Up between cards is left to ordinary traversal',
      (tester) async {
    await tester.pumpWidget(hub(chips, cards));
    await tester.pump();
    cards[1].requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(cards[0].hasPrimaryFocus, isTrue);
  });
}
