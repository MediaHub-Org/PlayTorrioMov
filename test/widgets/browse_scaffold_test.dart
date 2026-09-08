// test/widgets/browse_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/browse_scaffold.dart';
import 'package:playtorriomov/widgets/common/custom_scroll_track.dart';
import 'package:playtorriomov/widgets/common/slider_arrow.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

BrowseScaffold<String> build({
  List<String> hero = const [],
  List<BrowseRow<String>> rows = const [],
  bool isLoading = false,
  String? error,
  Widget? emptyState,
  Widget? belowHero,
  Widget? afterRows,
  Widget? header,
}) {
  return BrowseScaffold<String>(
    heroItems: hero,
    rows: rows,
    isLoading: isLoading,
    error: error,
    emptyState: emptyState,
    belowHero: belowHero,
    afterRows: afterRows,
    header: header,
    // Auto-rotation would leave a pending timer at the end of every test.
    heroInterval: null,
    heroBuilder: (_, item) => ColoredBox(
      key: const Key('hero-box'),
      color: Colors.blue,
      child: Center(child: Text('hero:$item')),
    ),
    itemBuilder: (_, item) => Text(item),
  );
}

List<String> items(int n, [String prefix = 'item']) => [
  for (var i = 0; i < n; i++) '$prefix$i',
];

void main() {
  group('BrowseScaffold', () {
    testWidgets('renders the hero and every non-empty row', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(
          build(
            hero: ['a'],
            rows: [
              BrowseRow(title: 'Trending', items: items(4)),
              const BrowseRow(title: 'Empty', items: []),
              BrowseRow(title: 'Latest', items: items(4, 'late')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('hero:a'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      // A row with no items is a row the caller has no data for yet; drawing
      // its heading over nothing reads as a failure.
      expect(find.text('Empty'), findsNothing);
    });

    testWidgets('renders a row subtitle when one is given', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(
          build(
            rows: [
              BrowseRow(
                title: 'Trending',
                subtitle: 'Top popular series',
                items: items(4),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Top popular series'), findsOneWidget);
    });

    testWidgets('arrows stay off-screen until the row is hovered', (
      tester,
    ) async {
      // Arrows are gated on hover alone, not on width or platform: a touch
      // device never fires onEnter, so it never reveals one. That means they
      // are *built* at every size, and what matters is that they sit outside
      // the viewport until a pointer arrives — asserting they are absent
      // would have been asserting the old width check, not the behaviour.
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(
        wrap(
          build(
            hero: ['a', 'b', 'c'],
            rows: [BrowseRow(title: 'Trending', items: items(30))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (final arrow in tester.widgetList<SliderArrow>(
        find.byType(SliderArrow),
      )) {
        final rect = tester.getRect(find.byWidget(arrow));
        expect(
          rect.right <= 0 || rect.left >= width,
          isTrue,
          reason:
              'an un-hovered arrow must be off-screen, not overlapping '
              'the artwork it sits on (was at $rect on a ${width}px surface)',
        );
      }
    });

    testWidgets('a hero with several slides and a scrollable row both get '
        'a back and forward arrow', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(
          build(
            hero: ['a', 'b', 'c'],
            rows: [BrowseRow(title: 'Trending', items: items(30))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two per carousel: back and forward, for the hero and for the row.
      expect(find.byType(SliderArrow), findsNWidgets(4));
    });

    testWidgets('a single hero slide gets no hero arrows', (tester) async {
      // Nothing to page to, so the arrows would be dead controls.
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(wrap(build(hero: ['only'])));
      await tester.pumpAndSettle();

      expect(find.byType(SliderArrow), findsNothing);
    });

    testWidgets('error replaces the content', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(
          build(
            hero: ['a'],
            rows: [BrowseRow(title: 'Trending', items: items(4))],
            error: 'no network',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('hero:a'), findsNothing);
      expect(find.text('Trending'), findsNothing);
    });

    testWidgets('empty state shows only once loading has finished', (
      tester,
    ) async {
      setSurfaceWidth(tester, 1400);
      const empty = Text('nothing here');

      await tester.pumpWidget(wrap(build(isLoading: true, emptyState: empty)));
      await tester.pump();
      expect(
        find.text('nothing here'),
        findsNothing,
        reason: 'an empty state while still loading reads as a failure',
      );

      await tester.pumpWidget(wrap(build(isLoading: false, emptyState: empty)));
      await tester.pumpAndSettle();
      expect(find.text('nothing here'), findsOneWidget);
    });

    testWidgets('belowHero renders under the hero, only when there is one', (
      tester,
    ) async {
      setSurfaceWidth(tester, 1400);

      // No hero items -> belowHero must not render either.
      await tester.pumpWidget(wrap(build(belowHero: const Text('CW row'))));
      await tester.pumpAndSettle();
      expect(find.text('CW row'), findsNothing);

      // A hero -> belowHero renders alongside it.
      await tester.pumpWidget(
        wrap(build(hero: ['a'], belowHero: const Text('CW row'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('hero:a'), findsOneWidget);
      expect(find.text('CW row'), findsOneWidget);
    });

    testWidgets('afterRows renders after every row', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(
          build(
            rows: [BrowseRow(title: 'Trending', items: items(2))],
            afterRows: const Text('footer row'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('footer row'), findsOneWidget);
    });

    testWidgets(
      'the header sits above the hero rather than over it',
      (tester) async {
        setSurfaceWidth(tester, 1400); // desktop tier
        await tester.pumpWidget(
          wrap(build(hero: ['a'], header: const Text('filters'))),
        );
        await tester.pumpAndSettle();

        expect(find.text('filters'), findsOneWidget);
        expect(find.text('hero:a'), findsOneWidget);

        // The header owns a band at the top of the page and the hero starts
        // below it. It used to be nested in the hero's own Stack, drawn over
        // a hero that ran to y = 0.
        final headerBottom = tester.getBottomLeft(find.text('filters')).dy;
        final heroTop = tester.getTopLeft(find.byKey(const Key('hero-box'))).dy;
        expect(heroTop, greaterThan(0.0));
        expect(heroTop, greaterThanOrEqualTo(headerBottom));
      },
    );

    testWidgets(
      'the header stays put while the page scrolls under it',
      (tester) async {
        // Regression test for the reverse of the old behaviour: the header
        // used to be nested inside the hero, so it scrolled away with it.
        // It now lives outside the scroll viewport, which is what makes it
        // stay fixed without content sliding visibly underneath it.
        setSurfaceWidth(tester, 1400);
        await tester.pumpWidget(
          wrap(
            build(
              hero: ['a'],
              header: const Text('filters'),
              rows: [BrowseRow(title: 'Trending', items: items(10))],
              // Guarantees enough scroll extent regardless of row/card
              // sizing -- without it, the fixed 900px test viewport can fit
              // the whole page and there is nothing to scroll.
              afterRows: const SizedBox(height: 3000),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final headerY = tester.getTopLeft(find.text('filters')).dy;

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        expect(find.text('filters'), findsOneWidget);
        expect(tester.getTopLeft(find.text('filters')).dy, headerY);
        // The hero really did scroll -- otherwise the assertion above is
        // only saying that nothing moved at all.
        expect(find.byKey(const Key('hero-box')), findsNothing);
      },
    );

    testWidgets('the scroll track is desktop-only', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(
        wrap(build(hero: ['a'], header: const Text('filters'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomScrollTrack), findsOneWidget);

      setSurfaceWidth(tester, 420);
      await tester.pumpWidget(
        wrap(build(hero: ['a'], header: const Text('filters'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomScrollTrack), findsNothing);
    });
  });
}
