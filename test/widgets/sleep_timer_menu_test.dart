// test/widgets/sleep_timer_menu_test.dart
//
// Six rows, one per choice, and nothing else. The menu used to carry a custom
// stepper and a "pauses at 02:14" line under every preset; both are gone, and
// this keeps them from coming back one at a time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/player/sleep_timer_service.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';

Widget wrap() => const MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: SleepTimerMenu())),
);

void main() {
  final timer = SleepTimerService.instance;

  setUp(timer.cancel);
  tearDown(timer.cancel);

  group('SleepTimerMenu', () {
    testWidgets('offers exactly the six choices, one per row', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      // Five presets plus end of video. A row each, which is the shape the
      // menu was asked for -- the old one had a Wrap of chips above a
      // divider and a pair of steppers below it.
      expect(find.byType(PlayerMenuRow), findsNWidgets(6));
      for (final label in ['10 min', '15 min', '30 min', '45 min', '60 min']) {
        expect(find.text(label), findsOneWidget, reason: '$label is a preset');
      }
      expect(find.text('End of video'), findsOneWidget);
    });

    testWidgets('no custom stepper, and no end-time line', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Custom'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.textContaining('pauses at'), findsNothing);
    });

    testWidgets('tapping a preset arms it and marks that row', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text('30 min'));
      await tester.pump();

      expect(timer.minutesRemaining.value, 30);

      // The tick is the only feedback, so the row that carries it is the
      // thing to assert.
      final selected = tester.widgetList<PlayerMenuRow>(
        find.byType(PlayerMenuRow),
      );
      expect(selected.where((r) => r.isSelected).length, 1);

      // A minute countdown arms a periodic Timer, and a widget test must not
      // leave one pending.
      timer.cancel();
    });

    testWidgets('End of video arms the flag rather than a countdown', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text('End of video'));
      await tester.pump();

      expect(timer.armedForEndOfVideo.value, isTrue);
      expect(timer.minutesRemaining.value, isNull);
    });

    testWidgets('the cancel row appears only once something is armed', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byIcon(Icons.timer_off_outlined), findsNothing);

      await tester.tap(find.text('End of video'));
      await tester.pump();
      expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    });

    testWidgets('cancel clears whichever kind was armed', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text('End of video'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.timer_off_outlined));
      await tester.pump();

      expect(timer.isArmed, isFalse);
    });
  });
}