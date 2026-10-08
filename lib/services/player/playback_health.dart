/// Watches how a playback is going once it has started, and says so at the
/// three moments that matter: the connection was the limit, a long stretch
/// went fine, and the picture keeps stopping.
///
/// Pure bookkeeping with the clock passed in, so the thresholds can be tested
/// without a player or a wait. The screen feeds it one [tick] a second and
/// acts on the callbacks.
///
/// **Only a stall that outlasts [slowStall] counts as the link being the limit.**
/// A buffer that dips for a second and recovers is the cache doing its job,
/// and a rate sampled then is not the connection's ceiling. A starved wait of
/// several seconds is, and the rate during it is the best measurement there is.
class PlaybackHealth {
  /// A stall at least this long, with samples, means the link is the limit.
  final Duration slowStall;

  /// Playing this long without a slow stall means the link is carrying it.
  final Duration smoothSpan;

  /// This many stalls inside [offerWindow] is "it keeps stopping".
  final int stallsForOffer;
  final Duration offerWindow;

  /// Shortest pause that is counted as a stall at all. A single dropped
  /// buffer for a moment is not one.
  final Duration minStall;

  /// Do not offer again for this long after offering.
  final Duration offerCooldown;

  /// Called once per slow stall with the download rate seen during it, in kb/s
  /// (the median, so one burst does not decide).
  final void Function(int medianKbps) onSlowLink;

  /// Called after [smoothSpan] of playing without a slow stall, and again for
  /// each further span.
  final void Function() onSmooth;

  /// Called when playback keeps stopping. At most once per [offerCooldown].
  final void Function() onRepeatedStalls;

  PlaybackHealth({
    required this.onSlowLink,
    required this.onSmooth,
    required this.onRepeatedStalls,
    this.slowStall = const Duration(seconds: 4),
    this.smoothSpan = const Duration(seconds: 120),
    this.stallsForOffer = 3,
    this.offerWindow = const Duration(minutes: 3),
    this.minStall = const Duration(seconds: 2),
    this.offerCooldown = const Duration(minutes: 10),
  });

  bool _wasBuffering = false;
  DateTime? _stallStart;
  final List<int> _samples = [];
  final List<DateTime> _stallTimes = [];
  DateTime? _smoothSince;
  DateTime? _lastOffer;

  /// One observation. [observedKbps] is the download rate right now, or null
  /// when it could not be read.
  void tick({
    required bool isBuffering,
    required int? observedKbps,
    required DateTime now,
  }) {
    if (isBuffering) {
      if (!_wasBuffering) {
        _stallStart = now;
        _samples.clear();
        _smoothSince = null;
      }
      if (observedKbps != null) _samples.add(observedKbps);
    } else {
      if (_wasBuffering) _endStall(now);
      _smoothSince ??= now;
      if (now.difference(_smoothSince!) >= smoothSpan) {
        _smoothSince = now;
        onSmooth();
      }
    }
    _wasBuffering = isBuffering;
  }

  void _endStall(DateTime now) {
    final start = _stallStart;
    _stallStart = null;
    if (start == null) return;
    final length = now.difference(start);

    if (length >= slowStall && _samples.length >= 3) {
      final sorted = [..._samples]..sort();
      onSlowLink(sorted[sorted.length ~/ 2]);
    }
    _samples.clear();

    if (length < minStall) return;
    _stallTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > offerWindow);
    final recentlyOffered =
        _lastOffer != null && now.difference(_lastOffer!) < offerCooldown;
    if (_stallTimes.length >= stallsForOffer && !recentlyOffered) {
      _lastOffer = now;
      _stallTimes.clear();
      onRepeatedStalls();
    }
  }
}
