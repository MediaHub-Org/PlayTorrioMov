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
  double Function(double)? belowHeroExtent,
  double bandHeight = 0,
  double chromeHeight = 0,
  Size surface = const Size(1200, 900),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final scaffold = BrowseScaffold<String>(
    contentLabel: 'items',
    heroItems: const ['a', 'b'],
    rows: const [],
    heroBuilder: slide,
    itemBuilder: card,
    heroHeightOf: heroHeightOf,
    belowHero: bandHeight > 0 ? SizedBox(height: bandHeight) : null,
    belowHeroExtent: belowHeroExtent,
    // Rotation would leave a pending timer at test end.
    heroInterval: null,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: chromeHeight > 0
          // Stands in for AdaptiveNavShell's top bar and section chip row:
          // the scaffold gets the window minus that, and the hero has to be
          // sized from what it got.
          ? Column(
              children: [
                SizedBox(height: chromeHeight),
                Expanded(child: scaffold),
              ],
            )
          : scaffold,
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

    testWidgets('fills the viewport above the below-hero band', (tester) async {
      // What the sizing is for: hero + Continue Watching come to exactly one
      // screen, so that row is the last thing above the fold rather than a
      // strip with the start of two more rows under it.
      await pumpScaffold(tester, bandHeight: 300, belowHeroExtent: (_) => 300);

      expect(heroHeight(tester), closeTo(600, 0.5));
    });

    testWidgets('measures the viewport, not the window', (tester) async {
      // MediaQuery would report 900 here; the scroll view only got 760. Using
      // the window would overshoot by the chrome and push the band off the
      // fold -- worst on a phone, where the chrome is top bar *and* bottom
      // tab bar.
      await pumpScaffold(
        tester,
        chromeHeight: 140,
        bandHeight: 300,
        belowHeroExtent: (_) => 300,
      );

      expect(heroHeight(tester), closeTo(460, 0.5));
    });

    testWidgets('the band extent sees the window width', (tester) async {
      late double seenWidth;
      await pumpScaffold(
        tester,
        surface: const Size(430, 800),
        bandHeight: 260,
        belowHeroExtent: (width) {
          seenWidth = width;
          return 260;
        },
      );

      expect(seenWidth, 430);
      expect(heroHeight(tester), closeTo(540, 0.5));
    });

    testWidgets('a short window keeps a usable hero', (tester) async {
      // 520 - 300 = 220, which is less artwork than the slide is worth. The
      // floor wins and the band scrolls, rather than the hero collapsing.
      await pumpScaffold(
        tester,
        surface: const Size(1200, 520),
        bandHeight: 300,
        belowHeroExtent: (_) => 300,
      );

      expect(heroHeight(tester), 380);
    });

    testWidgets('a very tall window does not get a hero to match', (
      tester,
    ) async {
      // 2000 - 300 = 1700. Filling that would be a poster the height of a
      // door; the ceiling takes over and more rows show, which on a screen
      // that big is the better answer anyway.
      await pumpScaffold(
        tester,
        surface: const Size(1200, 2000),
        bandHeight: 300,
        belowHeroExtent: (_) => 300,
      );

      expect(heroHeight(tester), 900);
    });

    testWidgets('an explicit height still wins over the band', (tester) async {
      // Live TV supplies both in principle; its user-chosen style has to
      // survive, so heroHeightOf is checked first.
      await pumpScaffold(
        tester,
        bandHeight: 300,
        belowHeroExtent: (_) => 300,
        heroHeightOf: (_, __) => 240,
      );

      expect(heroHeight(tester), 240);
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
