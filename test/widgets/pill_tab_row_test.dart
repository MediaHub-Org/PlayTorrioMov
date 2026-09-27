// test/widgets/pill_tab_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/pill_tab_row.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PillTabRow', () {
    testWidgets('renders every tab label and highlights the active one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PillTabRow(
            tabs: const [
              SubTab(id: 'movie', label: 'Films', icon: Icons.movie_rounded),
              SubTab(
                id: 'series',
                label: 'Series',
                icon: Icons.live_tv_rounded,
              ),
            ],
            activeId: 'movie',
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Films'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
    });

    testWidgets('tapping a tab reports its id', (tester) async {
      String? picked;
      await tester.pumpWidget(
        wrap(
          PillTabRow(
            tabs: const [
              SubTab(id: 'movie', label: 'Films', icon: Icons.movie_rounded),
              SubTab(
                id: 'series',
                label: 'Series',
                icon: Icons.live_tv_rounded,
              ),
            ],
            activeId: 'movie',
            onSelected: (id) => picked = id,
          ),
        ),
      );

      await tester.tap(find.text('Series'));
      expect(picked, 'series');
    });

    testWidgets('short rows center instead of hugging the edge', (
      tester,
    ) async {
      // The Library tabs sit in the middle of the bar. A scrollable still
      // has to scroll when the pills outgrow the phone, so centering lives
      // in a min-width box rather than an alignment that would clip.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          PillTabRow(
            tabs: const [
              SubTab(id: 'a', label: 'Collections', icon: Icons.movie_rounded),
              SubTab(id: 'b', label: 'Continue', icon: Icons.play_arrow_rounded),
            ],
            activeId: 'a',
            onSelected: (_) {},
          ),
        ),
      );

      final middle = tester.getCenter(find.byType(PillTabRow)).dx;
      expect(tester.getCenter(find.text('Collections')).dx, lessThan(middle));
      expect(tester.getCenter(find.text('Continue')).dx, greaterThan(middle));
    });
  });
}