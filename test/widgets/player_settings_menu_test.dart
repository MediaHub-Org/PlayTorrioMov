// test/widgets/player_settings_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

PlayerSettingsMenu menu({
  void Function()? onQuality,
  void Function()? onSpeed,
  void Function()? onSleep,
  void Function()? onAspect,
  void Function()? onStats,
}) =>
    PlayerSettingsMenu(
      currentRate: 1.5,
      qualitySummary: '1080p',
      aspectSummary: 'Original',
      statsSummary: 'Torrent',
      onOpenQuality: onQuality,
      onOpenSpeed: onSpeed ?? () {},
      onOpenSleep: onSleep ?? () {},
      onOpenAspect: onAspect ?? () {},
      onOpenStats: onStats ?? () {},
    );

void main() {
  group('PlayerSettingsMenu', () {
    testWidgets('shows the four cards with their current values',
        (tester) async {
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('PLAYBACK SPEED'), findsOneWidget);
      expect(find.text('SLEEP TIMER'), findsOneWidget);
      expect(find.text('ASPECT RATIO'), findsOneWidget);
      expect(find.text('STREAM STATS'), findsOneWidget);
      expect(find.text('1.50×'), findsOneWidget);
      expect(find.text('Torrent'), findsOneWidget);
    });

    testWidgets('each card steps into its own panel', (tester) async {
      var speed = false;
      var sleep = false;
      var aspect = false;
      var stats = false;
      await tester.pumpWidget(wrap(menu(
        onSpeed: () => speed = true,
        onSleep: () => sleep = true,
        onAspect: () => aspect = true,
        onStats: () => stats = true,
      )));

      await tester.tap(find.text('PLAYBACK SPEED'));
      await tester.tap(find.text('SLEEP TIMER'));
      await tester.tap(find.text('ASPECT RATIO'));
      await tester.tap(find.text('STREAM STATS'));

      expect(speed, isTrue);
      expect(sleep, isTrue);
      expect(aspect, isTrue);
      expect(stats, isTrue);
    });

    testWidgets('the quality row opens Sources, with the current quality',
        (tester) async {
      var quality = false;
      await tester.pumpWidget(wrap(menu(onQuality: () => quality = true)));

      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);

      await tester.tap(find.text('Quality'));
      expect(quality, isTrue);
    });

    testWidgets('without an episode there is no quality row', (tester) async {
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('Quality'), findsNothing);
    });

    testWidgets('the four controls are cards, not radio rows', (tester) async {
      await tester.pumpWidget(wrap(menu(onQuality: () {})));

      // Five labels, zero radios: quality plus the 2x2 of cards.
      for (final label in [
        'Quality',
        'PLAYBACK SPEED',
        'SLEEP TIMER',
        'ASPECT RATIO',
        'STREAM STATS',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The quality row keeps its (unselected) radio mark; what must not
      // be there is a selected one -- nothing on this menu is a choice
      // among the rows anymore.
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
    });

    testWidgets('cards without a value show the label alone', (tester) async {
      await tester.pumpWidget(wrap(PlayerSettingsMenu(
        currentRate: 1.0,
        onOpenSpeed: () {},
        onOpenSleep: () {},
        onOpenAspect: () {},
        onOpenStats: () {},
      )));

      expect(find.text('1.00×'), findsOneWidget);
      // Aspect and stats summaries are null here: their cards show the
      // label with no value beneath it.
      expect(find.text('ASPECT RATIO'), findsOneWidget);
      expect(find.text('STREAM STATS'), findsOneWidget);
    });
  });
}
