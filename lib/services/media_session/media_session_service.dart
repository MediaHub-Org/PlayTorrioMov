import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../../app_info.dart';
import '../playback_coordinator.dart';

/// Publishes whatever [PlaybackCoordinator] is playing to the operating
/// system's media session — the Android notification shade and lock screen,
/// the iOS lock screen and Control Center, Bluetooth and headset buttons.
///
/// Before this, audio played through libmpv with no session attached: starting
/// a track and pulling down the shade showed nothing, so the only way to pause
/// was to return to the app, and Android was free to kill the process the
/// moment it was backgrounded.
///
/// The handler deliberately owns no player. `audio_service` is normally the
/// thing that *does* the playing, but every source here already has its own
/// controller, and [PlaybackCoordinator] already knows which one is active and
/// how to drive it. So this mirrors in both directions instead: coordinator
/// state out to the notification, notification buttons back in as coordinator
/// calls. One handler therefore covers music, podcasts and audiobooks — and
/// anything else that registers with the coordinator later — rather than each
/// growing its own session.
abstract final class MediaSessionService {
  static _CoordinatorAudioHandler? _handler;
  static bool _initialising = false;

  /// Whether a media session is running. False on platforms where one is not
  /// offered, and false if initialisation failed.
  static bool get isActive => _handler != null;

  /// Platforms with a system media session worth publishing to.
  ///
  /// The desktop targets have their own conventions (SMTC, MPRIS) that
  /// `audio_service` does not implement, so asking for a session there would
  /// pay the init cost for nothing.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Starts the media session. Safe to call more than once; only the first
  /// call does anything.
  ///
  /// Failure is not fatal — the app plays fine without a session, it just
  /// loses the notification controls — so this swallows errors rather than
  /// taking startup down with it.
  static Future<void> init() async {
    if (_handler != null || _initialising || !isSupported) return;
    _initialising = true;
    try {
      _handler = await AudioService.init(
        builder: _CoordinatorAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.mediahub.playtorriomod.audio',
          androidNotificationChannelName: '${AppInfo.name} playback',
          androidNotificationChannelDescription:
              'Shows what is playing and lets you control it.',
          // Keep the notification (and the foreground service) alive while
          // paused. Dropping it on pause makes a paused track unresumable
          // from the shade, which is the state people leave audio in most.
          androidStopForegroundOnPause: false,
          androidNotificationOngoing: false,
        ),
      );
    } catch (e, st) {
      debugPrint('Media session unavailable: $e\n$st');
      _handler = null;
    } finally {
      _initialising = false;
    }
  }
}

/// The buttons to publish, and which of them survive the Android shade's
/// collapsed row (which shows at most three).
///
/// Pulled out of the handler because the compact indices point *into* the
/// control list: add or drop a button without adjusting them and the shade
/// silently shows the wrong three, or throws on an index past the end. Keeping
/// both halves in one function is what makes that testable.
@visibleForTesting
({List<MediaControl> controls, List<int> compactIndices}) buildMediaControls({
  required bool playing,
  required bool canPrevious,
  required bool canNext,
}) {
  final controls = <MediaControl>[
    if (canPrevious) MediaControl.skipToPrevious,
    playing ? MediaControl.pause : MediaControl.play,
    if (canNext) MediaControl.skipToNext,
    MediaControl.stop,
  ];
  // Everything except Stop, which the shade's swipe-away already covers.
  final compact = [
    for (var i = 0; i < controls.length - 1; i++) i,
  ];
  return (controls: controls, compactIndices: compact);
}

/// Mirrors [PlaybackCoordinator] into an `audio_service` session.
class _CoordinatorAudioHandler extends BaseAudioHandler with SeekHandler {
  _CoordinatorAudioHandler() {
    PlaybackCoordinator.revision.addListener(_sync);
    _sync();
  }

  /// The last state pushed, so a coordinator revision that changed something
  /// the session does not care about does not churn the notification.
  String? _lastSignature;

  void _sync() {
    if (!PlaybackCoordinator.hasActive) {
      _lastSignature = null;
      mediaItem.add(null);
      playbackState.add(PlaybackState(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      return;
    }

    final title = PlaybackCoordinator.title ?? AppInfo.name;
    final subtitle = PlaybackCoordinator.subtitle ?? '';
    final cover = PlaybackCoordinator.coverUrl;
    final duration = PlaybackCoordinator.duration;
    final playing = PlaybackCoordinator.isPlaying;
    final canNext = PlaybackCoordinator.canSkipNext;
    final canPrev = PlaybackCoordinator.canSkipPrevious;

    final signature = '$title|$subtitle|$cover|$duration|$playing|'
        '$canNext|$canPrev|${PlaybackCoordinator.activeKind}';
    if (signature != _lastSignature) {
      _lastSignature = signature;
      mediaItem.add(MediaItem(
        id: PlaybackCoordinator.title ?? 'playtorrio',
        title: title,
        artist: subtitle.isEmpty ? null : subtitle,
        // A zero duration would render the shade's scrubber as a finished
        // track; omitting it renders no scrubber at all, which is honest
        // while the real duration is still being resolved.
        duration: duration > Duration.zero ? duration : null,
        artUri: _artUri(cover),
      ));
    }

    final buttons = buildMediaControls(
      playing: playing,
      canPrevious: canPrev,
      canNext: canNext,
    );

    playbackState.add(PlaybackState(
      controls: buttons.controls,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: buttons.compactIndices,
      processingState: AudioProcessingState.ready,
      playing: playing,
      updatePosition: PlaybackCoordinator.position,
    ));
  }

  /// Cover art has to be a URI the platform can fetch. A relative path or an
  /// asset key would make `audio_service` throw on the platform channel, so
  /// anything that is not an absolute URL or file is dropped and the
  /// notification falls back to the app icon.
  static Uri? _artUri(String? cover) {
    if (cover == null || cover.isEmpty) return null;
    final uri = Uri.tryParse(cover);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file') {
      return null;
    }
    return uri;
  }

  // The coordinator exposes a single toggle rather than separate play/pause
  // callbacks, so each of these guards on the current state — a "play" press
  // while already playing must not pause.
  @override
  Future<void> play() async {
    if (!PlaybackCoordinator.isPlaying) PlaybackCoordinator.togglePlayPause();
  }

  @override
  Future<void> pause() async {
    if (PlaybackCoordinator.isPlaying) PlaybackCoordinator.togglePlayPause();
  }

  @override
  Future<void> stop() async {
    PlaybackCoordinator.stopActive();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async =>
      PlaybackCoordinator.seekTo(position);

  @override
  Future<void> skipToNext() async => PlaybackCoordinator.skipToNext();

  @override
  Future<void> skipToPrevious() async => PlaybackCoordinator.skipToPrevious();
}
