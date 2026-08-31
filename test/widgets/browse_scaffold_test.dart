// test/widgets/browse_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/widgets/common/browse_scaffold.dart';
import 'package:playtorrio/widgets/common/slider_arrow.dart';

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
}) {
  return BrowseScaffold<String>(
    heroItems: hero,
    rows: rows,
    isLoading: isLoading,
    error: error,
    emptyState: emptyState,
    // Auto-rotation would leave a pending timer at the end of every test.
    heroInterval: null,
    heroBuilder: (_, item) => ColoredBox(
      color: Colors.blue,
      child: Center(child: Text('hero:$item')),
    ),
    itemBuilder: (_, item) => Text(item),
  );
}

List<String> items(int n, [String prefix = 'item']) =>
    [for (var i = 0; i < n; i++) '$prefix$i'];

void main() {
  group('BrowseScaffold', () {
    testWidgets('renders the hero and every non-empty row', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(wrap(build(
        hero: ['a'],
        rows: [
          BrowseRow(title: 'Trending', items: items(4)),
          const BrowseRow(title: 'Empty', items: []),
          BrowseRow(title: 'Latest', items: items(4, 'late')),
        ],
      )));
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
      await tester.pumpWidget(wrap(build(
        rows: [
          BrowseRow(
            title: 'Trending',
            subtitle: 'Top popular series',
            items: items(4),
          ),
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Top popular series'), findsOneWidget);
    });

    testWidgets('arrows stay off-screen until the row is hovered',
        (tester) async {
      // Arrows are gated on hover alone, not on width or platform: a touch
      // device never fires onEnter, so it never reveals one. That means they
      // are *built* at every size, and what matters is that they sit outside
      // the viewport until a pointer arrives — asserting they are absent
      // would have been asserting the old width check, not the behaviour.
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(build(
        hero: ['a', 'b', 'c'],
        rows: [BrowseRow(title: 'Trending', items: items(30))],
      )));
      await tester.pumpAndSettle();

      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (final arrow in tester.widgetList<SliderArrow>(find.byType(SliderArrow))) {
        final rect = tester.getRect(find.byWidget(arrow));
        expect(
          rect.right <= 0 || rect.left >= width,
          isTrue,
          reason: 'an un-hovered arrow must be off-screen, not overlapping '
              'the artwork it sits on (was at $rect on a ${width}px surface)',
        );
      }
    });

    testWidgets('a hero with several slides and a scrollable row both get '
        'a back and forward arrow', (tester) async {
      setSurfaceWidth(tester, 1400);
      await tester.pumpWidget(wrap(build(
        hero: ['a', 'b', 'c'],
        rows: [BrowseRow(title: 'Trending', items: items(30))],
      )));
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
      await tester.pumpWidget(wrap(build(
        hero: ['a'],
        rows: [BrowseRow(title: 'Trending', items: items(4))],
        error: 'no network',
      )));
      await tester.pumpAndSettle();

      expect(find.text('hero:a'), findsNothing);
      expect(find.text('Trending'), findsNothing);
    });

    testWidgets('empty state shows only once loading has finished',
        (tester) async {
      setSurfaceWidth(tester, 1400);
      const empty = Text('nothing here');

      await tester.pumpWidget(wrap(build(isLoading: true, emptyState: empty)));
      await tester.pump();
      expect(find.text('nothing here'), findsNothing,
          reason: 'an empty state while still loading reads as a failure');

      await tester.pumpWidget(wrap(build(isLoading: false, emptyState: empty)));
      await tester.pumpAndSettle();
      expect(find.text('nothing here'), findsOneWidget);
    });
  });
}
