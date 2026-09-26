// test/widgets/player_menu_consistency_test.dart
//
// The player's popovers are one family, and two things about them had drifted
// apart: their widths (280, 320 and 330, so the panel jumped sideways as a
// viewer moved between them) and how they mark a selection (a leading radio
// in three menus, a trailing check in the aspect menu).
//
// Both are the kind of thing that regresses one menu at a time, so they are
// asserted across every menu rather than per menu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/widgets/player/player_aspect_menu.dart';
import 'package:playtorriomov/widgets/player/player_audio_menu.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Every popover, as a builder so each is pumped fresh.
final menus = <String, Widget Function()>{
  'audio': () => PlayerAudioMenu(
    audioTracks: const [
      PlayerAudioTrack(index: 1, title: 'English', language: 'eng'),
    ],
    selectedIndex: 1,
    onTrackSelected: (_) {},
  ),
  'subtitles': () => PlayerSubtitleMenu(
    isSubtitleEnabled: false,
    onSelectVariant: (_) {},
    onSelectEmbedded: (_) {},
    onEnable: () {},
    onDisable: () {},
    onOpenSyncBar: () {},
  ),
  'sleep': () => const SleepTimerMenu(),
  'speed': () => PlayerSpeedMenu(
    currentRate: 1.0,
    onRateSelected: (_) {},
    onClose: () {},
  ),
  'aspect': () => PlayerAspectMenu(
    currentFit: BoxFit.contain,
    onFitSelected: (_) {},
    onRatioSelected: (_) {},
    onClose: () {},
  ),
};

void main() {
  group('every player menu is the same width', () {
    for (final entry in menus.entries) {
      testWidgets('${entry.key} uses the shared width', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(wrap(entry.value()));
        await tester.pump();

        final card = tester.getSize(find.byType(PlayerGlassCard));
        expect(
          card.width,
          PlayerTheme.menuWidth,
          reason:
              '${entry.key} is a different width from the rest, so the panel '
              'moves when a viewer switches menus',
        );
      });
    }

    testWidgets('they all shrink together on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final widths = <String, double>{};
      for (final entry in menus.entries) {
        await tester.pumpWidget(wrap(entry.value()));
        await tester.pump();
        widths[entry.key] = tester.getSize(find.byType(PlayerGlassCard)).width;
      }

      // One width, not five: the clamp is shared, so a narrow screen cannot
      // leave one menu wider than another.
      expect(widths.values.toSet().length, 1, reason: 'widths: $widths');
      expect(widths.values.first, lessThanOrEqualTo(360 - 32));
    });
  });

  group('selection is marked the same way everywhere', () {
    testWidgets('the aspect menu uses a radio, not a trailing check', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(menus['aspect']!()));
      await tester.pump();

      // It drew a trailing check while the other menus drew a leading radio,
      // so the same gesture was drawn two ways.
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('the audio menu uses a radio', (tester) async {
      await tester.pumpWidget(wrap(menus['audio']!()));
      await tester.pump();

      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('the sleep menu uses a radio', (tester) async {
      await tester.pumpWidget(wrap(menus['sleep']!()));
      await tester.pump();

      // Nothing armed, so every row is unselected -- but the marks are
      // radios, which is the shape being asserted.
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('the subtitle menu uses a radio', (tester) async {
      await tester.pumpWidget(
        wrap(
          PlayerSubtitleMenu(
            groups: [
              SubtitleLanguageGroup(
                language: 'Arabic',
                variants: [
                  SubtitleVariant(
                    providerName: 'test',
                    language: 'Arabic',
                    title: '',
                    downloadUrl: 'a',
                    format: 'srt',
                  ),
                ],
              ),
            ],
            isSubtitleEnabled: false,
            onSelectVariant: (_) {},
            onSelectEmbedded: (_) {},
            onEnable: () {},
            onDisable: () {},
            onOpenSyncBar: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}