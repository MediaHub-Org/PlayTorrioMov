import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_settings_menu.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';

/// The anchor builds a Positioned, so it only makes sense inside a Stack --
/// which is exactly where player_screen.dart puts it.
Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Stack(children: [const Positioned.fill(child: ColoredBox(color: Colors.black)), child]),
  ),
);

void main() {
  group('PlayerMenuAnchor', () {
    testWidgets('a tall menu fits a short landscape phone', (tester) async {
      // The regression this exists for: the speed menu is seven presets, a
      // divider and a sleep-timer row -- around 440px of card. Bottom-
      // anchored with no top bound, height it did not have went upward, out
      // of the viewport, with nothing to clip or scroll it.
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

      // What has to fit is the scroll viewport, not the card. The card is
      // allowed -- expected -- to be taller than the screen here; the whole
      // point is that the overflow became something to scroll instead of
      // something painted past the edge. Asserting the card's own layout
      // rect measures the scrolled content, which is not what the viewer
      // sees.
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(viewport.top, greaterThanOrEqualTo(0));
      expect(viewport.bottom, lessThanOrEqualTo(400));

      final card = tester.getRect(find.byType(PlayerSpeedMenu));
      // The header is on screen. Under the old hand-placed Positioned this
      // was negative: the top of the card sat above the top of the window.
      expect(card.top, greaterThanOrEqualTo(0));
      // And the fixture is genuinely taller than the space, so the scroll
      // view is doing real work rather than the test passing by accident on
      // a card that happened to fit.
      expect(card.height, greaterThan(viewport.height));
    });

    testWidgets('what overflows can be scrolled to', (tester) async {
      // The sleep timer is the last thing in the speed menu, so it is what
      // the old layout put furthest out of reach.
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

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final chip = tester.getRect(find.text('60 min'));
      expect(chip.top, greaterThanOrEqualTo(0));
      expect(chip.bottom, lessThanOrEqualTo(400));
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
          PlayerMenuAnchor(
            child: PlayerSettingsMenu(
              currentRate: 1.0,
              aspectLabel: 'Fit',
              onTapSpeed: () {},
              onTapAspect: () {},
            ),
          ),
        ),
      );

      final card = tester.getRect(find.byType(PlayerSettingsMenu));
      // Clear of the transport bar, but not floating in the middle of the
      // frame either.
      expect(card.bottom, lessThanOrEqualTo(720 - 96));
      expect(card.bottom, greaterThan(720 - 200));
    });

    testWidgets('the card clears both side edges on a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          PlayerMenuAnchor(
            child: PlayerSettingsMenu(
              currentRate: 1.0,
              aspectLabel: 'Fit',
              onTapSpeed: () {},
              onTapAspect: () {},
            ),
          ),
        ),
      );

      final card = tester.getRect(find.byType(PlayerSettingsMenu));
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
