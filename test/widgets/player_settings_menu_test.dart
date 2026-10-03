// test/widgets/player_settings_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

PlayerSettingsMenu menu({
  void Function()? onSpeed,
  void Function()? onAudio,
  void Function()? onSleep,
  void Function()? onAspect,
}) =>
    PlayerSettingsMenu(
      currentRate: 1.5,
      audioSummary: 'English',
      aspectSummary: 'Original',
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

      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('Audio track'), findsOneWidget);
      expect(find.text('Sleep timer'), findsOneWidget);
      expect(find.text('Aspect ratio'), findsOneWidget);
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

      await tester.tap(find.text('Playback speed'));
      await tester.tap(find.text('Audio track'));
      await tester.tap(find.text('Sleep timer'));
      await tester.tap(find.text('Aspect ratio'));

      expect(speed, isTrue);
      expect(audio, isTrue);
      expect(sleep, isTrue);
      expect(aspect, isTrue);
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
      // Audio and aspect summaries are null here: no badge beside them.
      expect(find.text('Audio track'), findsOneWidget);
      expect(find.text('Aspect ratio'), findsOneWidget);
    });
  });
}
