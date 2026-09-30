// test/widgets/remote_key_decision_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/remote_key_decision.dart';

RemoteKeyDecision decide(
  LogicalKeyboardKey key, {
  bool isTv = true,
  bool controlsVisible = false,
  bool hasOverlayOpen = false,
  bool screenHoldsFocus = true,
}) => decideRemoteKey(
  key: key,
  isTv: isTv,
  controlsVisible: controlsVisible,
  hasOverlayOpen: hasOverlayOpen,
  screenHoldsFocus: screenHoldsFocus,
);

void main() {
  group('on a TV with the controls hidden', () {
    test('Left and Right seek and bring the bars back', () {
      final left = decide(LogicalKeyboardKey.arrowLeft);
      final right = decide(LogicalKeyboardKey.arrowRight);

      expect(left.action, RemoteKeyAction.seekBack);
      expect(right.action, RemoteKeyAction.seekForward);
      expect(left.revealControls, isTrue);
      expect(right.revealControls, isTrue);
    });

    test('Up and Down only show the bars, and the key is consumed', () {
      for (final key in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown]) {
        final d = decide(key);
        expect(d.revealControls, isTrue, reason: '$key');
        expect(d.action, RemoteKeyAction.revealOnly, reason: '$key');
        expect(d.isHandled, isTrue, reason: '$key');
      }
    });

    test('OK shows the bars and still falls through to play/pause', () {
      // Consuming it here would leave OK unable to pause, which is the
      // original "D-pad only pauses and plays" report turned inside out.
      for (final key in [LogicalKeyboardKey.select, LogicalKeyboardKey.gameButtonA]) {
        final d = decide(key);
        expect(d.revealControls, isTrue, reason: '$key');
        expect(d.isHandled, isFalse, reason: '$key');
      }
    });
  });

  group('on a TV with the controls showing', () {
    test('the first arrow hands focus to play/pause', () {
      final d = decide(LogicalKeyboardKey.arrowDown, controlsVisible: true);

      expect(d.action, RemoteKeyAction.focusPlayPause);
      expect(d.revealControls, isTrue, reason: 'keeps the hide timer fresh');
    });

    test('once focus is on a control, arrows are left to traversal', () {
      final d = decide(
        LogicalKeyboardKey.arrowRight,
        controlsVisible: true,
        screenHoldsFocus: false,
      );

      expect(d.action, RemoteKeyAction.none);
      expect(d.isHandled, isFalse);
      expect(d.revealControls, isTrue);
    });
  });

  group('off a TV', () {
    test('arrows keep their desktop meaning and never seek from here', () {
      for (final visible in [true, false]) {
        final d = decide(
          LogicalKeyboardKey.arrowLeft,
          isTv: false,
          controlsVisible: visible,
        );
        expect(d.action, RemoteKeyAction.none, reason: 'visible=$visible');
        expect(d.isHandled, isFalse, reason: 'visible=$visible');
      }
    });
  });

  group('while a menu or panel is open', () {
    test('every arrow and OK is left alone', () {
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.select,
      ]) {
        final d = decide(key, hasOverlayOpen: true);
        expect(d.revealControls, isFalse, reason: '$key');
        expect(d.action, RemoteKeyAction.none, reason: '$key');
      }
    });
  });

  test('other keys never reveal the controls', () {
    for (final key in [
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.audioVolumeUp,
    ]) {
      final d = decide(key);
      expect(d.revealControls, isFalse, reason: '$key');
      expect(d.action, RemoteKeyAction.none, reason: '$key');
    }
  });
}
