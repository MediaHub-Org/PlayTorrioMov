// test/widgets/header_pill_min_size_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/filter_dropdown.dart';
import 'package:playtorriomov/widgets/common/header_pill_style.dart';
import 'package:playtorriomov/widgets/common/page_search_button.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(
        // A narrow surface so FilterDropdown renders icon-only (mobile
        // tier), the smallest case.
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    );

void main() {
  group('Header pill controls keep a minimum tap target', () {
    testWidgets('HeaderPillIconButton is at least headerPillMinSize', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          HeaderPillIconButton(
            icon: Icons.cast_rounded,
            tooltip: 'Cast',
            onTap: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(HeaderPillIconButton));
      expect(size.width, greaterThanOrEqualTo(headerPillMinSize));
      expect(size.height, greaterThanOrEqualTo(headerPillMinSize));
    });

    testWidgets('PageSearchButton is at least headerPillMinSize', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const PageSearchButton()));
      final size = tester.getSize(find.byType(PageSearchButton));
      expect(size.width, greaterThanOrEqualTo(headerPillMinSize));
      expect(size.height, greaterThanOrEqualTo(headerPillMinSize));
    });

    testWidgets(
      'FilterDropdown is at least headerPillMinSize even icon-only',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrap(
            FilterDropdown<String>(
              label: 'All genres',
              icon: Icons.category_rounded,
              items: const [
                PopupMenuItem(value: 'a', child: Text('a')),
              ],
              onSelected: (_) {},
            ),
          ),
        );
        final size = tester.getSize(find.byType(FilterDropdown<String>));
        expect(size.width, greaterThanOrEqualTo(headerPillMinSize));
        expect(size.height, greaterThanOrEqualTo(headerPillMinSize));
      },
    );
  });
}
