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
              SubTab(id: 'movie', label: 'Movies', icon: Icons.movie_rounded),
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

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
    });

    testWidgets('tapping a tab reports its id', (tester) async {
      String? picked;
      await tester.pumpWidget(
        wrap(
          PillTabRow(
            tabs: const [
              SubTab(id: 'movie', label: 'Movies', icon: Icons.movie_rounded),
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
  });
}
