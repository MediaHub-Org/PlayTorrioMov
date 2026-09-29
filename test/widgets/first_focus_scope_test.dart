// test/widgets/first_focus_scope_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/first_focus_scope.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FirstFocusScope', () {
    testWidgets('ready: true focuses the first descendant', (tester) async {
      final firstNode = FocusNode();
      final secondNode = FocusNode();
      addTearDown(firstNode.dispose);
      addTearDown(secondNode.dispose);

      await tester.pumpWidget(wrap(FirstFocusScope(
        ready: true,
        child: Column(
          children: [
            Focus(focusNode: firstNode, child: const Text('one')),
            Focus(focusNode: secondNode, child: const Text('two')),
          ],
        ),
      )));
      await tester.pumpAndSettle();

      expect(firstNode.hasFocus, isTrue);
      expect(secondNode.hasFocus, isFalse);
    });

    testWidgets('ready: false focuses nothing', (tester) async {
      final firstNode = FocusNode();
      addTearDown(firstNode.dispose);

      await tester.pumpWidget(wrap(FirstFocusScope(
        ready: false,
        child: Focus(focusNode: firstNode, child: const Text('one')),
      )));
      await tester.pumpAndSettle();

      expect(firstNode.hasFocus, isFalse);
    });

    testWidgets(
      'content that arrives after the first build (ready flips true later) '
      'still gets focused',
      (tester) async {
        final firstNode = FocusNode();
        addTearDown(firstNode.dispose);

        await tester.pumpWidget(wrap(const FirstFocusScope(
          ready: false,
          child: SizedBox.shrink(),
        )));
        await tester.pumpAndSettle();
        expect(firstNode.hasFocus, isFalse);

        await tester.pumpWidget(wrap(FirstFocusScope(
          ready: true,
          child: Focus(focusNode: firstNode, child: const Text('one')),
        )));
        await tester.pumpAndSettle();

        expect(firstNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'only focuses once -- a later rebuild does not steal focus back',
      (tester) async {
        final firstNode = FocusNode();
        final otherNode = FocusNode();
        addTearDown(firstNode.dispose);
        addTearDown(otherNode.dispose);

        await tester.pumpWidget(wrap(Column(
          children: [
            FirstFocusScope(
              ready: true,
              child: Focus(focusNode: firstNode, child: const Text('one')),
            ),
            // Outside the scope entirely, so moving focus here is a clean
            // stand-in for "the viewer navigated to something else".
            Focus(focusNode: otherNode, child: const Text('elsewhere')),
          ],
        )));
        await tester.pumpAndSettle();
        expect(firstNode.hasFocus, isTrue);

        otherNode.requestFocus();
        await tester.pumpAndSettle();
        expect(firstNode.hasFocus, isFalse);
        expect(otherNode.hasFocus, isTrue);

        // An unrelated rebuild of the scope's content must not yank focus
        // back to the first item now that the viewer moved it elsewhere.
        await tester.pumpWidget(wrap(Column(
          children: [
            FirstFocusScope(
              ready: true,
              child: Focus(focusNode: firstNode, child: const Text('one (v2)')),
            ),
            Focus(focusNode: otherNode, child: const Text('elsewhere')),
          ],
        )));
        await tester.pumpAndSettle();

        expect(firstNode.hasFocus, isFalse);
        expect(otherNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'rows wrapped in their own FirstFocusScope stay in one traversal scope: '
      'Down moves to the row below, Right stays in the row',
      (tester) async {
        final a0 = FocusNode();
        final a1 = FocusNode();
        final b0 = FocusNode();
        final b1 = FocusNode();
        for (final n in [a0, a1, b0, b1]) {
          addTearDown(n.dispose);
        }

        Widget row(FocusNode first, FocusNode second) => SizedBox(
              height: 60,
              child: FirstFocusScope(
                ready: false,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Focus(
                      focusNode: first,
                      child: const SizedBox(width: 100, height: 60),
                    ),
                    Focus(
                      focusNode: second,
                      child: const SizedBox(width: 100, height: 60),
                    ),
                  ],
                ),
              ),
            );

        await tester.pumpWidget(wrap(Column(
          children: [row(a0, a1), row(b0, b1)],
        )));
        a0.requestFocus();
        await tester.pump();
        expect(a0.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(a1.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(
          b1.hasPrimaryFocus || b0.hasPrimaryFocus,
          isTrue,
          reason: 'Down must leave the row -- each row used to be its own '
              'FocusScope, which a D-pad cannot traverse out of',
        );
      },
    );
  });
}
