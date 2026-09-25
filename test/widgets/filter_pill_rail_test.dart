// test/widgets/filter_pill_rail_test.dart
//
// The rail is shared by the phone and desktop layouts of the watch screen,
// and the two get different affordances: a tappable chevron button on
// desktop, the edge fade alone on touch. That split is the whole point of
// the widget's platform check, and it is the part a regression would quietly
// undo -- a button reappearing on a phone puts a tap target over the first
// and last pill, which is a bug you cannot see in a screenshot.
//
// The rail is pumped directly rather than through WatchScreen: the screen
// loads its sources over the network, so reaching the rail through it would
// make this a network test for no benefit.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/pages/player/watch_screen.dart';

/// A pill wide enough that four of them cannot fit the rail's frame.
Widget pill(String label) => SizedBox(
  key: Key(label),
  width: 140,
  height: 36,
  child: Center(child: Text(label)),
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The rail measures itself against the surface, so the surface width is
/// what decides whether it overflows.
void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Runs [body] with the platform reported as [platform].
///
/// `debugDefaultTargetPlatformOverride` is what `defaultTargetPlatform`
/// reads, and it is the same lever the app's own `isDesktopPlatform()` uses
/// to decide. It must be cleared even if the body throws, or every later
/// test in the file inherits the platform.
Future<void> withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The chevron buttons, found by their icons. The rail draws one per end
/// when it overflows, so a count of 2 means both ends are showing.
Finder chevrons() => find.byWidgetPredicate(
  (w) =>
      w is Icon &&
      (w.icon == Icons.chevron_left_rounded ||
          w.icon == Icons.chevron_right_rounded),
);

void main() {
  group('FilterPillRail overflow', () {
    testWidgets('a row too short to overflow shows no edge affordance', (
      tester,
    ) async {
      setSurfaceWidth(tester, 800);
      await withPlatform(TargetPlatform.windows, () async {
        await tester.pumpWidget(
          wrap(const FilterPillRail(children: [SizedBox(width: 60)])),
        );
        await tester.pumpAndSettle();

        expect(
          chevrons(),
          findsNothing,
          reason: 'nothing is hidden, so there is nothing to indicate',
        );
      });
    });

    testWidgets('an overflowing row shows an affordance at both ends', (
      tester,
    ) async {
      setSurfaceWidth(tester, 400);
      await withPlatform(TargetPlatform.windows, () async {
        await tester.pumpWidget(
          wrap(
            FilterPillRail(
              children: [pill('a'), pill('b'), pill('c'), pill('d')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both ends, not just the right one. Showing only the live end made
        // the row look lopsided and left it with no control at all once
        // scrolled to the far end.
        expect(chevrons(), findsNWidgets(2));
      });
    });
  });

  group('FilterPillRail platform split', () {
    testWidgets('desktop gets tappable chevron buttons', (tester) async {
      setSurfaceWidth(tester, 400);
      await withPlatform(TargetPlatform.windows, () async {
        await tester.pumpWidget(
          wrap(
            FilterPillRail(
              children: [pill('a'), pill('b'), pill('c'), pill('d')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(chevrons(), findsNWidgets(2));
        // A button is something you can press, so it carries a tap handler.
        expect(
          find.byType(GestureDetector),
          findsWidgets,
          reason: 'the desktop chevrons must be tappable',
        );
      });
    });

    testWidgets('touch platforms get the fade but no button', (tester) async {
      setSurfaceWidth(tester, 400);
      await withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          wrap(
            FilterPillRail(
              children: [pill('a'), pill('b'), pill('c'), pill('d')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The regression this guards: a chevron button over the first and
        // last pill on a phone, where the row is dragged and a tap meant for
        // a pill would land on the button instead.
        expect(
          chevrons(),
          findsNothing,
          reason: 'a phone drags the row; it must not get a button over it',
        );
      });
    });

    testWidgets('a tablet is treated as touch, not as desktop', (
      tester,
    ) async {
      // Wide enough to pass every breakpoint, and still a touch device. The
      // check is the platform, not the width, and this is the case that
      // would catch it being changed to a width check.
      //
      // The pills are sized to overflow even at this width, so the test is
      // not vacuous: at 1200px a row of 140px pills would fit, the rail
      // would report no overflow, and "no chevrons" would pass for the wrong
      // reason. Six of them cannot fit.
      setSurfaceWidth(tester, 1200);
      await withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          wrap(
            FilterPillRail(
              children: [
                pill('a'),
                pill('b'),
                pill('c'),
                pill('d'),
                pill('e'),
                pill('f'),
                pill('g'),
                pill('h'),
                pill('i'),
                pill('j'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(chevrons(), findsNothing);
      });
    });
  });
}