// test/widgets/filter_dropdown_width_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/filter_dropdown.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('the menu opens exactly as wide as the pill it came from', (tester) async {
    // Laid out as the search bar lays it out: a horizontal scroll row, so the
    // pill takes its own width rather than the screen's.
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterDropdown<String?>(
                label: 'All genres',
                icon: Icons.category_rounded,
                selectedValue: '',
                items: const [
                  PopupMenuItem(value: '', child: Text('All genres')),
                  PopupMenuItem(value: 'Action', child: Text('Action')),
                ],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    // The visible pill is the decorated container inside the tap target.
    final pill = find.ancestor(
      of: find.text('All genres'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration != null,
      ),
    );
    final pillWidth = tester.getSize(pill).width;

    await tester.tap(find.byType(FilterDropdown<String?>));
    await tester.pumpAndSettle();

    // A menu row stretches to the menu's own width, so its width is the menu's.
    final row = find.byType(PopupMenuItem<String?>).first;
    expect(tester.getSize(row).width, pillWidth);
  });
}
