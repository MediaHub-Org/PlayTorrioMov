// test/widgets/player_speed_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
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

    testWidgets('has no preset chips and no -/+ buttons, only the slider', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: (_) {},
        onClose: () {},
      )));

      expect(find.text('Normal'), findsNothing);
      expect(find.text('1.5'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byType(PlayerIconButton), findsNothing);
    });

    testWidgets('normal speed sits in the middle of the track', (tester) async {
      await tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: 1.0,
        onRateSelected: (_) {},
        onClose: () {},
      )));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, (slider.min + slider.max) / 2,
          reason: 'three steps slower on one side, three faster on the other');
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
    group('with a remote', () {
      Future<void> pumpMenu(
        WidgetTester tester, {
        double rate = 1.0,
        required List<double> reported,
        required List<String> events,
      }) => tester.pumpWidget(wrap(PlayerSpeedMenu(
        currentRate: rate,
        onRateSelected: (r) {
          reported.add(r);
          events.add('rate $r');
        },
        onClose: () => events.add('close'),
      )));

      testWidgets('Right steps up and Left steps down, one point each', (
        tester,
      ) async {
        final reported = <double>[];
        await pumpMenu(tester, reported: reported, events: []);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

        expect(reported, [1.25, 0.75]);
      });

      testWidgets('reaches 0.25x and 2x, and stops at the ends', (
        tester,
      ) async {
        final slow = <double>[];
        await pumpMenu(tester, rate: 0.5, reported: slow, events: []);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        expect(slow, [0.25]);

        final fast = <double>[];
        await pumpMenu(tester, rate: 2.0, reported: fast, events: []);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(fast, isEmpty, reason: 'nothing above 2x to step to');

        final stepped = <double>[];
        await pumpMenu(tester, rate: 1.5, reported: stepped, events: []);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(stepped, [2.0], reason: '2x is one step past 1.5x');
      });

      testWidgets('stays open while the arrows step, and closes on OK', (
        tester,
      ) async {
        // It closed after the first press: every arrow was reported as a
        // finished drag, so a viewer going from 1x to 1.5x lost the menu
        // after 1.25x.
        final events = <String>[];
        await pumpMenu(tester, reported: [], events: events);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(events, ['rate 1.25', 'rate 1.25'],
            reason: 'two presses reported, no close');

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        expect(events.last, 'close');
      });

      testWidgets('has no border around the slider by default', (
        tester,
      ) async {
        await pumpMenu(tester, reported: [], events: []);
        await tester.pump();

        // Autofocus put the slider in focus; the frame that used to come
        // with that was on screen from the moment the menu opened.
        final box = find.descendant(
          of: find.byType(PlayerStepSlider),
          matching: find.byType(DecoratedBox),
        );
        for (final decorated in tester.widgetList<DecoratedBox>(box)) {
          final decoration = decorated.decoration;
          if (decoration is BoxDecoration) {
            expect(decoration.border, isNull);
          }
        }
      });
    });
  });
}
