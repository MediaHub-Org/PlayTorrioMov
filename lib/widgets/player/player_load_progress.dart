import 'package:flutter/foundation.dart';

/// How far along "press play" is, as one number from 0 to 1.
///
/// Starting a stream is three waits in a row, and only the last two can be
/// measured: working out where the video lives (a debrid lookup, or a torrent
/// finding peers and the file list), handing it to the player, and then the
/// player or the torrent engine filling enough buffer to show a frame. The
/// first has no fraction of its own, so each step we can *name* moves the bar
/// to a fixed mark, and the buffering step, which does report real progress
/// (mpv's cache fill, TorrServer's preload), spreads across what is left.
/// The bar therefore only moves forward and never claims a percentage it
/// cannot back with something that actually happened.
class PlayerLoadProgress extends ValueNotifier<double> {
  PlayerLoadProgress() : super(0);

  /// The stream has been asked for.
  static const double started = 0.05;

  /// A source is being resolved: debrid is answering, or the torrent is
  /// looking for peers.
  static const double resolving = 0.15;

  /// The stream URL is known.
  static const double resolved = 0.30;

  /// The player has the URL and is opening it. Buffering fills the rest.
  static const double opened = 0.40;

  /// Moves the bar to [mark] if that is further than it already is.
  void reach(double mark) {
    final clamped = mark.clamp(0.0, 1.0);
    if (clamped > value) value = clamped;
  }

  /// Maps the buffering step's own 0..1 fraction onto what is left of the bar.
  void reachBuffering(double fraction) =>
      reach(opened + (1 - opened) * fraction.clamp(0.0, 1.0));

  void reset() => value = 0;

  /// The whole percent shown to the user. Rounds down so "100%" only ever
  /// appears when the load really is done.
  static int percentOf(double progress) =>
      (progress * 100).floor().clamp(0, 100);
}
