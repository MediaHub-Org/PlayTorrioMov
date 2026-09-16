// test/widgets/player_settings_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

PlayerSettingsMenu menu({
  String? subtitleLabel,
  VoidCallback? onTapSubtitles,
}) => PlayerSettingsMenu(
  subtitleLabel: subtitleLabel,
  onTapSubtitles: onTapSubtitles,
);

void main() {
  group('PlayerSettingsMenu', () {
    // The gear used to be an index of every player control -- audio,
    // subtitles, speed, aspect -- which made it a menu of menus: three taps
    // to reach a speed that was one tap away on YouTube. Those four are
    // transport-bar buttons now, and what is left here is the two things
    // that have no button of their own: the subtitle entry and the sleep
    // timer.

    testWidgets('lists Subtitles when a handler is supplied', (tester) async {
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

    testWidgets('carries a sleep timer', (tester) async {
      // It lived at the bottom of the speed menu before, which was the one
      // place a viewer winding down for the night would not look for it.
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('SLEEP TIMER'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('the sleep timer presets are offered', (tester) async {
      await tester.pumpWidget(wrap(menu()));

      for (final min in ['15 min', '30 min', '45 min', '60 min']) {
        expect(find.text(min), findsOneWidget);
      }
    });

    testWidgets('carries no close button', (tester) async {
      // Tapping off the panel dismisses it; the X was a third way to do
      // what the barrier behind the menu already did.
      await tester.pumpWidget(wrap(menu()));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('carries no speed, audio or aspect rows', (tester) async {
      // They are transport-bar buttons now. A row here as well would be the
      // same control reachable two ways, and the menu-of-menus this panel
      // existed to be.
      await tester.pumpWidget(wrap(menu()));

      expect(find.text('Playback speed'), findsNothing);
      expect(find.text('Audio track'), findsNothing);
      expect(find.text('Aspect ratio'), findsNothing);
    });
  });
}
