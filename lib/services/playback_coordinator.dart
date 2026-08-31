import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A global coordinator that ensures only **one** playback source plays at a
/// time across the whole app (music, video, audiobooks).
///
/// When a new source starts playing, it notifies the previously active source
/// to pause/stop. This prevents multiple streams from playing simultaneously.
///
/// It also exposes the currently active source's display metadata (title,
/// subtitle, cover) and playback state so a single universal play bar can be
/// shown across all hubs.
abstract final class PlaybackCoordinator {
  static String? _activeSourceId;
  static String? _activeKind;
  static VoidCallback? _onStopActive;
  static VoidCallback? _onFullStop;
  static VoidCallback? _onTogglePlayPause;
  static VoidCallback? _onExpand;
  static VoidCallback? _onOpenArtist;
  static ValueChanged<Duration>? _onSeek;
  static VoidCallback? _onNext;
  static VoidCallback? _onPrevious;
  static bool Function()? _isLiked;
  static VoidCallback? _onToggleLike;
  static String? _title;
  static String? _subtitle;
  static String? _coverUrl;
  static bool _isPlaying = false;
  static Duration _position = Duration.zero;
  static Duration _duration = Duration.zero;

  /// Bumped whenever the active source or its state changes, so UI can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Bumps [revision], deferring to after the current frame if called while
  /// Flutter is mid-build/layout/paint -- e.g. `activate()` is commonly
  /// called from a freshly-pushed player's `initState()`, which runs while
  /// the *previous* frame's widgets (like the universal play bar listening
  /// to [revision]) may still be finishing their own build. Notifying
  /// synchronously in that window trips "setState() called during build".
  static void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      revision.value++;
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => revision.value++);
    }
  }

  /// Registers a source as the active playback source. Any previously active
  /// source is told to stop first.
  ///
  /// [sourceId] uniquely identifies the playback source (e.g. a track id, a
  /// video id, an audiobook id). [kind] is a coarse category ('music',
  /// 'video', 'audiobook') used to decide which global shortcuts apply.
  /// [onStop] is called if this source is later superseded by another
  /// source — it should pause, not tear down, so the source can still be
  /// resumed from where it was.
  /// [onFullStop] is called when the user explicitly stops playback (the
  /// play bar's Stop button) — it should fully release the source
  /// (dispose controllers, free network/torrent resources, clear state),
  /// not just pause. Falls back to [onStop] if not provided.
  /// [onTogglePlayPause] lets the universal play bar toggle this source.
  /// [onOpenArtist] lets the play bar's artist label open the artist view.
  /// [onNext]/[onPrevious] advance within the source's own queue or chapter
  /// list. Leave both null for a source with nothing to skip to (a single
  /// video, a live channel) and the skip controls disappear from the
  /// notification rather than appearing dead.
  /// [isLiked]/[onToggleLike] let the play bar show and toggle a like
  /// button for this source (music tracks only — leave both null for
  /// video/audiobook/podcast sources, which have no like concept).
  static void activate(
    String sourceId,
    VoidCallback onStop, {
    String? kind,
    String? title,
    String? subtitle,
    String? coverUrl,
    VoidCallback? onTogglePlayPause,
    VoidCallback? onExpand,
    VoidCallback? onOpenArtist,
    ValueChanged<Duration>? onSeek,
    VoidCallback? onFullStop,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    bool Function()? isLiked,
    VoidCallback? onToggleLike,
  }) {
    if (_activeSourceId == sourceId) return;
    // Stop whatever was playing before.
    _onStopActive?.call();
    _activeSourceId = sourceId;
    _activeKind = kind;
    _title = title;
    _subtitle = subtitle;
    _coverUrl = coverUrl;
    _onStopActive = onStop;
    _onFullStop = onFullStop;
    _onTogglePlayPause = onTogglePlayPause;
    _onExpand = onExpand;
    _onOpenArtist = onOpenArtist;
    _onSeek = onSeek;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _isLiked = isLiked;
    _onToggleLike = onToggleLike;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = true;
    _notify();
  }

  /// Releases the source identified by [sourceId] if it is still the active
  /// one. Call this when a source is disposed.
  static void release(String sourceId) {
    if (_activeSourceId == sourceId) {
      _activeSourceId = null;
      _activeKind = null;
      _title = null;
      _subtitle = null;
      _coverUrl = null;
      _onStopActive = null;
      _onFullStop = null;
      _onTogglePlayPause = null;
      _onExpand = null;
      _onOpenArtist = null;
      _onSeek = null;
      _onNext = null;
      _onPrevious = null;
      _isLiked = null;
      _onToggleLike = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _notify();
    }
  }

  /// Stops the currently active source (if any) without activating a new
  /// one. Fully releases it via [_onFullStop] when the source provided one;
  /// otherwise falls back to the pause-only [_onStopActive].
  static void stopActive() {
    if (_onFullStop != null) {
      _onFullStop!.call();
    } else {
      _onStopActive?.call();
    }
    _activeSourceId = null;
    _activeKind = null;
    _title = null;
    _subtitle = null;
    _coverUrl = null;
    _onStopActive = null;
    _onFullStop = null;
    _onTogglePlayPause = null;
    _onExpand = null;
    _onOpenArtist = null;
    _onSeek = null;
    _onNext = null;
    _onPrevious = null;
    _isLiked = null;
    _onToggleLike = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _notify();
  }

  /// Updates the playing state of the active source (called by the source).
  static void setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    _notify();
  }

  /// Updates the active source's playback progress so the universal play bar
  /// can render a seek bar.
  static void setProgress(Duration position, Duration duration) {
    if (_position == position && _duration == duration) return;
    _position = position;
    _duration = duration;
    _notify();
  }

  /// Seeks the active source to [position] via the play bar's seek bar.
  static void seekTo(Duration position) => _onSeek?.call(position);

  /// Whether the active source can skip forward in its own queue.
  static bool get canSkipNext => _onNext != null;

  /// Whether the active source can skip backward in its own queue.
  static bool get canSkipPrevious => _onPrevious != null;

  /// Skips to the next item in the active source's queue.
  static void skipToNext() => _onNext?.call();

  /// Skips to the previous item in the active source's queue.
  static void skipToPrevious() => _onPrevious?.call();

  /// The active source's current playback position.
  static Duration get position => _position;

  /// The active source's total duration.
  static Duration get duration => _duration;

  /// Toggles play/pause on the active source via the universal play bar.
  static void togglePlayPause() => _onTogglePlayPause?.call();

  /// Expands the active source (e.g. opens the full music player).
  static void expand() => _onExpand?.call();

  /// Opens the artist for the active source (music tracks only).
  static void openArtist() => _onOpenArtist?.call();

  /// Whether the active source supports liking (music tracks only).
  static bool get canLike => _isLiked != null;

  /// Whether the active source is currently liked. False if [canLike] is
  /// false.
  static bool get isLiked => _isLiked?.call() ?? false;

  /// Toggles the active source's liked state via the universal play bar.
  static void toggleLike() {
    _onToggleLike?.call();
    _notify();
  }

  /// Dismisses the play bar without stopping playback (hides the bar only).
  static void dismiss() {
    _activeSourceId = null;
    _activeKind = null;
    _title = null;
    _subtitle = null;
    _coverUrl = null;
    _onStopActive = null;
    _onFullStop = null;
    _onTogglePlayPause = null;
    _onExpand = null;
    _onOpenArtist = null;
    _onSeek = null;
    _onNext = null;
    _onPrevious = null;
    _isLiked = null;
    _onToggleLike = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _notify();
  }

  /// Whether [sourceId] is currently the active playback source.
  static bool isActive(String sourceId) => _activeSourceId == sourceId;

  /// Whether there is an active playback source.
  static bool get hasActive => _activeSourceId != null;

  /// The kind of the currently active source, or null if nothing is active.
  static String? get activeKind => _activeKind;

  /// Display title of the active source.
  static String? get title => _title;

  /// Display subtitle (artist / episode / chapter) of the active source.
  static String? get subtitle => _subtitle;

  /// Cover/thumbnail URL of the active source.
  static String? get coverUrl => _coverUrl;

  /// Whether the active source is currently playing.
  static bool get isPlaying => _isPlaying;
}

