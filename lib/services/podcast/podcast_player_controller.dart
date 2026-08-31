import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../playback_coordinator.dart';
import 'podcast_service.dart';

/// Plays one podcast episode at a time in the background, matching
/// [AudiobookPlayerController]'s shape but simpler -- a podcast episode is
/// a single audio stream, no chapters.
class PodcastPlayerController extends ChangeNotifier {
  static final PodcastPlayerController instance = PodcastPlayerController._internal();
  PodcastPlayerController._internal();

  VideoPlayerController? _controller;
  PodcastResult? _podcast;
  PodcastEpisode? _episode;
  bool _isPlaying = false;
  bool _isLoading = false;

  VoidCallback? _onExpandRequested;

  PodcastResult? get podcast => _podcast;
  PodcastEpisode? get episode => _episode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get hasEpisode => _episode != null;

  void setExpandCallback(VoidCallback callback) {
    _onExpandRequested = callback;
  }

  Future<void> play(PodcastResult podcast, PodcastEpisode episode) async {
    _podcast = podcast;
    _episode = episode;
    _isLoading = true;
    notifyListeners();

    PlaybackCoordinator.activate(
      'podcast:${podcast.id}:${episode.audioUrl}',
      () {
        _controller?.pause();
        _isPlaying = false;
        notifyListeners();
      },
      kind: 'podcast',
      title: episode.title,
      subtitle: podcast.name,
      coverUrl: podcast.artworkUrl,
      onTogglePlayPause: togglePlayPause,
      onExpand: _onExpandRequested,
      onSeek: seekTo,
      onFullStop: stop,
    );

    if (_controller != null) {
      _controller!.removeListener(_onPlayerStateChanged);
      await _controller!.dispose();
      _controller = null;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(episode.audioUrl));
      await controller.initialize();
      controller.addListener(_onPlayerStateChanged);
      _controller = controller;
      _isLoading = false;
      _isPlaying = true;
      await controller.play();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      debugPrint('Podcast playback error: $e');
      notifyListeners();
    }
  }

  void _onPlayerStateChanged() {
    final c = _controller;
    if (c == null) return;
    final value = c.value;
    PlaybackCoordinator.setProgress(value.position, value.duration);
    final playing = value.isPlaying;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      PlaybackCoordinator.setPlaying(playing);
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  Future<void> stop() async {
    PlaybackCoordinator.release(
      _podcast != null && _episode != null ? 'podcast:${_podcast!.id}:${_episode!.audioUrl}' : '',
    );
    _controller?.removeListener(_onPlayerStateChanged);
    await _controller?.dispose();
    _controller = null;
    _podcast = null;
    _episode = null;
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    super.dispose();
  }
}
