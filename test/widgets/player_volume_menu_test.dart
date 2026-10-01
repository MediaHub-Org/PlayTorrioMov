// test/widgets/player_volume_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_volume_menu.dart';

class _Host extends StatefulWidget {
  final List<String> log;
  final double initial;
  const _Host({required this.log, this.initial = 1.0});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double volume = widget.initial;
  bool muted = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            PlayerMenuAnchor(
              child: PlayerVolumeMenu(
                volume: volume,
                isMuted: muted,
                onVolumeChanged: (v) => setState(() {
                  volume = v;
                  muted = v == 0;
                }),
                onToggleMute: () {
                  widget.log.add('mute');
                  setState(() => muted = !muted);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> open(WidgetTester tester, {double initial = 1.0}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_Host(log: const [], initial: initial));
  // The panel builds, then takes focus after that frame.
  await tester.pump();
  await tester.pump();
}

void main() {
  tearDown(() => TvModeService.isTv.value = false);

  testWidgets('Left and Right change the level through the boost range, with '
      'focus on the slider as it opens', (tester) async {
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('105%'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('it reaches 250% and stops there', (tester) async {
    await open(tester, initial: 2.45);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(find.text('250%'), findsOneWidget);
  });

  testWidgets('OK mutes and unmutes from the slider', (tester) async {
    final log = <String>[];
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_Host(log: log));
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Mute'), findsWidgets, reason: 'the readout says so');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(log, ['mute', 'mute']);
  });

  testWidgets('a remote is told what the keys do; a pointer is not', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('OK'), findsNothing);

    TvModeService.isTv.value = true;
    await open(tester);
    expect(find.textContaining('OK'), findsOneWidget);
  });
}
