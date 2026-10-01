// test/widgets/focus_highlight_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/focus_highlight.dart';
import 'package:playtorriomov/widgets/common/focus_ring.dart';

void main() {
  testWidgets('a focused pill gets a soft backdrop and does not move its '
      'neighbors', (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              FocusHighlight(
                child: Focus(
                  focusNode: first,
                  child: const SizedBox(key: Key('a'), width: 80, height: 32),
                ),
              ),
              const SizedBox(width: 12),
              FocusHighlight(
                child: Focus(
                  focusNode: second,
                  child: const SizedBox(key: Key('b'), width: 80, height: 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final neighborBefore = tester.getTopLeft(find.byKey(const Key('b')));

    Color? backdrop() {
      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(FocusRing).first,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(backdrop(), Colors.transparent);

    first.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Painted outside the child's box, so nothing beside it shifts.
    expect(backdrop(), isNot(Colors.transparent));
    expect(tester.getTopLeft(find.byKey(const Key('b'))), neighborBefore);
  });

  testWidgets('the soft backdrop never has a border', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FocusRing(
            visible: true,
            soft: true,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((box.decoration as BoxDecoration).border, isNull);
  });
}
