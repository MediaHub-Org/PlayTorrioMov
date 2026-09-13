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
      // divider and a sleep-timer row -- around 430px of card. Bottom-
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
