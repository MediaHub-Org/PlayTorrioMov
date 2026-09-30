import 'package:flutter/services.dart';

/// What the player should do with an arrow or OK press, beyond the reveal.
enum RemoteKeyAction {
  /// Nothing special: fall through to the key handler's ordinary shortcuts
  /// (volume, seek, play/pause) and to focus traversal.
  none,

  /// Controls were hidden on a TV and the key was Left: seek back.
  seekBack,

  /// Controls were hidden on a TV and the key was Right: seek forward.
  seekForward,

  /// Controls were hidden on a TV and the key was Up/Down: they only show.
  /// The key is consumed so it does not also move focus on a screen nobody
  /// can see yet.
  revealOnly,

  /// Controls were up and focus still sat on the screen's own node: hand it
  /// to play/pause, so the next arrow has somewhere to travel from.
  focusPlayPause,
}

/// The outcome for one key press: whether the controls come up, and the
/// action that goes with it.
class RemoteKeyDecision {
  final bool revealControls;
  final RemoteKeyAction action;

  const RemoteKeyDecision(this.revealControls, this.action);

  /// Whether the key stops here rather than continuing to the shortcuts.
  bool get isHandled => action != RemoteKeyAction.none;
}

/// Decides what an arrow or OK press means to the player.
///
/// Pulled out of `PlayerScreen`'s key handler because the TV behaviors it
/// carries (#80) are exactly the ones that cannot be seen from a test that
/// pumps the whole screen, and they regressed silently once: a D-pad that
/// could only pause and play, with no bars. As a pure function of its inputs
/// it can be asserted row by row.
///
/// [hasOverlayOpen] covers every menu and side panel: they own the arrows
/// for their own lists, so nothing here fires. [screenHoldsFocus] is whether
/// the screen's own focus node (not one of the controls) is the primary focus.
RemoteKeyDecision decideRemoteKey({
  required LogicalKeyboardKey key,
  required bool isTv,
  required bool controlsVisible,
  required bool hasOverlayOpen,
  required bool screenHoldsFocus,
}) {
  const none = RemoteKeyDecision(false, RemoteKeyAction.none);
  if (hasOverlayOpen) return none;

  final isArrow = key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;
  final isOk =
      key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.gameButtonA;
  if (!isArrow && !isOk) return none;

  // Off TV the arrows keep their desktop meaning (seek/volume), so the only
  // thing to do is bring the controls back.
  if (!isTv || !isArrow) return const RemoteKeyDecision(true, RemoteKeyAction.none);

  if (!controlsVisible) {
    return RemoteKeyDecision(
      true,
      switch (key) {
        LogicalKeyboardKey.arrowLeft => RemoteKeyAction.seekBack,
        LogicalKeyboardKey.arrowRight => RemoteKeyAction.seekForward,
        _ => RemoteKeyAction.revealOnly,
      },
    );
  }

  return RemoteKeyDecision(
    true,
    screenHoldsFocus ? RemoteKeyAction.focusPlayPause : RemoteKeyAction.none,
  );
}
