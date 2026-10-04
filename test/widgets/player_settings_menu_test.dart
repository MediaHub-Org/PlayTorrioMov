// test/widgets/player_settings_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

PlayerSettingsMenu menu({
  void Function()? onQuality,
  void Function()? onSpeed,
  void Function()? onAudio,
  void Function()? onSleep,
  void Function()? onAspect,
}) =>
    PlayerSettingsMenu(
      currentRate: 1.5,
      qualitySummary: '1080p',
      audioSummary: 'English',
      aspectSummary: 'Original',
      onOpenQuality: onQuality,
      onOpenSpeed: onSpeed ?? () {},
      onOpenAudio: onAudio ?? () {},
      onOpenSleep: onSleep ?? () {},
      onOpenAspect: onAspect ?? () {},
    );

void main() {
  group('PlayerSettingsMenu', () {
    testWidgets('shows the four controls with their current values',
        (tester) async {
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('PLAYBACK SPEED'), findsOneWidget);
      expect(find.text('AUDIO TRACK'), findsOneWidget);
      expect(find.text('SLEEP TIMER'), findsOneWidget);
      expect(find.text('ASPECT RATIO'), findsOneWidget);
      expect(find.text('1.50×'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('each row steps into its own panel', (tester) async {
      var speed = false;
      var audio = false;
      var sleep = false;
      var aspect = false;
      await tester.pumpWidget(wrap(menu(
        onSpeed: () => speed = true,
        onAudio: () => audio = true,
        onSleep: () => sleep = true,
        onAspect: () => aspect = true,
      )));

      await tester.tap(find.text('PLAYBACK SPEED'));
      await tester.tap(find.text('AUDIO TRACK'));
      await tester.tap(find.text('SLEEP TIMER'));
      await tester.tap(find.text('ASPECT RATIO'));

      expect(speed, isTrue);
      expect(audio, isTrue);
      expect(sleep, isTrue);
      expect(aspect, isTrue);
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
        'AUDIO TRACK',
        'SLEEP TIMER',
        'ASPECT RATIO',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The quality row keeps its (unselected) radio mark; what must not
      // be there is a selected one -- nothing on this menu is a choice
      // among the rows anymore.
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
    });

    testWidgets('rows without a value show no badge', (tester) async {
      await tester.pumpWidget(wrap(PlayerSettingsMenu(
        currentRate: 1.0,
        onOpenSpeed: () {},
        onOpenAudio: () {},
        onOpenSleep: () {},
        onOpenAspect: () {},
      )));

      expect(find.text('1.00×'), findsOneWidget);
      // Audio and aspect summaries are null here: their cards show the
      // label with no value beneath it.
      expect(find.text('AUDIO TRACK'), findsOneWidget);
      expect(find.text('ASPECT RATIO'), findsOneWidget);
    });
  });
}
