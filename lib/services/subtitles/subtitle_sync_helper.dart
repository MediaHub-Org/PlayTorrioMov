import 'dart:math';
import 'subtitle_parser.dart';

class SyncPoint {
  final double t; // Original cue start time
  final double at; // Target playback timestamp when spoken

  const SyncPoint({
    required this.t,
    required this.at,
  });

  double get delta => at - t;

  @override
  String toString() => 'SyncPoint(t: $t, at: $at, delta: $delta)';
}

class SyncSegment {
  final int startIdx;
  final int endIdx;
  final double offsetSec;

  const SyncSegment({
    required this.startIdx,
    required this.endIdx,
    required this.offsetSec,
  });

  bool contains(int index) => index >= startIdx && index <= endIdx;

  @override
  String toString() => 'SyncSegment($startIdx..$endIdx, offset: $offsetSec)';
}

class SubtitleSyncHelper {
  /// Computes the delta offset function based on anchor points and a global nudge.
  static double computeDelta(double t, List<SyncPoint> points, double nudge) {
    if (points.isEmpty) return nudge;

    if (points.length == 1) {
      final d = points.first.at - points.first.t;
      return d + nudge;
    }

    final sorted = List<SyncPoint>.from(points)..sort((a, b) => a.t.compareTo(b.t));
    final a = sorted.first;
    final b = sorted.last;
    final d1 = a.at - a.t;
    final span = b.t - a.t;

    if (span.abs() < 1e-6) {
      return d1 + nudge;
    }

    final m = ((b.at - b.t) - d1) / span;
    return d1 + m * (t - a.t) + nudge;
  }

  /// Applies linear sync, nudge, and section offsets to all subtitle cues.
  static List<SubCue> applyLinearSync({
    required List<SubCue> cues,
    required List<SyncPoint> points,
    double nudge = 0.0,
    List<SyncSegment> segments = const [],
  }) {
    return List<SubCue>.generate(cues.length, (i) {
      final cue = cues[i];
      double segExtra = 0.0;
      for (final seg in segments) {
        if (seg.contains(i)) {
          segExtra += seg.offsetSec;
        }
      }

      final startDelta = computeDelta(cue.start, points, nudge) + segExtra;
      final endDelta = computeDelta(cue.end, points, nudge) + segExtra;

      final start = _round3(max(0.0, cue.start + startDelta));
      final endCandidate = _round3(cue.end + endDelta);
      final end = max(start + 0.001, endCandidate);

      return cue.copyWith(start: start, end: end);
    });
  }

  static double _round3(double v) {
    return (v * 1000).round() / 1000.0;
  }
}
