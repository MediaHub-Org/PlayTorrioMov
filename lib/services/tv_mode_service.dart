import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Whether the app is running on an actual Android TV device, not a phone or
/// tablet sized like one.
///
/// Checked once at startup against Android's own `UiModeManager`
/// (`UI_MODE_TYPE_TELEVISION`) over a platform channel, not a pub dependency
/// and not a width/aspect-ratio heuristic -- the latter would misidentify a
/// tablet or Chromebook in landscape as a TV. `ScreenTier`
/// (`app_breakpoints.dart`) still answers "how much width is there"; this
/// answers a different question, "is this screen 8-10 feet away," which
/// phases 2 and 3 of #80 (type/spacing, and sheets becoming full-screen
/// routes) gate on. See #80 in docs/ROADMAP.md.
abstract final class TvModeService {
  static const _channel = MethodChannel('com.example.playtorrio/tv_mode');

  /// False until [initialize] resolves it, and permanently false off
  /// Android -- only Android exposes `UiModeManager`.
  static final ValueNotifier<bool> isTv = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    installFocusPolicy();
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      isTv.value = await _channel.invokeMethod<bool>('isTv') ?? false;
      // A key may have arrived while the channel was still answering; then
      // the answer applies now, not at the next key.
      if (_keyboardSeen) applyFocusStrategy(isTv.value);
    } catch (e) {
      // Optional signal, not a startup requirement -- phases 2/3 read it to
      // decide whether to apply TV-specific treatment, and simply don't if
      // it stays false.
      debugPrint('[TvModeService] initialize error: $e');
    }
  }

  /// On a TV, focus is always drawn.
  ///
  /// Flutter shows focus only while it believes the viewer is using keys
  /// ([FocusHighlightMode.traditional]); it starts a phone in touch mode and
  /// drops back to it on any pointer event. A TV has no touch, but a remote
  /// app, an air mouse or a USB mouse sends pointer events, and after one the
  /// Material controls drew no focus at all -- the cursor was somewhere, and
  /// to a viewer on the couch the app had lost its place. Pinning the mode
  /// keeps the cue on, whatever last touched the screen.
  @visibleForTesting
  static void applyFocusStrategy(bool isTv) {
    FocusManager.instance.highlightStrategy = isTv
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.automatic;
  }

  /// Focus is drawn only once the viewer has pressed a key.
  ///
  /// Flutter starts a desktop in traditional mode, so the first card that
  /// FirstFocusScope hands focus to zoomed on open, for a mouse viewer who
  /// never touched a key. Starting in touch mode draws nothing until a key
  /// arrives. The first key then sets the strategy the app would have had
  /// anyway: pinned on a TV, Flutter's own choice everywhere else.
  ///
  /// The hook is a [HardwareKeyboard] handler, not a focus one: the hardware
  /// handlers see a key before the focus system does, and they run even when
  /// nothing holds focus yet, which a focus-side handler would skip.
  static void installFocusPolicy() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  static bool _keyboardSeen = false;

  static bool _onHardwareKey(KeyEvent event) {
    if (_keyboardSeen || event is! KeyDownEvent) return false;
    _keyboardSeen = true;
    applyFocusStrategy(isTv.value);
    // Not handled: the key still goes on to move focus.
    return false;
  }

  /// Returns the focus policy to where a fresh launch starts. Tests only.
  @visibleForTesting
  static void resetFocusPolicy() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _keyboardSeen = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  }
}
