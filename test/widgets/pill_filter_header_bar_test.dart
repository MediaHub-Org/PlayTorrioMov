// test/widgets/pill_filter_header_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_spacing.dart';
import 'package:playtorriomov/widgets/common/pill_filter_header_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The inset is breakpoint-driven, so the surface width -- not a wrapping
/// SizedBox -- is what the bar actually measures itself against.
void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A pill wide enough that four of them cannot fit a phone-width bar.
Widget pill(String label) => SizedBox(
  key: Key(label),
  width: 140,
  height: 40,
  child: Center(child: Text(label)),
);

void main() {
  group('PillFilterHeaderBar', () {
    testWidgets('keeps every pill on one line when they overflow', (
      tester,
    ) async {
      // 4 x 140px of pills on a 400px phone: exactly the case the old Wrap
      // broke onto a second run, which changed the bar's height and shifted
      // the page content underneath it.
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            pills: [pill('a'), pill('b'), pill('c'), pill('d')],
          ),
        ),
      );

      final tops = <double>{
        for (final label in ['a', 'b', 'c', 'd'])
          tester.getTopLeft(find.byKey(Key(label))).dy,
      };
      expect(tops.length, 1, reason: 'pills must share one row');
    });

    testWidgets('bar height does not grow with the number of pills', (
      tester,
    ) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(PillFilterHeaderBar(pills: [pill('a')])));
      final withOne = tester.getSize(find.byType(PillFilterHeaderBar)).height;

      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            pills: [pill('a'), pill('b'), pill('c'), pill('d'), pill('e')],
          ),
        ),
      );
      final withFive = tester.getSize(find.byType(PillFilterHeaderBar)).height;

      expect(withFive, withOne);
      expect(withOne, pillFilterHeaderContentHeight);
    });

    testWidgets('does not re-inset a status bar the shell already cleared', (
      tester,
    ) async {
      // Regression test. The bar used to wrap itself in a SafeArea, but
      // AdaptiveNavShell already offsets past the status bar before the hub
      // content starts and does not removePadding -- so on a notched phone
      // the inset was counted twice and the bar was ~50px taller than
      // pillFilterHeaderContentHeight claims. Harmless while it floated
      // over the hero; it eats the scroll viewport now that it owns a band.
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 59)),
            child: Scaffold(body: PillFilterHeaderBar(pills: [pill('a')])),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PillFilterHeaderBar)).height,
        pillFilterHeaderContentHeight,
      );
    });

    testWidgets('overflowing pills scroll horizontally', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            pills: [pill('a'), pill('b'), pill('c'), pill('d')],
          ),
        ),
      );

      final before = tester.getTopLeft(find.byKey(const Key('a'))).dx;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(const Key('a'))).dx, lessThan(before));
    });

    testWidgets('leading pills sit at the leading edge, filters at the end', (
      tester,
    ) async {
      // Live TV's arrangement: a title run on the left, actions on the
      // right, in the same bar every other section uses.
      setSurfaceWidth(tester, 1000);
      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            leading: [pill('title')],
            pills: [pill('search')],
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byKey(const Key('title'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('search'))).dx),
      );
      // Same row, not stacked.
      expect(
        tester.getTopLeft(find.byKey(const Key('title'))).dy,
        tester.getTopLeft(find.byKey(const Key('search'))).dy,
      );
    });

    testWidgets('a lone pill stays against the trailing inset', (tester) async {
      setSurfaceWidth(tester, 1000);
      await tester.pumpWidget(wrap(PillFilterHeaderBar(pills: [pill('a')])));

      final expectedInset = AppSpacing.pageInset(
        tester.element(find.byType(PillFilterHeaderBar)),
      );
      expect(
        tester.getBottomRight(find.byKey(const Key('a'))).dx,
        closeTo(1000 - expectedInset, 0.5),
      );
    });

    Finder dividerFinder() => find.descendant(
      of: find.byType(PillFilterHeaderBar),
      matching: find.byType(DecoratedBox),
    );

    testWidgets('an opaque bar shows a divider by default', (tester) async {
      setSurfaceWidth(tester, 1000);
      await tester.pumpWidget(wrap(PillFilterHeaderBar(pills: [pill('a')])));

      expect(dividerFinder(), findsOneWidget);
    });

    testWidgets(
      'a transparent bar has no divider by default -- it floats over a '
      'hero, and a hard line cutting across the image would look like a '
      'rendering glitch, not a border',
      (tester) async {
        setSurfaceWidth(tester, 1000);
        await tester.pumpWidget(
          wrap(PillFilterHeaderBar(pills: [pill('a')], transparent: true)),
        );

        expect(dividerFinder(), findsNothing);
      },
    );

    testWidgets('showDivider always overrides the transparent-based default', (
      tester,
    ) async {
      setSurfaceWidth(tester, 1000);
      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            pills: [pill('a')],
            transparent: true,
            showDivider: true,
          ),
        ),
      );
      expect(dividerFinder(), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          PillFilterHeaderBar(
            pills: [pill('a')],
            showDivider: false,
          ),
        ),
      );
      expect(dividerFinder(), findsNothing);
    });
  });
}
