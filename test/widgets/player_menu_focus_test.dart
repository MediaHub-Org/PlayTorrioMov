// test/widgets/player_menu_focus_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';
import 'package:playtorriomov/widgets/player/player_volume_menu.dart';

class _Host extends StatefulWidget {
  final FocusNode opener;
  final List<String> picked;

  /// The menu's contents; the default is three plain rows.
  final Widget? menu;
  const _Host({required this.opener, required this.picked, this.menu});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            // Something focusable nearer the opener than the menu rows, as the
            // seek bar is in the player.
            const Align(
              alignment: Alignment.bottomCenter,
              child: Focus(child: SizedBox(width: 400, height: 30)),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Focus(
                focusNode: widget.opener,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.select) {
                    setState(() => open = !open);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
            if (open)
              PlayerMenuAnchor(
                child: widget.menu ?? Column(
                  children: [
                    for (final label in ['0.5x', '1x', '2x'])
                      PlayerMenuRow(
                        leading: const SizedBox(width: 8),
                        title: label,
                        isSelected: label == '1x',
                        onTap: () => widget.picked.add(label),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('opening a menu puts focus on its rows and keeps the arrows '
      'there', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final opener = FocusNode(debugLabel: 'opener');
    addTearDown(opener.dispose);
    final picked = <String>[];

    await tester.pumpWidget(_Host(opener: opener, picked: picked));
    opener.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    // Twice: the menu builds, then asks for focus after that frame.
    await tester.pump();
    await tester.pump();

    // Focus is on a menu row now, not still on the opener.
    bool inMenu() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      var found = false;
      context.visitAncestorElements((e) {
        if (e.widget is PlayerMenuRow) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    }

    expect(inMenu(), isTrue, reason: 'the menu takes focus when it opens');

    // Up and Down walk the rows and never leave them, whatever else is near.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(inMenu(), isTrue, reason: 'Up #$i stayed on the menu');
    }
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(inMenu(), isTrue, reason: 'Down #$i stayed on the menu');
    }

    // OK picks the focused row.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(picked, hasLength(1));
  });

  testWidgets('a menu whose main control is a slider opens with focus on it, '
      'so Left/Right work at once', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final opener = FocusNode(debugLabel: 'opener');
    addTearDown(opener.dispose);
    final rates = <double>[];

    await tester.pumpWidget(
      _Host(
        opener: opener,
        picked: const [],
        menu: PlayerVolumeMenu(
          volume: 1.0,
          isMuted: false,
          onVolumeChanged: rates.add,
          onToggleMute: () {},
        ),
      ),
    );
    opener.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // The slider, not the mute button to its left, took the first press.
    expect(rates, isNotEmpty, reason: 'Right adjusted the level');
    expect(rates.last, greaterThan(1.0));
  });
}
