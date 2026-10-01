// test/widgets/player_dpad_traversal_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/widgets/player/player_center_controls.dart';
import 'package:playtorriomov/widgets/player/player_seek_bar.dart';
import 'package:playtorriomov/widgets/player/player_transport.dart';
import 'package:playtorriomov/widgets/player/player_volume_control.dart';

/// The player's layout in miniature: the centered play/pause with its seek
/// buttons, the transport bar pinned to the bottom. A remote has only the
/// arrows, so what these tests hold is that they can reach every layer and
/// come back (#80).
Widget player(FocusNode playPause) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(
      children: [
        Center(
          child: PlayerCenterControls(
            isPlaying: true,
            onPlayPause: () {},
            onSeekBack30: () {},
            onSeekForward30: () {},
            playPauseFocusNode: playPause,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PlayerTransport(
            position: const Duration(minutes: 5),
            duration: const Duration(minutes: 50),
            volume: 1.0,
            isMuted: false,
            playbackRate: 1.0,
            isSubtitlesActive: false,
            onSeek: (_) {},
            onVolumeChanged: (_) {},
            onToggleMute: () {},
            onOpenSubtitleMenu: () {},
            onOpenSpeedMenu: () {},
            onOpenAudioMenu: () {},
            onOpenAspectMenu: () {},
            onOpenSleepTimerMenu: () {},
          ),
        ),
      ],
    ),
  ),
);

bool inside(Type type) {
  final primary = FocusManager.instance.primaryFocus;
  final context = primary?.context;
  if (context == null) return false;
  var found = false;
  context.visitAncestorElements((e) {
    if (e.widget.runtimeType == type) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  setUp(() => TvModeService.isTv.value = true);
  tearDown(() => TvModeService.isTv.value = false);

  testWidgets('Down from play/pause reaches the seek bar, then the bottom row, '
      'and Up comes back the same way', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final playPause = FocusNode(debugLabel: 'playPause');
    addTearDown(playPause.dispose);
    await tester.pumpWidget(player(playPause));
    playPause.requestFocus();
    await tester.pump();
    expect(playPause.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(inside(PlayerSeekBar), isTrue, reason: 'first stop below is the seek bar');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(inside(PlayerSeekBar), isFalse);
    expect(playPause.hasPrimaryFocus, isFalse);
    expect(
      inside(PlayerTransport),
      isTrue,
      reason: 'the next stop is on the bottom row',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(inside(PlayerSeekBar), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(playPause.hasPrimaryFocus, isTrue, reason: 'and back to play/pause');
  });

  testWidgets('the volume is a stop on the bottom row, and Right leaves it '
      'for the next control only after it', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final playPause = FocusNode(debugLabel: 'playPause');
    addTearDown(playPause.dispose);
    await tester.pumpWidget(player(playPause));
    playPause.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // Wherever the bottom row was entered, walking Left reaches the volume:
    // it is the leftmost control, and nothing before it traps the arrows.
    for (var i = 0; i < 8 && !inside(PlayerVolumeControl); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    expect(inside(PlayerVolumeControl), isTrue);

    // And from the volume, Up leaves it (it does not own the vertical keys).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(inside(PlayerVolumeControl), isFalse);
  });
}
