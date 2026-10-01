// test/widgets/player_volume_control_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
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

/// Puts primary focus on the slider by walking there with Tab, the way a
/// remote does: on a TV the mute button is excluded, so the slider is the one
/// stop after the focusable above it.
Future<void> focusSlider(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

void main() {
  // The flag is read when the control builds, so it is set before each test
  // pumps the widget. TV is the case these keys are for.
  setUp(() => TvModeService.isTv.value = true);
  tearDown(() => TvModeService.isTv.value = false);

  testWidgets('on a TV Up and Down move the level in steps, past 100%', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(app(_Host(initialVolume: 1.0, log: log)));
    await focusSlider(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // Above 100% is the point of the boost range; the readout shows it.
    expect(find.text('105%'), findsOneWidget);

    // A frame between presses, as a real remote has: the level is read back
    // from the widget, so a second press in the same frame sees the old one.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('the level stops at the ends of its range', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(app(_Host(initialVolume: 2.48, log: log)));
    await focusSlider(tester);

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
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

  testWidgets('on a TV Left and Right are not claimed, so the buttons beyond '
      'it can be reached', (tester) async {
    // They were: every arrow was the slider's, and a remote could not get
    // from the volume to speed, audio, the sleep timer or aspect (#80).
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(bubbled, contains(LogicalKeyboardKey.arrowRight));
    expect(bubbled, contains(LogicalKeyboardKey.arrowLeft));
  });

  testWidgets('off a TV Left and Right are the slider\'s', (tester) async {
    TvModeService.isTv.value = false;
    await tester.pumpWidget(app(const _Host(initialVolume: 1.0, log: [])));
    // Above, the mute button, then the slider.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('105%'), findsOneWidget);
  });

  testWidgets('on a TV the mute button is not a separate stop', (tester) async {
    await tester.pumpWidget(app(const _Host(initialVolume: 1.0, log: [])));

    final button = find.descendant(
      of: find.byType(PlayerVolumeControl),
      matching: find.byType(PlayerIconButton),
    );
    final excluding = find.ancestor(
      of: button,
      matching: find.byWidgetPredicate(
        (w) => w is ExcludeFocus && w.excluding,
      ),
    );
    expect(excluding, findsOneWidget);
  });

  testWidgets('off a TV the mute button keeps its own focus', (tester) async {
    TvModeService.isTv.value = false;
    await tester.pumpWidget(app(const _Host(initialVolume: 1.0, log: [])));

    final button = find.descendant(
      of: find.byType(PlayerVolumeControl),
      matching: find.byType(PlayerIconButton),
    );
    final excluding = find.ancestor(
      of: button,
      matching: find.byWidgetPredicate(
        (w) => w is ExcludeFocus && w.excluding,
      ),
    );
    expect(excluding, findsNothing);
  });
}
