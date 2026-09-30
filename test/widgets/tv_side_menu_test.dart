// test/widgets/tv_side_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/utils/hub_controller.dart';
import 'package:playtorriomov/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorriomov/widgets/common/top_bar.dart';
import 'package:playtorriomov/widgets/common/tv_side_menu.dart';

void setSurface(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    HubController.instance.setMediaSection('movies');
  });

  testWidgets('the menu lists the sections, Search and Settings',
      (tester) async {
    setSurface(tester, 1280);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TvHubFrame(
          menu: TvSideMenu(onSearchTap: () {}, onSettingsTap: () {}),
          child: const SizedBox.expand(),
        ),
      ),
    ));
    await tester.pump();

    for (final label in [
      'Films',
      'Series',
      'Anime',
      'Live TV',
      'Profile',
      'Search',
      'Settings',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets(
    'Left from content reaches the menu, Up/Down move through it, OK switches '
    'section, Right returns to the content',
    (tester) async {
      setSurface(tester, 1280);
      final card = FocusNode(debugLabel: 'card');
      addTearDown(card.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TvHubFrame(
            menu: TvSideMenu(onSearchTap: () {}, onSettingsTap: () {}),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Focus(
                focusNode: card,
                child: const SizedBox(width: 120, height: 180),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      card.requestFocus();
      await tester.pump();
      expect(card.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(card.hasPrimaryFocus, isFalse);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      // Wherever Left landed, Up to the top item (Films), then Down to Series.
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(HubController.instance.mediaSection, 'series');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(card.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('a TV layout draws no top bar and no bottom tab bar',
      (tester) async {
    setSurface(tester, 400);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdaptiveNavShell(tvLayout: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pump();

    expect(find.byType(TopBar), findsNothing);
    expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
  });
}
