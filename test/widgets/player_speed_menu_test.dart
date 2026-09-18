// test/widgets/player_speed_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PlayerSpeedMenu', () {
    // The list of rows this replaced offered seven speeds and no 0.25x, and
    // a row per speed is a lot of vertical space for a control people nudge
    // one step at a time. The slider carries the same choices as points.

    testWidgets('shows the current rate', (tester) async {
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.25,
        onRateSelected: (_) {},
        onClose: () {},
      )));

      expect(find.text('1.25×'), findsOneWidget);
    });

    testWidgets('offers 0.25x, which the old list omitted', (tester) async {
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: (_) {},
        onClose: () {},
      )));

      expect(find.text('0.25'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('dragging the slider reports a rate from the point set',
        (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: reported.add,
        onClose: () {},
      )));

      // Drag the thumb to the far right: the last point is 2.0x.
      await tester.drag(find.byType(Slider), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported.last, 2.0);
    });

    testWidgets('closes once the drag ends', (tester) async {
      var closed = false;
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: (_) {},
        onClose: () => closed = true,
      )));

      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(closed, isTrue,
          reason: 'the menu is a popover; a chosen speed should dismiss it');
    });
  });
}
