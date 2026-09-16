// lib/services/player/sleep_timer_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// The player's sleep timer: pause playback after a chosen number of minutes.
///
/// The chips existed in the speed menu for several releases before this
/// service did, and choosing one changed nothing -- there was no timer
/// behind them. This is the timer.
///
/// A singleton with a [ValueNotifier] rather than player-screen state,
/// because the countdown has to survive the controls hiding and the menus
/// opening and closing, and because the button that shows it lives in the
/// transport bar while the cancellation lives wherever the user happens to
/// tap. One owner, one source of truth.
class SleepTimerService {
  SleepTimerService._();
  static final SleepTimerService instance = SleepTimerService._();

  /// Minutes remaining, or null when no timer is running. Listened to by the
  /// transport bar's button, which shows the count in its badge.
  final ValueNotifier<int?> minutesRemaining = ValueNotifier<int?>(null);

  /// Called when the countdown reaches zero. The player screen supplies it,
  /// and pauses playback there -- the service owns the clock, not the
  /// player, so it has no business reaching into playback itself.
  VoidCallback? onExpired;

  Timer? _ticker;

  /// Starts (or restarts) the timer at [minutes]. Passing a value while one
  /// is already running replaces it -- the last choice wins, which is what a
  /// viewer tapping "60" after "15" means.
  void start(int minutes) {
    cancel();
    minutesRemaining.value = minutes;
    // A one-minute ticker rather than a single Timer for the whole span:
    // the badge then counts down visibly, which is the difference between
    // a timer that is running and one the user has to take on faith.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      final remaining = minutesRemaining.value;
      if (remaining == null) return;
      if (remaining <= 1) {
        cancel();
        onExpired?.call();
      } else {
        minutesRemaining.value = remaining - 1;
      }
    });
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    minutesRemaining.value = null;
  }
}
