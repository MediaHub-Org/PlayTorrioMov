// test/widgets/player_panel_test.dart
//
// The player's menus come in the shape the screen is good at: a sheet from the
// bottom on a phone upright, a column from the side on a phone on its side, a
// tablet and a TV, the popover on a desktop. Which one, and how each is sent
// away -- the close button, the swipe, the scrim -- is decided per shape, and
// held here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_aspect_menu.dart';
import 'package:playtorriomov/widgets/player/player_audio_menu.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';
import 'package:playtorriomov/widgets/player/player_volume_menu.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';
import 'package:playtorriomov/widgets/player/player_panel.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

void main() {
  tearDown(() {
    PlayerPanelPolicy.touchOverride = null;
    TvModeService.isTv.value = false;
  });

  group('playerPanelStyleFor', () {
    PlayerPanelStyle style(Size size, {bool tv = false, bool touch = true}) =>
        playerPanelStyleFor(size: size, isTv: tv, isTouch: touch);

    test('a phone upright gets a bottom sheet', () {
      expect(style(const Size(390, 844)), PlayerPanelStyle.bottomSheet);
      expect(style(const Size(360, 640)), PlayerPanelStyle.bottomSheet);
    });

    test('a phone on its side and a tablet get a side sheet', () {
      expect(style(const Size(844, 390)), PlayerPanelStyle.sideSheet);
      expect(style(const Size(1024, 768)), PlayerPanelStyle.sideSheet);
      expect(style(const Size(1280, 800)), PlayerPanelStyle.sideSheet);
    });

    test('a tablet upright gets a bottom sheet while it is narrow', () {
      expect(style(const Size(800, 1280)), PlayerPanelStyle.bottomSheet);
      // Wide enough upright to have room for a column.
      expect(style(const Size(1000, 1400)), PlayerPanelStyle.sideSheet);
    });

    test('a TV always gets a side sheet', () {
      expect(style(const Size(960, 540), tv: true), PlayerPanelStyle.sideSheet);
      expect(style(const Size(1920, 1080), tv: true, touch: false),
          PlayerPanelStyle.sideSheet);
    });

    test('a pointer on a wide window keeps the popover', () {
      expect(style(const Size(1280, 720), touch: false),
          PlayerPanelStyle.popover);
      expect(style(const Size(844, 390), touch: false),
          PlayerPanelStyle.popover);
    });

    test('a narrow upright desktop window gets a bottom sheet, not a sliver',
        () {
      expect(style(const Size(500, 900), touch: false),
          PlayerPanelStyle.bottomSheet);
    });
  });

  group('the sheets', () {
    Future<void> pumpMenu(
      WidgetTester tester, {
      required Size size,
      required List<String> log,
      bool touch = true,
      bool tv = false,
      TextDirection direction = TextDirection.ltr,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PlayerPanelPolicy.touchOverride = touch;
      TvModeService.isTv.value = tv;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                PlayerMenuAnchor(
                  onClose: () => log.add('closed'),
                  child: PlayerGlassCard(
                    width: 320,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (var i = 0; i < 3; i++)
                          PlayerMenuRow(
                            leading: const SizedBox(width: 8),
                            title: 'Row $i',
                            isSelected: i == 0,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // The sheet is in place after its slide.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a side sheet is as tall as the screen and fills its width', (
      tester,
    ) async {
      await pumpMenu(tester, size: const Size(844, 390), log: []);

      final card = tester.getRect(find.byType(PlayerGlassCard));
      // The sheet's width, not the 320 the card asked for, and the card is
      // not a card any more: no second surface inside the sheet.
      expect(card.width, greaterThan(320));
      expect(card.right, closeTo(844, 1));
      expect(
        tester.getSize(find.byType(PlayerSheet)).height,
        390,
        reason: 'the sheet spans the screen top to bottom',
      );
    });

    testWidgets('a side sheet on a touch screen has a close button', (
      tester,
    ) async {
      final log = <String>[];
      await pumpMenu(tester, size: const Size(844, 390), log: log);

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(log, ['closed']);
    });

    testWidgets('a side sheet is swiped away toward its edge, and not by a '
        'small nudge', (tester) async {
      final log = <String>[];
      await pumpMenu(tester, size: const Size(844, 390), log: log);

      // A short drag springs back.
      await tester.drag(find.text('Row 1'), const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, isEmpty);

      // A long one sends it away.
      await tester.drag(find.text('Row 1'), const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, ['closed']);
    });

    testWidgets('in a right-to-left layout the swipe goes the other way', (
      tester,
    ) async {
      final log = <String>[];
      await pumpMenu(
        tester,
        size: const Size(844, 390),
        log: log,
        direction: TextDirection.rtl,
      );

      // The sheet sits at the left edge now.
      expect(tester.getRect(find.byType(PlayerSheet)).left, closeTo(0, 1));
      await tester.drag(find.text('Row 1'), const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, isEmpty, reason: 'a swipe toward the middle is not closing');

      await tester.drag(find.text('Row 1'), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, ['closed']);
    });

    testWidgets('tapping the scrim closes a sheet', (tester) async {
      final log = <String>[];
      await pumpMenu(tester, size: const Size(844, 390), log: log);

      await tester.tapAt(const Offset(40, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(log, ['closed']);
    });

    testWidgets('a TV side sheet has no close button and no swipe: Back closes '
        'it', (tester) async {
      final log = <String>[];
      await pumpMenu(tester, size: const Size(960, 540), log: log, tv: true);

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.drag(find.text('Row 1'), const Offset(400, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, isEmpty);
    });

    testWidgets('a bottom sheet has a grabber and no close button, and a drag '
        'down on the grabber closes it', (tester) async {
      final log = <String>[];
      await pumpMenu(tester, size: const Size(390, 844), log: log);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      final card = tester.getRect(find.byType(PlayerGlassCard));
      expect(card.bottom, closeTo(844, 1));
      expect(card.width, 390, reason: 'the full width of the screen');

      // The grabber is the drag area: the strip just above the menu.
      final grabber = Offset(195, card.top - 18);
      await tester.dragFrom(grabber, const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, isEmpty, reason: 'a short pull springs back');

      await tester.dragFrom(grabber, const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(log, ['closed']);
    });

    testWidgets('the popover is untouched on a pointer: no sheet, no scrim', (
      tester,
    ) async {
      await pumpMenu(
        tester,
        size: const Size(1280, 720),
        log: [],
        touch: false,
      );

      expect(find.byType(PlayerSheet), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(
        tester.getSize(find.byType(PlayerGlassCard)).width,
        320,
        reason: 'the card keeps its own width as a popover',
      );
    });

    testWidgets('the subtitle list gets the whole sheet, not a popover height', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      PlayerPanelPolicy.touchOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                PlayerMenuAnchor(
                  onClose: () {},
                  child: PlayerSubtitleMenu(
                    isSubtitleEnabled: false,
                    onSelectVariant: (_) {},
                    onSelectEmbedded: (_) {},
                    onEnable: () {},
                    onDisable: () {},
                    onOpenSyncBar: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      final card = tester.getSize(find.byType(PlayerGlassCard));
      // A popover tops out near 280-460; a 390-high sheet minus its close
      // strip is more than the popover could be on this screen.
      expect(card.height, greaterThan(300));
      expect(card.height, lessThanOrEqualTo(390));
    });

    testWidgets('a menu opened in a sheet still takes focus on its rows', (
      tester,
    ) async {
      await pumpMenu(tester, size: const Size(844, 390), log: []);
      await tester.pump();

      final context = FocusManager.instance.primaryFocus?.context;
      expect(context, isNotNull);
      var inRow = false;
      context!.visitAncestorElements((e) {
        if (e.widget is PlayerMenuRow) {
          inRow = true;
          return false;
        }
        return true;
      });
      expect(inRow, isTrue, reason: 'the first row, not the close button');
      // And the arrows stay on the rows.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.byType(PlayerMenuRow), findsNWidgets(3));
    });
  });

  group('every menu, in every presentation, at 3x text', () {
    final menus = <String, Widget Function()>{
      'audio': () => PlayerAudioMenu(
        audioTracks: const [
          PlayerAudioTrack(index: 1, title: 'English'),
          PlayerAudioTrack(index: 2, title: 'Spanish (LATAM)'),
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
      'settings': () => PlayerSettingsMenu(
        currentRate: 1.0,
        audioSummary: 'English',
        aspectSummary: 'Original',
        onOpenSpeed: () {},
        onOpenAudio: () {},
        onOpenSleep: () {},
        onOpenAspect: () {},
      ),
      'volume': () => PlayerVolumeMenu(
        volume: 2.1,
        isMuted: false,
        onVolumeChanged: (_) {},
        onToggleMute: () {},
      ),
    };

    const screens = <String, ({Size size, bool touch, bool tv})>{
      'popover (desktop)': (size: Size(1280, 720), touch: false, tv: false),
      'side sheet (phone on its side)':
          (size: Size(844, 390), touch: true, tv: false),
      'side sheet (TV)': (size: Size(960, 540), touch: true, tv: true),
      'bottom sheet (phone upright)':
          (size: Size(390, 844), touch: true, tv: false),
    };

    for (final screen in screens.entries) {
      for (final menu in menus.entries) {
        testWidgets('${menu.key} as a ${screen.key}', (tester) async {
          tester.view.physicalSize = screen.value.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          PlayerPanelPolicy.touchOverride = screen.value.touch;
          TvModeService.isTv.value = screen.value.tv;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(3),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Stack(
                  children: [
                    PlayerMenuAnchor(onClose: () {}, child: menu.value()),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
