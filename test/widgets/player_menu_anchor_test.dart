import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_panel.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

/// The anchor builds a Positioned, so it only makes sense inside a Stack --
/// which is exactly where player_screen.dart puts it.
Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Stack(children: [const Positioned.fill(child: ColoredBox(color: Colors.black)), child]),
  ),
);

void main() {
  // These hold the popover, the desktop presentation. A touch platform (what
  // flutter_test defaults to) gets a sheet on these sizes; those are in
  // player_panel_test.dart.
  setUp(() => PlayerPanelPolicy.touchOverride = false);
  tearDown(() => PlayerPanelPolicy.touchOverride = null);

  group('PlayerMenuAnchor', () {
    testWidgets('a menu taller than a short landscape phone scrolls', (
      tester,
    ) async {
      // The regression this exists for: a bottom-anchored menu with no top
      // bound sent whatever height it did not have upward, out of the
      // viewport, with nothing to clip or scroll it. The subtitle menu is
      // the fixture now -- the speed menu shrank when its sleep timer moved
      // to settings, and no longer overflows a 400px screen on its own.
      tester.view.physicalSize = const Size(880, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          PlayerMenuAnchor(
            child: PlayerSubtitleMenu(
              isSubtitleEnabled: false,
              onSelectVariant: (_) {},
              onSelectEmbedded: (_) {},
              onEnable: () {},
              onDisable: () {},
              onOpenSyncBar: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // The panel carries inner scroll views of its own, so the anchor's is
      // identified by its element: each candidate is measured through its
      // own render object, which needs no finder and cannot be ambiguous.
      final candidates = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .toList();
      expect(candidates, isNotEmpty);

      var sawFullHeightViewport = false;
      for (final element in find
          .byType(SingleChildScrollView)
          .evaluate()) {
        final renderObject = element.renderObject!;
        final box = renderObject as RenderBox;
        final topLeft = box.localToGlobal(Offset.zero);
        final bottomRight =
            box.localToGlobal(box.size.bottomRight(Offset.zero));
        final rect = Rect.fromPoints(topLeft, bottomRight);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(400));
        if (rect.height > 200) sawFullHeightViewport = true;
      }
      // And the fixture is genuinely tall enough that something had to be
      // bounded, so the test is not passing on a card that happened to fit.
      expect(sawFullHeightViewport, isTrue);
    });

    testWidgets('a shorter menu than the space does not scroll', (tester) async {
      // The speed menu lost its sleep timer to the settings menu, and at
      // seven presets it now fits a 400px landscape phone whole. The anchor
      // must not hand it a scroll view that eats drag gestures the rows
      // could have had.
      tester.view.physicalSize = const Size(880, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          PlayerMenuAnchor(
            child: PlayerSpeedMenu(
              currentRate: 1.0,
              onRateSelected: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      final card = tester.getRect(find.byType(PlayerSpeedMenu));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(400));
    });

    testWidgets('a tall menu on a short screen stays scrollable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(880, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          PlayerMenuAnchor(
            child: PlayerSpeedMenu(
              currentRate: 1.0,
              onRateSelected: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short menu sits against the bottom inset', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const PlayerMenuAnchor(
            child: SleepTimerMenu(),
          ),
        ),
      );

      final card = tester.getRect(find.byType(SleepTimerMenu));
      // Just above the playback line: the inset clears the whole transport
      // bar (its top padding, the seek row, the gap, the buttons and the
      // bottom padding) plus a quarter rem of air, not just the buttons row,
      // so the timeline stays visible and scrubbable while a menu is open.
      expect(card.bottom, lessThanOrEqualTo(720 - 162));
      expect(card.bottom, greaterThan(720 - 320));
    });

    testWidgets('the card clears both side edges on a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const PlayerMenuAnchor(
            child: SleepTimerMenu(),
          ),
        ),
      );

      final card = tester.getRect(find.byType(SleepTimerMenu));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('availableHeight never goes negative', (tester) async {
      // A clamp fed a negative upper bound throws, and callers clamp their
      // own preferred height against this.
      tester.view.physicalSize = const Size(880, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late double room;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              room = PlayerMenuAnchor.availableHeight(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(room, greaterThan(0));
    });
  });
}
