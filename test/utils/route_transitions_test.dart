// test/utils/route_transitions_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/main.dart' show navigatorKey;
import 'package:playtorriomov/utils/navigation/route_transitions.dart';

/// Mimics HubPage's real shape closely enough to prove the thing that
/// matters: "hub chrome" sits alongside a nested Navigator, and a page
/// pushed via [pushPage] must escape that nested Navigator and cover the
/// chrome too -- not just render inside the nested Navigator's own box,
/// which is what pushPage did before it was switched to the root
/// navigator.
Widget _harness() {
  final nestedNavKey = GlobalKey<NavigatorState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Column(
      children: [
        const Text('hub chrome'),
        Expanded(
          child: Navigator(
            key: nestedNavKey,
            onGenerateInitialRoutes: (nav, _) => [
              MaterialPageRoute<void>(
                builder: (context) => ElevatedButton(
                  onPressed: () => pushPage(context, const Text('pushed page')),
                  child: const Text('open'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('pushPage escapes the nested navigator and covers hub chrome', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    expect(find.text('hub chrome'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The chrome and the nested navigator's own "open" button are both
    // gone -- pushPage rendered fullscreen on the root navigator, above
    // everything, not inside the nested navigator's own box.
    expect(find.text('pushed page'), findsOneWidget);
    expect(find.text('hub chrome'), findsNothing);
    expect(find.text('open'), findsNothing);

    // Backing out returns to the hub with its chrome intact.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('hub chrome'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('pushed page'), findsNothing);
  });
}
