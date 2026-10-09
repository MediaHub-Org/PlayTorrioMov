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
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      isTv.value = await _channel.invokeMethod<bool>('isTv') ?? false;
      applyFocusStrategy(isTv.value);
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
}
