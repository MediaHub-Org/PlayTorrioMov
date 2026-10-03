// test/widgets/filter_dropdown_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/filter_dropdown.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// A genre-style menu: the "All" reset is a sentinel, since a null route
/// result means dismissal and never reaches onSelected.
FilterDropdown<String?> genreMenu({
  String? selected,
  ValueChanged<String?>? onSelected,
}) =>
    FilterDropdown<String?>(
      label: selected ?? 'All genres',
      icon: Icons.category_rounded,
      selectedValue: selected ?? '',
      items: const [
        PopupMenuItem(value: '', child: Text('All genres')),
        PopupMenuItem(value: 'Action', child: Text('Action')),
        PopupMenuItem(value: 'Drama', child: Text('Drama')),
      ],
      onSelected: onSelected ?? (_) {},
    );

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(FilterDropdown<String?>));
  await tester.pumpAndSettle();
}

void main() {
  group('FilterDropdown', () {
    testWidgets('ticks the selected value', (tester) async {
      await tester.pumpWidget(wrap(genreMenu(selected: 'Drama')));
      await openMenu(tester);

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // The tick sits on Drama's row, not on All's.
      final row = tester.widget<PopupMenuItem<String?>>(
        find.ancestor(
          of: find.text('Drama'),
          matching: find.byType(PopupMenuItem<String?>),
        ),
      );
      expect(row.value, 'Drama');
    });

    testWidgets('reports the tapped value, sentinel included', (tester) async {
      final reported = <String?>[];
      await tester.pumpWidget(wrap(genreMenu(onSelected: reported.add)));
      await openMenu(tester);

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(reported, ['Action']);

      await openMenu(tester);
      // The pill carries the same words at this width, so the menu's row is
      // the later match -- the route paints on top.
      await tester.tap(find.text('All genres').last);
      await tester.pumpAndSettle();
      expect(reported, ['Action', '']);
    });

    testWidgets('a dismissal reports nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        wrap(genreMenu(onSelected: (_) => calls++)),
      );
      await openMenu(tester);

      // Outside the menu: the route pops with a null result.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('a long list is capped instead of running off screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          FilterDropdown<int>(
            label: 'Decades',
            icon: Icons.calendar_today_rounded,
            items: [
              for (var i = 0; i < 60; i++)
                PopupMenuItem(value: i, child: Text('Item $i')),
            ],
            onSelected: (_) {},
          ),
        ),
      );
      await tester.tap(find.byType(FilterDropdown<int>));
      await tester.pumpAndSettle();

      // Sixty 48px rows would want ~2900px uncapped; the menu card is the
      // topmost Material and must stay at the 22 rem ceiling (352px at 1x).
      final menu = tester.getSize(find.byType(Material).last);
      expect(menu.height, lessThan(400));
      expect(menu.height, greaterThan(200));
    });
  });
}
