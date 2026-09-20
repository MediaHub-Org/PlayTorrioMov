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

    testWidgets('shows a chip per common speed, captioning normal',
        (tester) async {
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: (_) {},
        onClose: () {},
      )));

      for (final label in ['0.5', '0.75', '1', '1.25', '1.5', '2']) {
        expect(find.text(label), findsOneWidget, reason: 'chip $label');
      }
      expect(find.text('Normal'), findsOneWidget);
    });

    testWidgets('tapping a chip picks that speed and keeps the menu open',
        (tester) async {
      final reported = <double>[];
      var closed = false;
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: reported.add,
        onClose: () => closed = true,
      )));

      await tester.tap(find.text('1.5'));
      await tester.pump();

      expect(reported, [1.5]);
      expect(closed, isFalse, reason: 'so the next nudge does not reopen it');
    });

    testWidgets('the -/+ buttons take one step each', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: reported.add,
        onClose: () {},
      )));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));

      expect(reported, [1.25, 0.75]);
    });

    testWidgets('the slower button reaches 0.25x, which the chips omit',
        (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 0.5,
        onRateSelected: reported.add,
        onClose: () {},
      )));

      await tester.tap(find.byIcon(Icons.remove_rounded));

      expect(reported, [0.25]);
    });

    testWidgets('the buttons stop at the ends of the range', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 2.0,
        onRateSelected: reported.add,
        onClose: () {},
      )));

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(reported, isEmpty, reason: 'nothing above 2x to step to');
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
