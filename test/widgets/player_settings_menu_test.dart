// test/widgets/player_settings_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

PlayerSettingsMenu menu({
  String? audioLabel,
  VoidCallback? onTapAudio,
  VoidCallback? onTapSpeed,
  String? subtitleLabel,
  VoidCallback? onTapSubtitles,
}) {
  return PlayerSettingsMenu(
    currentRate: 1.0,
    aspectLabel: 'Fit',
    audioLabel: audioLabel,
    onTapAudio: onTapAudio,
    onTapSpeed: onTapSpeed ?? () {},
    onTapAspect: () {},
    subtitleLabel: subtitleLabel,
    onTapSubtitles: onTapSubtitles,
    onClose: () {},
  );
}

void main() {
  group('PlayerSettingsMenu', () {
    testWidgets('lists audio track alongside speed and aspect', (tester) async {
      // Audio used to be its own button in the transport bar, next to the
      // gear that had already absorbed speed and aspect.
      await tester.pumpWidget(
        wrap(menu(audioLabel: 'English', onTapAudio: () {})),
      );

      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('Aspect ratio'), findsOneWidget);
      expect(find.text('Audio track'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('opens the audio menu when the row is tapped', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        wrap(menu(audioLabel: 'English', onTapAudio: () => opened++)),
      );

      await tester.tap(find.text('Audio track'));
      expect(opened, 1);
    });

    testWidgets('hides the audio row when there is nothing to choose', (
      tester,
    ) async {
      // A single-track file: a row that opens an empty menu is worse than
      // no row.
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('Audio track'), findsNothing);
      expect(find.text('Playback speed'), findsOneWidget);
    });

    testWidgets('falls back to Default before tracks are known', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(menu(onTapAudio: () {})));

      expect(find.text('Audio track'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('lists Subtitles when a handler is supplied', (tester) async {
      // Track/style picking moved here from the transport bar's own
      // subtitle button, which is now a plain on/off toggle.
      await tester.pumpWidget(
        wrap(menu(subtitleLabel: 'English', onTapSubtitles: () {})),
      );

      expect(find.text('Subtitles'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('opens the subtitle menu when the row is tapped', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        wrap(menu(subtitleLabel: 'English', onTapSubtitles: () => opened++)),
      );

      await tester.tap(find.text('Subtitles'));
      expect(opened, 1);
    });

    testWidgets('hides the Subtitles row without a handler', (tester) async {
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('Subtitles'), findsNothing);
    });

    testWidgets('falls back to Off before a subtitle is selected', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(menu(onTapSubtitles: () {})));

      expect(find.text('Subtitles'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
    });
  });
}
