// test/widgets/player_dpad_traversal_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:playtorriomov/widgets/player/player_center_controls.dart';
import 'package:playtorriomov/widgets/player/player_transport.dart';

/// The player's layout in miniature, wired the way `PlayerScreen` wires it:
/// the centered play/pause with its seek buttons, the transport bar pinned to
/// the bottom, and the named stops between them. A remote has only the
/// arrows, so what these tests hold is that it can reach every control and
/// that each arrow goes where a person expects (#80).
class _Nodes {
  final playPause = FocusNode(debugLabel: 'playPause');
  final seek = FocusNode(debugLabel: 'seek');
  final volume = FocusNode(debugLabel: 'volume');

  void dispose() {
    playPause.dispose();
    seek.dispose();
    volume.dispose();
  }
}

Widget _player(_Nodes n) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(
      children: [
        Center(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent ||
                  event.logicalKey != LogicalKeyboardKey.arrowDown) {
                return KeyEventResult.ignored;
              }
              n.seek.requestFocus();
              return KeyEventResult.handled;
            },
            child: PlayerCenterControls(
              isPlaying: true,
              onPlayPause: () {},
              onSeekBack30: () {},
              onSeekForward30: () {},
              playPauseFocusNode: n.playPause,
            ),
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
            onOpenStatsMenu: () {},
            seekFocusNode: n.seek,
            volumeFocusNode: n.volume,
            playPauseFocusNode: n.playPause,
          ),
        ),
      ],
    ),
  ),
);

Future<_Nodes> _pumpPlayer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final nodes = _Nodes();
  addTearDown(nodes.dispose);
  await tester.pumpWidget(_player(nodes));
  return nodes;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  setUp(() => TvModeService.isTv.value = true);
  tearDown(() => TvModeService.isTv.value = false);

  testWidgets('Down from play/pause goes to the seek bar, then into the row',
      (tester) async {
    final n = await _pumpPlayer(tester);
    n.playPause.requestFocus();
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(n.seek.hasPrimaryFocus, isTrue);

    // No volume stop on a TV: the remote owns its speaker, so the bar has
    // no volume control and Down keeps going to the buttons row.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(n.seek.hasPrimaryFocus, isFalse);
    expect(n.playPause.hasPrimaryFocus, isFalse);
  });

  testWidgets('Up from the seek bar is play/pause, with no stop between, '
      'however the bar was reached', (tester) async {
    final n = await _pumpPlayer(tester);
    // Straight onto the bar, as arriving from the bottom row does -- not by
    // Down from play/pause, where focus history would hide the problem.
    n.seek.requestFocus();
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(n.playPause.hasPrimaryFocus, isTrue);
  });

  /// Every button on the bottom row: Down from the seek bar lands in the
  /// row, then both directions are walked to the edges. The seek bar eats
  /// Left/Right itself (on a TV those seek), so the row cannot be entered
  /// sideways from it -- Down is the way in.
  Future<List<FocusNode>> _rowStops(WidgetTester tester, _Nodes n) async {
    n.seek.requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    final stops = <FocusNode>[FocusManager.instance.primaryFocus!];
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
      final here = FocusManager.instance.primaryFocus!;
      if (stops.contains(here)) break;
      stops.add(here);
    }
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      final here = FocusManager.instance.primaryFocus!;
      if (stops.contains(here)) break;
      stops.add(here);
    }
    return stops;
  }

  testWidgets('Up from any button on the bottom row is the seek bar', (
    tester,
  ) async {
    final n = await _pumpPlayer(tester);
    final stops = await _rowStops(tester, n);
    expect(
      stops.length,
      6,
      reason: 'stats, speed, audio, subtitles, sleep timer and aspect',
    );

    // From each one Up must reach the bar, not a seek button above its own
    // column.
    var buttons = 0;
    for (final stop in stops) {
      stop.requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.arrowUp);
      buttons++;
      expect(n.seek.hasPrimaryFocus, isTrue, reason: 'Up from button $buttons');
    }
  });

  testWidgets('Left and Right walk the row edge to edge and back', (
    tester,
  ) async {
    final n = await _pumpPlayer(tester);
    final stops = await _rowStops(tester, n);
    expect(
      stops.length,
      6,
      reason: 'stats, speed, audio, subtitles, sleep timer and aspect',
    );

    // Exact counts, never past an edge: pressing past one escapes the row
    // upward to the seek bar, which is right for a remote but not a walk.
    // Five hops cross six stops.
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    final rightmost = FocusManager.instance.primaryFocus!;
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowLeft);
    }
    expect(FocusManager.instance.primaryFocus, isNot(rightmost));
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(FocusManager.instance.primaryFocus, rightmost);
  });
}
