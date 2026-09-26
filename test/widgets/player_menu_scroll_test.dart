// test/widgets/player_menu_scroll_test.dart
//
// Two bugs that only showed up on screen, both about a panel that is taller
// than the room it is given.
//
// The subtitle panel sets its own height, and the anchor bounds it. When the
// card asked for more than the anchor could give, the anchor's scroll view
// and the panel's own list became two nested scrollables -- the wheel went to
// the inner one, and the bottom of the panel, where "More options" expands
// to, could not be reached at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        PlayerMenuAnchor(child: child),
      ],
    ),
  ),
);

Widget menu() => PlayerSubtitleMenu(
  isSubtitleEnabled: false,
  onSelectVariant: (_) {},
  onSelectEmbedded: (_) {},
  onEnable: () {},
  onDisable: () {},
  onOpenSyncBar: () {},
);

void main() {
  group('the panel never asks for more height than it is given', () {
    for (final size in const {
      'a short landscape phone': Size(880, 400),
      'a small window': Size(900, 600),
      'a phone portrait': Size(390, 844),
      'a desktop window': Size(1280, 720),
    }.entries) {
      testWidgets('on ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(wrap(menu()));
        await tester.pump();

        expect(tester.takeException(), isNull);

        final card = tester.getSize(find.byType(PlayerGlassCard));
        final room = PlayerMenuAnchor.availableHeight(
          tester.element(find.byType(PlayerGlassCard)),
        );
        expect(
          card.height,
          lessThanOrEqualTo(room + 0.5),
          reason:
              'a card taller than the anchor overflows its scroll view, and '
              'the bottom of the panel becomes unreachable',
        );
      });
    }
  });

  group('the appearance editor is reachable', () {
    testWidgets('opening it does not overflow a short screen', (tester) async {
      tester.view.physicalSize = const Size(880, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(menu()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // The editor's own rows use Expanded, so it needs a bounded height --
      // which is what the card's fixed height provides. "More options" is
      // below the fold on a 400px screen, so reaching it is the assertion:
      // it is the bottom of the panel, and the bottom is what was
      // unreachable when the card outgrew the anchor.
      final page = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('More options'),
        200,
        scrollable: page,
      );
      expect(find.text('More options'), findsOneWidget);
    });
  });
}