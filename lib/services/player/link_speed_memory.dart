import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this device's connection has been seen to carry, remembered between
/// playbacks so the next source list can start with releases it can play.
///
/// **It only ever learns from trouble.** The number is a download rate seen
/// while the player was starved and waiting, which is the one moment the
/// connection is the limit. A fast start proves nothing about the ceiling: the
/// cache fills in a second or two and the rate drops because there is nothing
/// left to ask for, so a "measured speed" taken then would call every link
/// slow. With no stall there is no estimate and no cap, and a 4K release stays
/// where it was.
///
/// And it forgets: a long run of clean playback lifts the estimate, because a
/// phone that moved from a bad signal to a good one should not keep being
/// offered 720p.
///
/// One value for the device, not per network. Telling a hotspot from the
/// home's Wi-Fi needs a connectivity plugin this app does not carry, and the
/// decay above does the job of noticing the move.
abstract final class LinkSpeedMemory {
  static const _key = 'link_speed_kbps';

  /// Below this a "rate" is a stalled connection or a measuring glitch, not
  /// a link speed: it would cap every release at nothing.
  static const int _floorKbps = 800;

  /// Above this the estimate stops growing; no source here needs more.
  static const int _ceilingKbps = 200000;

  /// The estimated link capacity in kb/s, or null while nothing has gone wrong.
  static final ValueNotifier<int?> kbps = ValueNotifier<int?>(null);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      kbps.value = prefs.getInt(_key);
    } catch (e) {
      debugPrint('[LinkSpeedMemory] Error initializing: $e');
    }
  }

  /// The most video bitrate worth offering first, or null when the link has
  /// not been seen struggling. A margin under the capacity: video at the
  /// link's full rate still stalls on every dip.
  static int? get sustainableKbps {
    final measured = kbps.value;
    if (measured == null) return null;
    return (measured * 0.75).round();
  }

  /// The player stalled while the connection delivered [observedKbps].
  ///
  /// Averaged with what was known, so one bad minute in a tunnel does not
  /// decide the next week.
  static Future<void> recordStall(int observedKbps) async {
    if (observedKbps < _floorKbps) return;
    final known = kbps.value;
    final next = known == null
        ? observedKbps
        : ((known + observedKbps) / 2).round();
    await _save(next.clamp(_floorKbps, _ceilingKbps));
  }

  /// A long stretch played without a stall: the estimate was too low or the
  /// link has improved. Nothing to do while there is no estimate.
  static Future<void> recordSmooth() async {
    final known = kbps.value;
    if (known == null) return;
    final next = (known * 1.25).round();
    if (next >= _ceilingKbps) {
      await forget();
      return;
    }
    await _save(next);
  }

  /// Back to "nothing known".
  static Future<void> forget() async {
    kbps.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[LinkSpeedMemory] Error clearing: $e');
    }
  }

  static Future<void> _save(int value) async {
    kbps.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, value);
    } catch (e) {
      debugPrint('[LinkSpeedMemory] Error saving: $e');
    }
  }
}
