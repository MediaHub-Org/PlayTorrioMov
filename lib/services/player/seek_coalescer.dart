import 'dart:async';

/// Turns a burst of "skip ten seconds" presses into one seek.
///
/// Every press used to be a seek: hold an arrow on a remote and mpv was told to
/// jump thirty times a second. For a network stream each jump throws away the
/// cache and asks the server (or the swarm) for a different byte range, so the
/// requests pile up behind each other and the picture only settles when the
/// last one lands -- the seconds of nothing people feel when they "go forward
/// and back a bit". The target is worked out on the spot, shown at once, and
/// the player is asked for it when the presses pause.
///
/// **A hold does not wait for its release.** The wait is restarted by each
/// press, but never for longer than [maxWait] from the first, so holding a key
/// still moves the picture every so often and the viewer can see where they
/// are going.
///
/// With a [delay] of zero (a file on disk, where a seek costs nothing) every
/// press seeks straight away.
class SeekCoalescer {
  /// Asked for the position once the presses pause.
  final void Function(Duration target) onSeek;

  /// Quiet time after the last press before the player is asked.
  Duration delay;

  /// The longest the first press of a burst is held back.
  final Duration maxWait;

  SeekCoalescer({
    required this.onSeek,
    this.delay = const Duration(milliseconds: 250),
    this.maxWait = const Duration(milliseconds: 900),
  });

  Duration? _pending;
  Timer? _timer;
  DateTime? _burstStart;

  /// The position the viewer has asked for and the player has not been told
  /// about yet, or null.
  Duration? get pending => _pending;

  bool get isPending => _pending != null;

  /// Moves the target by [offset] and returns it.
  ///
  /// A burst builds on its own target; the first press builds on [from], where
  /// the player is. The result stays within the media when [duration] is known.
  Duration nudge({
    required Duration from,
    required Duration offset,
    Duration duration = Duration.zero,
  }) {
    final base = _pending ?? from;
    var target = base + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    _pending = target;

    if (delay == Duration.zero) {
      flush();
      return target;
    }

    final now = DateTime.now();
    _burstStart ??= now;
    final heldFor = now.difference(_burstStart!);
    final remaining = maxWait - heldFor;
    final wait = remaining < delay ? remaining : delay;
    _timer?.cancel();
    _timer = Timer(wait.isNegative ? Duration.zero : wait, flush);
    return target;
  }

  /// Asks the player for the pending position now.
  void flush() {
    final target = _pending;
    _timer?.cancel();
    _timer = null;
    _burstStart = null;
    _pending = null;
    if (target != null) onSeek(target);
  }

  /// Drops the pending position. For a seek that comes from somewhere else (a
  /// drag on the bar) and replaces whatever the presses were heading for.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _burstStart = null;
    _pending = null;
  }

  void dispose() => cancel();
}
