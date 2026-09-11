// test/widgets/browse_scaffold_hero_height_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/browse_scaffold.dart';

Widget slide(BuildContext context, String item) =>
    ColoredBox(color: Colors.blue, child: Text(item));

Widget card(BuildContext context, String item) =>
    SizedBox(width: 100, child: Text(item));

Future<void> pumpScaffold(
  WidgetTester tester, {
  double Function(double, double)? heroHeightOf,
  Size surface = const Size(1200, 900),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: BrowseScaffold<String>(
        heroItems: const ['a', 'b'],
        rows: const [],
        heroBuilder: slide,
        itemBuilder: card,
        heroHeightOf: heroHeightOf,
        // Rotation would leave a pending timer at test end.
        heroInterval: null,
      ),
    ),
  );
  await tester.pump();
}

double heroHeight(WidgetTester tester) =>
    tester.getSize(find.byType(PageView)).height;

void main() {
  group('BrowseScaffold hero height', () {
    testWidgets('uses its own formula when the caller supplies none', (
      tester,
    ) async {
      await pumpScaffold(tester);

      // Desktop tier: screenHeight * 0.52, clamped to 380..560.
      expect(heroHeight(tester), closeTo(900 * 0.52, 0.5));
    });

    testWidgets('a caller can override it', (tester) async {
      // Live TV lets the user pick between three hero styles, each with its
      // own height. That setting is why its hero could not simply be
      // replaced by this one -- taking the formula as a parameter is what
      // let Live TV move onto this scaffold without dropping it.
      await pumpScaffold(
        tester,
        heroHeightOf: (width, screenHeight) =>
            (screenHeight * 0.28).clamp(210.0, 260.0),
      );

      expect(heroHeight(tester), closeTo(252, 0.5));
    });

    testWidgets('the override sees the real width and height', (tester) async {
      late double seenWidth;
      late double seenHeight;
      await pumpScaffold(
        tester,
        surface: const Size(430, 800),
        heroHeightOf: (width, screenHeight) {
          seenWidth = width;
          seenHeight = screenHeight;
          return 300;
        },
      );

      expect(seenWidth, 430);
      expect(seenHeight, 800);
      expect(heroHeight(tester), 300);
    });

    testWidgets('an override that clamps low still renders a hero', (
      tester,
    ) async {
      // Minimalist is the shortest of Live TV's three styles; it must not
      // collapse the carousel or trip an overflow.
      await pumpScaffold(tester, heroHeightOf: (_, __) => 210);

      expect(heroHeight(tester), 210);
      expect(tester.takeException(), isNull);
    });
  });
}
