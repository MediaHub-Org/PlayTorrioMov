/// Why a playback is slow, from the numbers the player already has.
///
/// "Slow, worse on the TV" has at least two different causes that need
/// different answers: the connection cannot carry the file, or the device
/// cannot decode it. Telling them apart is what turns a guess into a fix, so
/// the stats panel runs this once a second and says which it is in a
/// sentence.
enum PlaybackVerdict {
  /// Nothing to report yet: not enough numbers.
  unknown,

  /// Playing normally.
  healthy,

  /// The cache is nearly empty and the connection is delivering less than the
  /// video needs. A lighter source, or a better link.
  linkTooSlow,

  /// The cache is healthy and frames are still being dropped: the device
  /// cannot keep up with the video. A lighter release (smaller resolution or
  /// H.264 rather than HEVC 10-bit) is the fix.
  decoderStruggling,
}

/// The reading behind a verdict, as the panel shows it.
class PlaybackDiagnosis {
  final PlaybackVerdict verdict;

  /// What the video needs, in kb/s, when it is known.
  final int? needKbps;

  /// What the connection is delivering, in kb/s, when it is known.
  final int? haveKbps;

  const PlaybackDiagnosis(this.verdict, {this.needKbps, this.haveKbps});
}

/// Frames dropped in a window longer than this, with a healthy cache, are the
/// decoder.
const int _droppedFramesThatMatter = 10;

/// A cache below this many seconds is "starved"; above it, the network is not
/// what is making the picture stutter.
const double _starvedBelowSeconds = 5;

/// A connection must beat the bitrate by this much to carry it: video at
/// exactly the link's rate stalls on every dip.
const double _headroom = 1.1;

/// Reads the numbers and decides.
///
/// [needKbps] is the stream's own bitrate (mpv's measurement, else the
/// source's stated or estimated one). [haveKbps] is the cache's fill rate,
/// which is only the connection's rate while the cache is hungry, so it is
/// trusted only when [bufferedSeconds] is low. [droppedRecently] is frames
/// dropped over the last few seconds, not since the start: an old burst while
/// seeking is not a live problem.
PlaybackDiagnosis diagnose({
  int? needKbps,
  int? haveKbps,
  double? bufferedSeconds,
  int droppedRecently = 0,
}) {
  if (bufferedSeconds == null) {
    return PlaybackDiagnosis(
      PlaybackVerdict.unknown,
      needKbps: needKbps,
      haveKbps: haveKbps,
    );
  }

  final starved = bufferedSeconds < _starvedBelowSeconds;
  if (starved &&
      needKbps != null &&
      haveKbps != null &&
      haveKbps < needKbps * _headroom) {
    return PlaybackDiagnosis(
      PlaybackVerdict.linkTooSlow,
      needKbps: needKbps,
      haveKbps: haveKbps,
    );
  }

  if (!starved && droppedRecently >= _droppedFramesThatMatter) {
    return PlaybackDiagnosis(
      PlaybackVerdict.decoderStruggling,
      needKbps: needKbps,
      haveKbps: haveKbps,
    );
  }

  return PlaybackDiagnosis(
    PlaybackVerdict.healthy,
    needKbps: needKbps,
    haveKbps: haveKbps,
  );
}
