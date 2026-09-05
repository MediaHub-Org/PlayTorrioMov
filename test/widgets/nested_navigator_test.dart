import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/nested_navigator.dart';

void main() {
  testWidgets(
    'a root-navigator pop (Android system back) pops the nested route '
    'instead of falling through to the root',
    (tester) async {
      final rootNav = GlobalKey<NavigatorState>();
      final nestedNav = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNav,
          home: NestedNavigator(
            navigatorKey: nestedNav,
            child: const Text('nested home'),
          ),
        ),
      );

      expect(find.text('nested home'), findsOneWidget);

      nestedNav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('pushed page')),
      );
      await tester.pumpAndSettle();

      expect(find.text('pushed page'), findsOneWidget);
      expect(find.text('nested home'), findsNothing);

      // What Android's system back button ultimately does: ask the root
      // Navigator to pop. Without NavigatorPopHandler this would find
      // nothing to pop at the root and exit the app instead of popping the
      // page pushed on the nested Navigator.
      final handled = await rootNav.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('nested home'), findsOneWidget);
      expect(find.text('pushed page'), findsNothing);
    },
  );
}
