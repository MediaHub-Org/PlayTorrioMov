import 'package:flutter/services.dart';

/// The keys that press a focused control: Enter, the number pad's Enter, a
/// TV remote's OK (`select`) and a game controller's A.
///
/// Thirteen files each declared their own copy, and they drifted: one had
/// Space and the rest did not. `final`, not `const`: `LogicalKeyboardKey`
/// overrides `==`, and the analyzer rejects that inside a `const` set literal.
final Set<LogicalKeyboardKey> kActivateKeys = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

/// [kActivateKeys] and Space, for a control a keyboard user presses like a
/// button. Not the default: Space scrolls a page and pauses a video, and a card
/// or a row inside either must not swallow it.
final Set<LogicalKeyboardKey> kActivateKeysWithSpace = {
  ...kActivateKeys,
  LogicalKeyboardKey.space,
};
