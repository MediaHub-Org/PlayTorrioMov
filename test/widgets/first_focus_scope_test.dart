// test/widgets/first_focus_scope_test.dart
import 'package:flutter/material.dart';
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

        await tester.pumpWidget(wrap(FirstFocusScope(
          ready: false,
          child: const SizedBox.shrink(),
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
  });
}
