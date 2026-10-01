// test/widgets/player_volume_control_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_volume_control.dart';

/// The control inside a stateful host, so a key press feeds back into
/// [PlayerVolumeControl.volume] the way the player's own state does.
class _Host extends StatefulWidget {
  final double initialVolume;
  final List<String> log;
  const _Host({required this.initialVolume, required this.log});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double volume = widget.initialVolume;
  bool muted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Focus(
          debugLabel: 'above',
          child: SizedBox(height: 40, width: 40),
        ),
        PlayerVolumeControl(
          volume: volume,
          isMuted: muted,
          onVolumeChanged: (v) => setState(() => volume = v),
          onToggleMute: () {
            widget.log.add('mute');
            setState(() => muted = !muted);
          },
        ),
      ],
    );
  }
}

Widget app(Widget body) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: body),
);

/// Tabs onto the slider: the focusable above, the mute button, the slider.
Future<void> focusSlider(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  }
  await tester.pump();
}

/// This is the pointer-and-keyboard control. A TV opens `PlayerVolumeMenu`
/// instead (see `player_volume_menu_test.dart`), because a slider that claims
/// Left/Right cannot be left with a remote.
void main() {
  testWidgets('Left and Right move the level in steps, past 100%', (
    tester,
  ) async {
    await tester.pumpWidget(app(const _Host(initialVolume: 1.0, log: [])));
    await focusSlider(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    // Above 100% is the point of the boost range; the readout shows it.
    expect(find.text('105%'), findsOneWidget);

    // A frame between presses: the level is read back from the widget.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('the level stops at the ends of its range', (tester) async {
    await tester.pumpWidget(app(const _Host(initialVolume: 2.48, log: [])));
    await focusSlider(tester);

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(find.text('250%'), findsOneWidget);
  });

  testWidgets('OK mutes and unmutes from the slider', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(app(_Host(initialVolume: 1.0, log: log)));
    await focusSlider(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(log, ['mute', 'mute']);
  });

  testWidgets('Up and Down are not claimed by the slider', (tester) async {
    final bubbled = <LogicalKeyboardKey>[];
    await tester.pumpWidget(
      app(
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) bubbled.add(event.logicalKey);
            return KeyEventResult.ignored;
          },
          child: const _Host(initialVolume: 1.0, log: []),
        ),
      ),
    );
    await focusSlider(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(bubbled, contains(LogicalKeyboardKey.arrowUp));
    expect(bubbled, contains(LogicalKeyboardKey.arrowDown));
  });

  testWidgets('the mute button is its own stop', (tester) async {
    await tester.pumpWidget(app(const _Host(initialVolume: 1.0, log: [])));
    final button = find.descendant(
      of: find.byType(PlayerVolumeControl),
      matching: find.byType(PlayerIconButton),
    );
    expect(
      find.ancestor(
        of: button,
        matching: find.byWidgetPredicate((w) => w is ExcludeFocus && w.excluding),
      ),
      findsNothing,
    );
  });
}
