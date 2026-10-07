// The subtitle panel's controls. Opened straight from the transport bar the
// panel has no back button, so the first control in reading order is
// Refresh, and the panel's take-focus-on-open put a violet ring on it: it
// read as switched on, and on a remote one press of OK started a network
// search nobody asked for. Focus now lands on the on/off button, shows only
// while the viewer is navigating with keys, and every pill lights on hover
// and on a press.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

Widget menu({
  VoidCallback? onBack,
  List<PlayerEmbeddedSubtitle> embedded = const [
    PlayerEmbeddedSubtitle(index: 1, title: 'English', language: 'English'),
  ],
  VoidCallback? onRefresh,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: PlayerFocusOnOpen(
        child: PlayerSubtitleMenu(
          embeddedSubtitles: embedded,
          isSubtitleEnabled: false,
          onBack: onBack,
          onSelectVariant: (_) {},
          onSelectEmbedded: (_) {},
          onEnable: () {},
          onDisable: () {},
          onOpenSyncBar: () {},
          onRefresh: onRefresh ?? () {},
        ),
      ),
    ),
  ),
);

/// Whether the control holding [label] is the one with focus.
bool hasFocus(WidgetTester tester, String label) {
  final element = tester.element(find.text(label).first);
  return Focus.of(element).hasPrimaryFocus;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The fill the pill around [label] is drawn with.
Color? pillFill(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(of: find.text(label).first, matching: find.byType(AnimatedContainer)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  group('focus on open', () {
    testWidgets('lands on the on/off button when there is no back button', (
      tester,
    ) async {
      await tester.pumpWidget(menu());
      await settle(tester);

      expect(hasFocus(tester, 'Turn subtitles on'), isTrue);
    });

    testWidgets('lands on the on/off button when there is a back button', (
      tester,
    ) async {
      await tester.pumpWidget(menu(onBack: () {}));
      await settle(tester);

      expect(hasFocus(tester, 'Turn subtitles on'), isTrue);
    });

    testWidgets('OK on the focused button presses it, not Refresh', (
      tester,
    ) async {
      var refreshed = false;
      await tester.pumpWidget(menu(onRefresh: () => refreshed = true));
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(refreshed, isFalse);
    });
  });

  group('the focus cue', () {
    testWidgets('is not drawn for a touch or mouse viewer', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(menu());
      await settle(tester);

      final touch = pillFill(tester, 'Turn subtitles on');

      // The same panel under a remote: the wash is drawn.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(menu());
      await settle(tester);

      expect(pillFill(tester, 'Turn subtitles on'), isNot(touch));
    });
  });

  group('every pill answers a press', () {
    for (final label in ['Embedded  1', 'Online', 'Subtitles', 'Turn subtitles on']) {
      testWidgets('"$label" lights while it is pressed', (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await tester.pumpWidget(menu());
        await settle(tester);

        final at = find.text(label).first;
        final before = pillFill(tester, label);
        final gesture = await tester.startGesture(tester.getCenter(at));
        await tester.pump(const Duration(milliseconds: 200));
        final during = pillFill(tester, label);
        // Cancelled rather than released: a release is a tap, and a tap on a
        // tab selects it, which changes the fill for its own reasons.
        await gesture.cancel();
        await tester.pump(const Duration(milliseconds: 200));

        expect(during, isNot(before));
        expect(pillFill(tester, label), before);
      });
    }

    testWidgets('an icon button lights while it is pressed', (tester) async {
      await tester.pumpWidget(menu());
      await settle(tester);
      // Switch to the Online tab so Refresh exists.
      await tester.tap(find.text('Online'));
      await settle(tester);

      Color? bg() {
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byTooltip('Refresh Online Subtitles'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration as BoxDecoration).color;
      }

      final before = bg();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Refresh Online Subtitles')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final during = bg();
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));

      expect(during, isNot(before));
      expect(bg(), before);
    });
  });

  group('Refresh', () {
    testWidgets('is only there on the Online list', (tester) async {
      await tester.pumpWidget(menu());
      await settle(tester);

      // Opens on Embedded, which a search does not refresh.
      expect(find.byTooltip('Refresh Online Subtitles'), findsNothing);

      await tester.tap(find.text('Online'));
      await settle(tester);
      expect(find.byTooltip('Refresh Online Subtitles'), findsOneWidget);

      await tester.tap(find.text('Embedded  1'));
      await settle(tester);
      expect(find.byTooltip('Refresh Online Subtitles'), findsNothing);
    });

    testWidgets('is there from the start when the file has no embedded tracks', (
      tester,
    ) async {
      await tester.pumpWidget(menu(embedded: const []));
      await settle(tester);

      expect(find.byTooltip('Refresh Online Subtitles'), findsOneWidget);
    });
  });
}
