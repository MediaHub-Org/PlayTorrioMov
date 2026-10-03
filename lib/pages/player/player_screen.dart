import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/models/movie/movie_detail.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/services/subtitles/subtitle_service.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';
import 'package:playtorriomov/services/subtitles/subtitle_parser.dart';

import '../../models/stream/stream_model.dart';
import '../../services/playback_coordinator.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/player/player_settings.dart';
import '../../services/sources/source_filter_settings.dart';

import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/back_press_decision.dart';
import '../../widgets/player/remote_key_decision.dart';
import '../../widgets/player/player_transport.dart';
import '../../widgets/player/player_load_progress.dart';
import '../../widgets/player/player_loading_logo.dart';
import '../../widgets/player/player_volume_menu.dart';
import '../../widgets/player/player_center_controls.dart';
import '../../widgets/player/player_seek_feedback.dart';
import '../../widgets/player/sleep_timer_menu.dart';
import '../../widgets/player/player_subtitle_menu.dart';
import '../../widgets/player/player_audio_menu.dart';
import '../../services/player/sleep_timer_service.dart';
import '../../widgets/player/player_speed_menu.dart';
import '../../services/window/window_service.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/skip_segments_service.dart';
import '../../services/tv_mode_service.dart';
import '../../widgets/player/player_aspect_menu.dart' show PlayerAspectMenu;
import '../../widgets/player/subtitle_overlay.dart';
import '../../widgets/player/player_skip_button.dart';
import '../../widgets/player/player_episodes_panel.dart';
import '../../widgets/player/player_sources_panel.dart';
import '../../widgets/player/player_volume_control.dart';
import '../../widgets/player/sub_sync_bar.dart';
import '../../widgets/player/text_sync_overlay.dart';
import '../../widgets/player/player_cast_sheet.dart';
import '../../widgets/player/player_stats_menu.dart';
import '../../services/cast/cast_service.dart';
import '../../services/tv_type.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../utils/download/download_launcher.dart';
import '../../services/app_units.dart';

class PlayerScreen extends StatefulWidget {
  final StreamSource source;
  final String title;
  final String? backdropUrl;
  final String? logoUrl;
  final MovieDetail? detail;
  final Video? episode;
  final VoidCallback? onNextEpisode;
  final Duration? initialPosition;

  const PlayerScreen({
    super.key,
    required this.source,
    required this.title,
    this.backdropUrl,
    this.logoUrl,
    this.detail,
    this.episode,
    this.onNextEpisode,
    this.initialPosition,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Player _player = Player(
    configuration: PlayerSettings.getMediaKitPlayerConfiguration(),
  );
  late final mk.VideoController _videoController = mk.VideoController(
    _player,
    configuration: PlayerSettings.getVideoControllerConfiguration(),
  );
  final List<StreamSubscription> _subscriptions = [];

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration?> _bufferNotifier = ValueNotifier<Duration?>(
    null,
  );

  bool _isLoading = true;

  /// Set when playback has failed with no automatic way forward. Only movies
  /// reach this: an episode has the sources panel to fall back to, so it
  /// recovers there instead. Until this existed, a failed movie left
  /// _isLoading true forever -- a spinner over a black screen with an error
  /// caption and nothing to press.
  String? _fatalError;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _buffered;
  bool _wasBuffering = false;
  /// The loading screen's status line, as a function of the language rather
  /// than a string: it is set from async code and field initializers, where
  /// there is no context to look a translation up with.
  String Function(AppLocalizations) _status =
      (l10n) => l10n.playerStatusInitializing;
  bool _showControls = true;
  bool _isHoveringUI = false;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  DateTime? _lastPointerTimerReset;
  /// 0..1 for the loading logo; see [PlayerLoadProgress] for what moves it.
  final PlayerLoadProgress _loadProgress = PlayerLoadProgress();

  /// True from the moment the player has been handed the stream until it has
  /// actually produced playback. `open()` returns as soon as mpv accepts the
  /// URL, long before a frame exists, so without this the loading screen
  /// vanished into a black video for however long the buffer took to fill.
  bool _awaitingFirstFrame = false;
  StreamSubscription<TorrentStats>? _preloadSub;
  Timer? _firstFrameTimeout;

  // Active Menu / Popover
  // 'settings' is the gear; 'audio', 'speed' and 'aspect' are the popovers
  // its rows open. 'subtitle' and 'style' are reached from the transport
  // bar directly.
  String? _activeMenu;

  /// Whether the subtitle appearance editor is open. While it is, the video
  /// shows sample subtitles in the current style (there may be no dialogue on
  /// screen to judge it by), and the subtitle panel moves to the top so it
  /// does not sit on top of them.
  bool _showSubtitleSample = false;
  bool _showSubSyncBar = false;
  bool _showTextSyncOverlay = false;

  // Playback & Audio State
  double _volume = 1.0;
  double _lastVolumeBeforeMute = 1.0;
  bool _isMuted = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;
  double _playbackRate = 1.0;
  BoxFit _videoFit = BoxFit.contain;

  /// The aspect ratio forced onto the picture, or null when it keeps its own
  /// shape (`_videoFit == BoxFit.contain`, the "Original" option). Forcing a
  /// ratio and picking a fit are mutually exclusive states: choosing one
  /// clears the other.
  double? _forcedAspectRatio;
  List<PlayerAudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = 0;

  /// Whether the preferred-audio ranking has already had its one chance at
  /// this file. Tracks arrive once, but a manual choice afterwards must not
  /// be undone by a later track update, so the ranking only fires on the
  /// first non-empty track list.
  bool _audioPreferenceApplied = false;

  bool _showAudioHud = false;
  String _audioHudText = '';
  Timer? _audioHudTimer;

  // Subtitle State
  List<SubtitleLanguageGroup> _subtitleGroups = [];

  /// Guards the panel's refresh button against a second press while the
  /// first search is still running.
  bool _isRefreshingSubtitles = false;
  List<PlayerEmbeddedSubtitle> _embeddedSubtitles = [];
  int? _selectedEmbeddedSubtitleIndex;
  SubtitleVariant? _currentSubtitleVariant;
  bool _isSubtitleEnabled = false;
  String? _currentSubtitlePath;
  List<SubCue> _currentCues = [];
  SubFormat _currentSubFormat = SubFormat.srt;
  double _subtitleDelayMs = 0;
  double _subtitleScale = 1.0;

  // Skip Segments State (IntroDB)
  List<MediaSkipSegment> _skipSegments = [];
  MediaSkipSegment? _activeSkipSegment;
  bool _showSkipButton = false;
  final Set<String> _dismissedSegmentKeys = {};

  // Episodes & Sources Side Panels State
  late StreamSource _currentSource;
  Video? _currentEpisode;
  late String _currentTitle;
  bool _showEpisodesPanel = false;

  // The URL actually opened by the local player, and whether it's a genuine
  // remote HTTP(S) URL a Cast receiver could fetch too. Torrent sources
  // resolve to this device's own local server (127.0.0.1), which a
  // Chromecast on the network cannot reach -- there is no fix for that
  // short of rearchitecting the torrent server to bind LAN-wide, so those
  // are excluded from casting rather than offering a button that always
  // fails for them.
  String? _resolvedStreamUrl;
  bool _isCastableSource = false;

  // What the stats popover reports about the stream being played. Set once
  // per stream in [_initStream] and read when the popover opens: the magnet
  // TorrServer is serving (only for a P2P torrent played through the local
  // engine), the debrid service behind a resolved link, and the kind token
  // the popover shows (`Torrent`, `Debrid`, `HLS`, `DASH`, `HTTPS`, `File`).
  String? _statsMagnet;
  String? _statsDebridService;
  String _statsKind = 'HTTPS';
  bool _statsIsLive = false;

  // Whether the app was already fullscreen (e.g. kiosk mode) before this
  // screen opened -- so leaving the player doesn't forcibly drop the user
  // out of a fullscreen they set up themselves, only the fullscreen the
  // player may have entered on its own.
  bool _wasFullscreenBeforeEntering = false;
  bool _showSourcesPanel = false;
  Video? _sourcesEpisode;
  String? _sourcesErrorMessage;
  final Map<String, List<StreamSource>> _cachedSourcesByEpisode = {};

  // ── Gesture state (volume / brightness swipes) ──


  // ── Auto-next episode state ──
  bool _autoNextShown = false;
  bool _autoNextDialogVisible = false;
  int _autoNextCountdown = 10;
  Timer? _autoNextTimer;

  // ── Accessibility / keyboard focus ──
  final FocusNode _focusNode = FocusNode();

  /// The centered play/pause button's node: where a remote's first arrow
  /// press lands once the controls are back on screen.
  final FocusNode _playPauseFocus = FocusNode(debugLabel: 'PlayerPlayPause');
  // Named stops for a remote's Up and Down (see PlayerTransport): without
  // them the neighbor in each direction is whatever is geometrically nearest.
  final FocusNode _seekFocus = FocusNode(debugLabel: 'PlayerSeekBar');
  final FocusNode _volumeFocus = FocusNode(debugLabel: 'PlayerVolume');

  @override
  void initState() {
    super.initState();
    // Re-focus after suspend/lock-screen. When the session comes back the
    // window's focus is gone and Flutter does not restore it, so every
    // keyboard shortcut (J/L/C/A/S/R/F/space) silently dies until the user
    // clicks. Observing the lifecycle re-arms them on resume.
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_keepControlsUpOnKey);
    _wasFullscreenBeforeEntering = WindowService.instance.isFullscreen;
    // The sleep timer pauses playback when its countdown ends. The service
    // outlives this screen -- it is a singleton the transport bar's button
    // also reads -- so the callback is cleared on dispose rather than left
    // pointing at a dead player.
    SleepTimerService.instance.onExpired = () {
      if (mounted) _player.pause();
    };
    _currentSource = widget.source;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;

    WakelockPlus.enable();

    PlayerSettings.changeNotifier.addListener(_onPlayerSettingsChanged);

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        // Straight to the coordinator, not via _onPlaybackUpdate: that only
        // runs on position ticks, and a paused video emits none, so the
        // notification kept showing Pause and its Play press was ignored.
        PlaybackCoordinator.setPlaying(playing);
        if (mounted) {
          setState(() => _isPlaying = playing);
        }
      }),
      _player.stream.position.listen((pos) {
        // time-pos only advances once a frame has been decoded, so the first
        // non-zero position is the end of the wait.
        if (_awaitingFirstFrame && pos > Duration.zero && mounted) {
          setState(_endFirstFrameWait);
        }
        _position = pos;
        _positionNotifier.value = pos;
        _onPlaybackTick(pos);
        _onPlaybackUpdate();
      }),
      _player.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
        }
      }),
      _player.stream.buffer.listen((buf) {
        _buffered = buf;
        _bufferNotifier.value = buf;
      }),
      _player.stream.bufferingPercentage.listen((percent) {
        if (_awaitingFirstFrame) _loadProgress.reachBuffering(percent / 100);
      }),
      _player.stream.buffering.listen((isBuffering) {
        if (_wasBuffering &&
            !isBuffering &&
            PlayerSettings.autoResyncOnStall.value) {
          try {
            if (PlayerSettings.hardwareAudioClock.value) {
              final np = _player.platform as dynamic;
              np.setProperty('video-sync', 'audio');
            }
          } catch (_) {
            // Not every libmpv build exposes 'video-sync'; the resync below
            // happens either way.
          }
        }
        _wasBuffering = isBuffering;
      }),
      _player.stream.tracks.listen((tracks) {
        _updateMediaTracks(tracks);
      }),
      _player.stream.track.listen((track) {
        if (!mounted) return;
        final aid = track.audio.id;
        final idx = int.tryParse(aid);
        if (idx != null && _selectedAudioTrackIndex != idx) {
          setState(() => _selectedAudioTrackIndex = idx);
        }
      }),
      _player.stream.error.listen((error) {
        _onControllerError(error);
      }),
      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _savePlaybackProgress();
          // "End of video" is armed, not counting down, so this is the only
          // thing that can fire it. `mounted` is true here by the guard
          // above; the flag is passed anyway so the service does not call
          // back into a screen that has since gone away.
          SleepTimerService.instance.notifyVideoEnded(mounted: mounted);
        }
      }),
    ]);

    _initStream();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A suspend/lock-screen cycle leaves the window focused but Flutter's
    // focus node detached, so every keyboard shortcut died until the next
    // click. Re-arming on resume is what "the shortcuts stopped working
    // after the screen locked" was.
    if (state == AppLifecycleState.resumed && mounted) {
      _focusNode.requestFocus();
    }
  }

  /// Starts waiting for the first decoded frame. Called inside the setState
  /// that clears [_isLoading], so the loading screen never blinks off between
  /// "opened" and "buffering".
  void _beginFirstFrameWait() {
    _awaitingFirstFrame = true;
    // A stream that never produces a position (a live feed that starts at
    // zero, a decoder that stalls) must not hold the logo over the picture
    // forever; after this long the player's own state is the better guide.
    _firstFrameTimeout?.cancel();
    _firstFrameTimeout = Timer(const Duration(seconds: 45), () {
      if (mounted && _awaitingFirstFrame) setState(_endFirstFrameWait);
    });
  }

  /// Ends the wait. Does not call setState: callers are already in one, or
  /// are tearing down.
  void _endFirstFrameWait() {
    if (_awaitingFirstFrame) _loadProgress.reach(1);
    _awaitingFirstFrame = false;
    _firstFrameTimeout?.cancel();
    _firstFrameTimeout = null;
    _preloadSub?.cancel();
    _preloadSub = null;
  }

  void _watchTorrentPreload(String magnet) {
    _preloadSub?.cancel();
    _preloadSub = TorrentStreamService().statsStream(magnet).listen(
      (stats) => _loadProgress.reachBuffering(stats.preloadPercent / 100),
      onError: (Object e) => debugPrint('[PlayerScreen] Preload stats failed: $e'),
    );
  }

  Future<void> _initStream() async {
    String? streamUrl;
    // Set only when TorrServer is serving, the one case with a preload to watch.
    String? preloadMagnet;
    _endFirstFrameWait();
    _loadProgress
      ..reset()
      ..reach(PlayerLoadProgress.started);

    // Ensure only one source plays app-wide: stop any other active source.
    final sourceId =
        'video:${widget.episode?.id ?? widget.detail?.id ?? widget.source.url}';
    PlaybackCoordinator.activate(
      sourceId,
      () {
        _player.pause();
      },
      kind: 'video',
      title: widget.title,
      subtitle: widget.episode?.title ?? widget.detail?.name,
      coverUrl: widget.backdropUrl,
      onTogglePlayPause: () {
        if (_player.state.playing) {
          _player.pause();
        } else {
          _player.play();
        }
      },
      onPlay: () => _player.play(),
      onPause: () => _player.pause(),
      onSeek: (position) => _player.seek(position),
      // See PlaybackCoordinator.activate's onShutdownDispose doc -- this
      // screen's own dispose() (which does the real, safe cleanup for the
      // ordinary close-this-screen path) never runs on a native window
      // close, so without this the media_kit Player's native decoder
      // threads and GPU surface stayed alive into process teardown.
      // Believed to be ROADMAP #12's "Unknown hard error" on close.
      onShutdownDispose: () => _player.dispose(),
    );

    debugPrint('[PlayerScreen] Initializing playback:');
    debugPrint('[PlayerScreen]   Title: $_currentTitle');
    debugPrint('[PlayerScreen]   Source Name: ${_currentSource.name}');
    debugPrint('[PlayerScreen]   Addon Name: ${_currentSource.addonName}');
    debugPrint('[PlayerScreen]   Source Title: ${_currentSource.title}');
    debugPrint('[PlayerScreen]   Raw URL: ${_currentSource.url}');

    try {
      final rawUrl = _currentSource.url;

      // Handle offline downloaded file playback directly
      if (rawUrl != null &&
          (File(rawUrl).existsSync() || _currentSource.name == 'Downloaded')) {
        debugPrint(
          '[PlayerScreen] Initializing offline local file playback: $rawUrl',
        );
        await PlayerSettings.applyPreOpenProperties(_player);
        // Volume before open: open() starts playback immediately, so applying
        // it afterwards let a muted or quietened video blast a moment of
        // full-volume audio first.
        _applyVolume(_isMuted ? 0.0 : _volume);
        _statsMagnet = null;
        _statsDebridService = null;
        _statsKind = 'File';
        _statsIsLive = false;
        _loadProgress.reach(PlayerLoadProgress.opened);
        await _player.open(Media(rawUrl), play: true);
        await PlayerSettings.applyPostOpenProperties(_player);
        _setSubtitleScale(_subtitleScale);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _beginFirstFrameWait();
          });
        }
        return;
      }

      final infoHash = _currentSource.infoHash;
      final isMagnetUrl = rawUrl != null && rawUrl.startsWith('magnet:');
      final isTorrent =
          (infoHash != null && infoHash.isNotEmpty) || isMagnetUrl;

      if (isTorrent) {
        String magnet;
        if (isMagnetUrl) {
          magnet = rawUrl;
        } else {
          magnet = 'magnet:?xt=urn:btih:$infoHash';
          if (_currentSource.sources != null) {
            for (final source in _currentSource.sources!) {
              if (source.startsWith('tracker:')) {
                final trackerUrl = source.replaceFirst('tracker:', '');
                magnet += '&tr=${Uri.encodeComponent(trackerUrl)}';
              }
            }
          }
        }

        final useDebrid = await DebridService().isDebridActiveForStreams();
        if (useDebrid) {
          final activeService = await DebridService().getSelectedService();
          if (!mounted) return;
          setState(() => _status = (l10n) => l10n.playerStatusUsing(activeService));
          _loadProgress.reach(PlayerLoadProgress.resolving);

          final seasonNum = _currentEpisode?.season;
          final episodeNum = _currentEpisode?.episode;

          final debridFiles = await DebridService().resolveMagnet(
            magnet: magnet,
            fileIndex: _currentSource.fileIdx,
            filename: _currentTitle,
            season: seasonNum,
            episode: episodeNum,
          );

          if (debridFiles.isEmpty || debridFiles.first.downloadUrl.isEmpty) {
            throw Exception('$activeService returned no direct stream links.');
          }

          streamUrl = debridFiles.first.downloadUrl;
          debugPrint('[PlayerScreen] Debrid resolved stream URL: $streamUrl');
          _statsMagnet = null;
          _statsDebridService = activeService;
        } else {
          if (!mounted) return;
          setState(() => _status = (l10n) => l10n.playerStatusGathering);
          _loadProgress.reach(PlayerLoadProgress.resolving);

          preloadMagnet = magnet;
          _statsMagnet = magnet;
          _statsDebridService = null;
          streamUrl = await TorrentStreamService().streamTorrent(
            magnet,
            fileIdx: _currentSource.fileIdx,
          );
        }
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        streamUrl = rawUrl;
        _statsMagnet = null;
        _statsDebridService = null;
      } else {
        throw Exception('No valid stream source found.');
      }

      if (streamUrl == null) throw Exception('Stream URL is null');

      _loadProgress.reach(PlayerLoadProgress.resolved);
      final sanitizedUrlStr = streamUrl.contains('::')
          ? streamUrl.replaceAll('::', '%3A%3A')
          : streamUrl;

      // Automatically resolve complete CDN headers (Referer, Origin, User-Agent)
      final playerHeaders = PlayerSettings.resolveStreamHeaders(
        sanitizedUrlStr,
        _currentSource.headers,
      );

      // Also merge any proxyHeaders from behaviorHints if present
      final proxyReqHeaders =
          _currentSource.behaviorHints?['proxyHeaders']?['request'];
      if (proxyReqHeaders is Map) {
        playerHeaders.addAll(Map<String, String>.from(proxyReqHeaders));
      }

      final cleanUri = Uri.parse(sanitizedUrlStr);
      debugPrint(
        '[PlayerScreen] Opening direct network stream URL: $cleanUri (headers: ${playerHeaders.keys})',
      );

      if (!mounted) return;
      final bufferingEpisode = _currentEpisode;
      final bufferingName = widget.detail?.name ?? _currentTitle;
      setState(
        () => _status = (l10n) => l10n.playerStatusBuffering(
          bufferingEpisode != null
              ? _episodeStatusLabel(l10n, bufferingEpisode)
              : bufferingName,
        ),
      );

      final lowerClean = sanitizedUrlStr.toLowerCase();
      final bool isLive =
          _currentSource.behaviorHints?['isLive'] == true ||
          _currentSource.addonName.toLowerCase() == 'iptv' ||
          _currentSource.name?.toLowerCase() == 'iptv' ||
          lowerClean.contains('/live/') ||
          lowerClean.contains('/hls/live');

      final bool isTorrentStream =
          isTorrent ||
          sanitizedUrlStr.contains(':8090') ||
          sanitizedUrlStr.contains('/stream?link=') ||
          sanitizedUrlStr.contains('/stream?');

      // The token the stats popover shows. A torrent name is not enough to
      // tell one apart: a debrid link and a TorrServer one both started as
      // a magnet, and only where the bytes come from now tells them apart.
      if (_statsMagnet != null) {
        _statsKind = 'Torrent';
      } else if (_statsDebridService != null) {
        _statsKind = 'Debrid';
      } else if (lowerClean.contains('.m3u8')) {
        _statsKind = 'HLS';
      } else if (lowerClean.contains('.mpd')) {
        _statsKind = 'DASH';
      } else {
        _statsKind = 'HTTPS';
      }
      _statsIsLive = isLive;

      await PlayerSettings.applyPreOpenProperties(
        _player,
        isLive: isLive,
        isTorrent: isTorrentStream,
      );

      // Set native MPV properties for referer and user-agent directly on the player for web streams
      if (!isTorrentStream) {
        try {
          final dynamic platform = _player.platform;
          if (platform != null) {
            final referer =
                playerHeaders['Referer'] ?? playerHeaders['referer'];
            if (referer != null && referer.isNotEmpty) {
              await platform.setProperty('referrer', referer);
            }
            final ua =
                playerHeaders['User-Agent'] ?? playerHeaders['user-agent'];
            if (ua != null && ua.isNotEmpty) {
              await platform.setProperty('user-agent', ua);
            }
          }
        } catch (e) {
          debugPrint('[PlayerScreen] Warning setting native header properties: $e');
        }
      }

      // Volume before open, for the same reason as the offline path above.
      _applyVolume(_isMuted ? 0.0 : _volume);

      _resolvedStreamUrl = cleanUri.toString();
      // Where the stream lives, not what produced it. The old test was
      // `!isTorrentStream`, which hid the Cast button on most of this app's
      // sources -- including the many torrent ones that resolve through a
      // debrid or a torrent server on another machine and are perfectly
      // fetchable by a receiver.
      _isCastableSource = CastService.canCastUrl(_resolvedStreamUrl);

      _loadProgress.reach(PlayerLoadProgress.opened);
      await _player.open(
        Media(
          cleanUri.toString(),
          httpHeaders: isTorrentStream ? null : playerHeaders,
          start: widget.initialPosition,
        ),
        play: true,
      );

      await PlayerSettings.applyPostOpenProperties(_player);

      _setSubtitleScale(_subtitleScale);

      debugPrint(
        '[PlayerScreen SUCCESS] Player opened media successfully for $streamUrl',
      );

      _updateMediaTracks(_player.state.tracks);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _beginFirstFrameWait();
      });
      // Only the engine knows how full its preload is; debrid and plain
      // HTTP streams are measured by the player's own buffering alone.
      if (preloadMagnet != null) _watchTorrentPreload(preloadMagnet);

      // Resume from history if previously watched
      if (widget.detail != null) {
        final historyItem = ContinueWatchingService.getHistoryProgress(
          widget.episode?.id ?? widget.detail!.id,
        );
        if (historyItem != null && historyItem.positionSeconds > 10) {
          await _player.seek(Duration(seconds: historyItem.positionSeconds));
        }
      }

      _player.play();
      _startHideControlsTimer();

      // Defer background services until after playback starts
      Future.microtask(() {
        if (!mounted) return;
        _fetchSkipSegments();
        _fetchInitialSubtitles();

        final detail = widget.detail;
        if (detail != null) {
          final isColl = detail.isCollection;
          final targetId = (isColl && _currentEpisode != null && _currentEpisode!.id.startsWith('tt'))
              ? _currentEpisode!.id
              : (detail.id.startsWith('tt') ? detail.id : (detail.tmdbId ?? detail.id));
          if (targetId.isNotEmpty) {
            final s = isColl ? null : _currentEpisode?.season;
            final e = isColl ? null : _currentEpisode?.episode;
            final initPos = widget.initialPosition?.inSeconds ?? 0;
            final dur = _player.state.duration.inSeconds;
            final progress = (dur > 0 ? (initPos / dur) * 100.0 : 0.0).clamp(
              0.0,
              100.0,
            );

            TraktService.instance.isAuthenticated().then((authed) {
              if (authed) {
                TraktService.instance.scrobbleStart(
                  targetId,
                  progress,
                  season: s,
                  episode: e,
                );
              }
            });
            SimklService.instance.isAuthenticated().then((authed) {
              if (authed) {
                SimklService.instance.scrobbleStart(
                  targetId,
                  progress,
                  season: s,
                  episode: e,
                );
              }
            });
          }
        }
      });

      _progressSaveTimer?.cancel();
      _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _savePlaybackProgress();
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[PlayerScreen ERROR] Failed to initialize stream URL: "$streamUrl"',
      );
      debugPrint('[PlayerScreen ERROR] Exception: $e');
      debugPrint('[PlayerScreen ERROR] StackTrace:\n$stackTrace');

      if (!mounted) return;

      // If we have an episode context (TV show), reopen the sources panel with error notice!
      if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
        setState(() {
          _isLoading = false;
          _showSourcesPanel = true;
          _sourcesEpisode = _currentEpisode;
          _sourcesErrorMessage = context.l10n.playerSourceFailed;
        });
        return;
      }

      String displayMessage = context.l10n.playerErrorGeneric('$e');
      if (e is PlatformException &&
          (e.message?.contains('invalid or unsupported media') ?? false)) {
        displayMessage = context.l10n.playerMediaOpenError;
      }

      setState(() {
        _isLoading = false;
        _status = (_) => displayMessage;
        _fatalError = displayMessage;
      });
    }
  }

  // Keep the universal play bar's progress/play-pause state in sync, and
  // detect end-of-credits for the auto-next dialog — covers every way
  // playback can toggle (in-player controls, the play bar itself,
  // auto-play), since this fires on every position update.
  void _onPlaybackUpdate() {
    final state = _player.state;
    PlaybackCoordinator.setProgress(state.position, state.duration);
    PlaybackCoordinator.setPlaying(state.playing);

    // ── Auto-next episode: detect end-of-credits ──
    if (widget.episode != null &&
        widget.onNextEpisode != null &&
        PlayerSettings.autoNextEnabled.value &&
        !_autoNextShown &&
        !_autoNextDialogVisible) {
      final pos = state.position;
      final dur = state.duration;
      if (dur.inSeconds > 15 &&
          pos.inSeconds >= dur.inSeconds - 15 &&
          pos.inSeconds > 0) {
        _autoNextShown = true;
        _showAutoNextDialog();
      }
    }
  }

  /// Shows a countdown dialog near the end of an episode offering to play the
  /// next episode. Auto-plays after the countdown unless the user cancels.
  void _showAutoNextDialog() {
    if (!mounted || _autoNextDialogVisible) return;
    _autoNextDialogVisible = true;
    _autoNextCountdown = 10;

    _autoNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _autoNextCountdown--;
      });
      if (_autoNextCountdown <= 0) {
        timer.cancel();
        _playNextEpisode();
      }
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF13151C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rem(AppRem.lg)),
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.accent,
                    size: context.rem(1.625),
                  ),
                  SizedBox(width: context.rem(0.625)),
                  Text(
                    context.l10n.upNext,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.upNextCountdown(_autoNextCountdown),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: context.rem(AppRem.sm)),
                  Text(
                    'S${widget.episode?.season ?? '?'}E${(widget.episode?.episode ?? 0) + 1}',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _autoNextTimer?.cancel();
                    setDialogState(() {});
                    Navigator.pop(dialogContext);
                    _autoNextDialogVisible = false;
                  },
                  child: Text(
                    context.l10n.libraryCancel,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                  ),
                  onPressed: () {
                    _autoNextTimer?.cancel();
                    Navigator.pop(dialogContext);
                    _autoNextDialogVisible = false;
                    _playNextEpisode();
                  },
                  child: Text(
                    context.l10n.playerPlayNext,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _playNextEpisode() {
    _autoNextTimer?.cancel();
    _autoNextDialogVisible = false;
    widget.onNextEpisode?.call();
  }

  /// The release name's single detected audio language, or null.
  ///
  /// Read off the source rather than the track list, for a file whose own
  /// tags say nothing. `multi` is excluded: it names no language, so it
  /// would only replace one unhelpful label with another.
  String? _singleSourceAudioLanguage() {
    try {
      final langs = widget.source
          .getAudioLanguages(mediaTitle: widget.title)
          .where((lang) => lang != 'multi')
          .toList();
      if (langs.length != 1) return null;
      final name = subtitleLanguageName(langs.single);
      return name.isEmpty ? null : name;
    } catch (_) {
      // Release-name sniffing must never break track listing.
      return null;
    }
  }

  void _updateMediaTracks(Tracks tracks) {
    if (!mounted) return;
    final audioList = tracks.audio;
    // The tracks that survive the filter below, kept whole so each can be
    // named from its own title.
    final keptAudio = <AudioTrack>[];
    for (final t in audioList) {
      if (t.id == 'no' || t.id == 'auto') continue;
      keptAudio.add(t);
    }

    // The same unique-naming the subtitle tracks get: a language, with a
    // region or a number only when two tracks would otherwise read the same.
    final audioNames = uniqueTrackLanguageNames(
      keptAudio.map((t) => t.language).toList(growable: false),
      keptAudio.map((t) => t.title).toList(growable: false),
    );

    final audioTracks = <PlayerAudioTrack>[];
    // What the release name says the file carries, for the common HTTP
    // case of one untagged track: mpv reports no language and often no
    // title either, so the chain below would fall through to the codec
    // and the row would read "AAC". A single detected language from the
    // source says more than a codec ever does. Only for one track and
    // only one detected language: anything else would be guessing which
    // of several tracks this row is.
    final sourceAudioHint = keptAudio.length == 1
        ? _singleSourceAudioLanguage()
        : null;
    for (var i = 0; i < keptAudio.length; i++) {
      final t = keptAudio[i];
      final cleaned = audioNames[i];
      // No "Track 3". That number came from the loop index, which counted
      // the `no` and `auto` entries this loop skips -- so a file with one
      // audio track reported it as the third.
      //
      // The fallback chain, in order of how much it tells the viewer: the
      // language, then the container's own title, then what the release
      // name detected for a single-track file, then the codec, then a
      // plain "Audio". A P2P or HTTP stream often tags no language at
      // all, and "Audio" alone is the least useful of the five -- while
      // the codec ("AAC") says something, it never answers which
      // language is being heard.
      final containerTitle = t.title?.trim().isNotEmpty == true
          ? t.title!.trim()
          : null;
      final codecLabel = t.codec?.trim().isNotEmpty == true
          ? t.codec!.trim().toUpperCase()
          : null;
      final title = cleaned.isNotEmpty
          ? cleaned
          : (containerTitle ??
                sourceAudioHint ??
                codecLabel ??
                'Audio');
      final idx = int.tryParse(t.id) ?? (i + 1);
      audioTracks.add(
        PlayerAudioTrack(
          index: idx,
          title: title,
          language: t.language,
          codec: t.codec,
          channels: int.tryParse(t.channels?.toString() ?? ''),
        ),
      );
    }

    final subList = tracks.subtitle;
    final embeddedSubs = <PlayerEmbeddedSubtitle>[];
    // The tracks that survive the filters below, kept whole so each can be
    // named from its own title.
    final keptSubs = <SubtitleTrack>[];
    for (final t in subList) {
      if (t.id == 'no' || t.id == 'auto') continue;
      // mpv's own tags, not languages: `spl` is a signs-only track and
      // `mon` marks subtitles matching the audio. Neither names something
      // anyone can choose deliberately, so both are dropped rather than
      // given a fallback title -- see subtitle_languages.dart.
      final tag = t.language?.trim().toLowerCase();
      if (tag == 'spl' || tag == 'mon') continue;
      // mpv's "auto" pseudo-track, arriving as the language or as the title.
      // It is not a language, and a row reading "Auto" cannot be chosen
      // deliberately -- there is nothing to choose it by.
      if (t.language?.trim().toLowerCase() == 'auto') continue;
      if (t.title?.trim().toLowerCase() == 'auto') continue;
      keptSubs.add(t);
    }

    // Two Spanish tracks both rendered as "Spanish", so the list showed the
    // same word twice and the choice between them was invisible. Each takes
    // a region from its own title where the title names one -- no numbers:
    // a handful of embedded tracks are told apart by trial, and numbering
    // them reads as two different kinds of thing next to the regions.
    final uniqueNames = uniqueTrackLanguageNames(
      keptSubs.map((t) => t.language).toList(growable: false),
      keptSubs.map((t) => t.title).toList(growable: false),
      numberDuplicates: false,
    );

    for (var i = 0; i < keptSubs.length; i++) {
      final t = keptSubs[i];
      final language = uniqueNames[i];
      // The language name leads, with [embeddedFallbackTitle] covering the
      // rest: the container's own title, then the codec as a short label,
      // then a bare number. A container title is written by whoever muxed
      // the file and is routinely technical noise -- "eng", "[Full] SDH",
      // "English (US) PGS" -- but for a track with no language it is the
      // only name there is. The two things a title can say that a language
      // name cannot, forced and hearing-impaired, are read off the title
      // separately and shown as their own badges, so nothing is lost by
      // preferring the name here.
      final title = language.isNotEmpty
          ? language
          : embeddedFallbackTitle(
              containerTitle: t.title,
              codec: t.codec,
              index: i + 1,
            );
      final idx = int.tryParse(t.id) ?? (i + 1);
      embeddedSubs.add(
        PlayerEmbeddedSubtitle(
          index: idx,
          title: title,
          // Normalized here rather than rendered raw: mpv's own track tags
          // (SPL, MON, ZHC, ZHT) are not languages, and a raw tag in the
          // picker read as noise. See subtitle_languages.dart for what each
          // means.
          language: language,
          // The codec decides how the track reaches the screen -- libass
          // for ASS, the overlay for text, mpv's OSD for bitmaps -- so it
          // rides along rather than being re-read later.
          codec: t.codec,
          // The container's own title, kept because it is the only place a
          // forced or hearing-impaired marker lives. `title` above is the
          // display name and prefers the language, so sniffing it meant
          // looking for "forced" in the word "Spanish".
          containerTitle: t.title,
        ),
      );
    }

    int activeIdx = _selectedAudioTrackIndex;
    if (activeIdx == 0 && audioTracks.isNotEmpty) {
      final activeAid = _player.state.track.audio.id;
      activeIdx = int.tryParse(activeAid) ?? audioTracks.first.index;
    }

    // The preferred-audio ranking gets one shot, on the first populated
    // track list. It is applied by index into the *file's* track order the
    // same way this loop built them, so the index it returns lines up with
    // `audioTracks`.
    if (!_audioPreferenceApplied && audioTracks.isNotEmpty) {
      _audioPreferenceApplied = true;
      final preferredIdx = preferredAudioTrackIndex(
        audioTracks.map((t) => t.language).toList(growable: false),
      );
      if (preferredIdx != null) {
        activeIdx = audioTracks[preferredIdx].index;
        _applyPreferredAudioTrack(activeIdx);
      }
    }

    setState(() {
      _audioTracks = audioTracks;
      _embeddedSubtitles = embeddedSubs;
      if (_selectedAudioTrackIndex == 0 && audioTracks.isNotEmpty) {
        _selectedAudioTrackIndex = activeIdx;
      }
    });
    _markDefaultSubtitleTracks();
  }

  /// Switches to the ranked track libmpv reported, mirroring what a tap in
  /// the audio menu does: the Dart-side call plus the raw `aid` property for
  /// builds that only honour one of them.
  void _applyPreferredAudioTrack(int index) {
    try {
      final matching = _player.state.tracks.audio.firstWhere(
        (t) => t.id == index.toString(),
        orElse: () => AudioTrack(index.toString(), null, null),
      );
      _player.setAudioTrack(matching);
      final np = _player.platform as dynamic;
      np.setProperty('aid', index.toString());
    } catch (_) {
      // Best effort, exactly as the manual path: a build that rejects one
      // of the two calls still gets the other, and the file's own default
      // is a correct fallback either way.
    }
  }

  /// Reads which embedded subtitle tracks the file itself marks default or
  /// forced. media_kit's track model does not carry either flag, so this asks
  /// libmpv for its own `track-list`. Best effort: without the flags the menu
  /// simply shows no Default badge, and auto-pick falls back to its other
  /// rules.
  Future<void> _markDefaultSubtitleTracks() async {
    try {
      final dynamic platform = _player.platform;
      if (platform == null) return;
      Future<String> read(String property) async =>
          (await platform.getProperty(property) as String?) ?? '';

      final count = int.tryParse(await read('track-list/count')) ?? 0;
      final defaults = <int>{};
      final forced = <int>{};
      for (var i = 0; i < count; i++) {
        if (await read('track-list/$i/type') != 'sub') continue;
        final id = int.tryParse(await read('track-list/$i/id'));
        if (id == null) continue;
        if (await read('track-list/$i/default') == 'yes') defaults.add(id);
        if (await read('track-list/$i/forced') == 'yes') forced.add(id);
      }
      if (!mounted || (defaults.isEmpty && forced.isEmpty)) return;
      setState(() {
        _embeddedSubtitles = [
          for (final track in _embeddedSubtitles)
            track.withFlags(
              isDefault: defaults.contains(track.index),
              isForcedTrack: forced.contains(track.index),
            ),
        ];
      });
    } catch (e) {
      debugPrint('[PlayerScreen] could not read subtitle track flags: $e');
    }
  }

  static String cleanMediaTitle(String raw) {
    var name = raw;
    name = name.replaceAll(
      RegExp(r'\.(mkv|mp4|avi|webm|ts|mov|m4v|srt|vtt)$', caseSensitive: false),
      '',
    );
    name = name.replaceAll(RegExp(r'[._]'), ' ');
    name = name.replaceAll(
      RegExp(
        r'\b(2160p|1080p|720p|480p|4k|uhd|ds4k|webrip|web-dl|bluray|brrip|h264|x264|h265|x265|hevc|10bit|ddp5\.1|dd5\.1|atmos|aac|ac3|dts|flac|remux|hdr|dv|proper|repack|hdtv)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Re-runs the online subtitle search, for the panel's refresh button.
  ///
  /// The player scrapes once when a stream opens; this is the manual retry
  /// for when that came back thin, or when a provider was briefly down. It
  /// replaces the groups rather than merging, so a provider that has since
  /// gone away does not leave its stale rows behind.
  Future<void> _refreshOnlineSubtitles() async {
    if (_isRefreshingSubtitles) return;
    setState(() => _isRefreshingSubtitles = true);
    try {
      await _fetchInitialSubtitles();
    } finally {
      if (mounted) setState(() => _isRefreshingSubtitles = false);
    }
  }

  Future<void> _fetchInitialSubtitles() async {
    try {
      int? searchYear;
      if (widget.detail?.year != null && widget.detail!.year!.isNotEmpty) {
        final yMatch = RegExp(
          r'\b(19\d\d|20\d\d)\b',
        ).firstMatch(widget.detail!.year!);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final rawName = widget.detail?.name ?? widget.title;
      if (searchYear == null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawName);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final isColl = widget.detail?.isCollection == true;
      final targetImdbId = (isColl && _currentEpisode != null && _currentEpisode!.id.startsWith('tt'))
          ? _currentEpisode!.id
          : widget.detail?.id;
      final targetName = (isColl && _currentEpisode != null && _currentEpisode!.title.isNotEmpty)
          ? _currentEpisode!.title
          : rawName;
      final targetYear = (isColl && _currentEpisode?.released != null && _currentEpisode!.released!.length >= 4)
          ? int.tryParse(_currentEpisode!.released!.substring(0, 4))
          : searchYear;
      final targetSeason = isColl ? null : _currentEpisode?.season;
      final targetEpisode = isColl ? null : _currentEpisode?.episode;
      final showName = cleanMediaTitle(targetName);

      debugPrint('[PlayerScreen] Scraping initial subtitles for "$showName" (year: $targetYear, imdb: $targetImdbId)...');

      final groups = await SubtitleService().fetchAllSubtitles(
        showName,
        imdbId: targetImdbId,
        season: targetSeason,
        episode: targetEpisode,
        year: targetYear,
      );
      debugPrint(
        '[PlayerScreen] Scraped ${groups.length} subtitle language groups with ${groups.fold(0, (s, g) => s + g.variants.length)} total variants',
      );
      if (mounted && groups.isNotEmpty) {
        setState(() => _subtitleGroups = groups);

        // Nothing is downloaded here. A search that turns up two hundred
        // languages is a list to choose from, not a decision to make on the
        // viewer's behalf: fetching one costs bandwidth, takes a moment, and
        // puts a subtitle on screen that nobody asked for. The list is
        // populated and the viewer picks. The only automatic subtitle is the
        // file's own embedded track, which is already on disk.
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading subtitles: $e');
    }
  }

  void _startHideControlsTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _isPlaying &&
          !_isHoveringUI &&
          _activeMenu == null &&
          !_showSubSyncBar &&
          !_showTextSyncOverlay) {
        setState(() => _showControls = false);
        _restoreScreenFocus();
      }
    });
  }

  /// The hidden controls stop taking focus (see [_controlsFocusable]), so a
  /// remote's focus that was on one of them falls back to the screen's own
  /// node, where the key handler lives.
  void _restoreScreenFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary is FocusScopeNode) {
        _focusNode.requestFocus();
      }
    });
  }

  /// Whether a menu, a side panel or a sync control is up. Back closes these
  /// before it does anything else; see [decideBackPress].
  bool get _hasBackableOverlay =>
      _activeMenu != null ||
      _showEpisodesPanel ||
      _showSourcesPanel ||
      _showSubSyncBar ||
      _showTextSyncOverlay;

  /// Set by the first of two Back presses, so a second within a couple of
  /// seconds leaves; cleared by [_exitArmTimer].
  bool _exitArmed = false;
  Timer? _exitArmTimer;

  BackAction get _backAction => decideBackPress(
        hasOverlayOpen: _hasBackableOverlay,
        controlsVisible: _showControls,
        exitArmed: _exitArmed,
        isTv: TvModeService.isTv.value,
        isLoading: _isLoading,
      );

  /// Acts on a Back press that is not "leave". Leaving is the route's own pop
  /// (see the [PopScope] in `build`), which only goes through when
  /// [_backAction] says [BackAction.exit].
  void _applyBackAction(BackAction action) {
    switch (action) {
      case BackAction.closeOverlay:
        setState(() {
          _activeMenu = null;
          _menuParent = null;
          _showEpisodesPanel = false;
          _showSourcesPanel = false;
          _sourcesErrorMessage = null;
          _showSubSyncBar = false;
          _showTextSyncOverlay = false;
        });
        _startHideControlsTimer();
        _restoreScreenFocus();
      case BackAction.hideControls:
        _hideTimer?.cancel();
        setState(() => _showControls = false);
        _restoreScreenFocus();
      case BackAction.armExit:
        setState(() => _exitArmed = true);
        _exitArmTimer?.cancel();
        _exitArmTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _exitArmed = false);
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.playerPressBackToExit),
              duration: const Duration(seconds: 2),
            ),
          );
      case BackAction.exit:
        Navigator.pop(context);
    }
  }

  /// Any key press keeps the bars up another few seconds.
  ///
  /// Keys the controls handle themselves -- Left/Right on the seek bar, Up/Down
  /// on the volume, the hops between rows -- never reach the screen's own key
  /// handler, which is where the hide timer used to be pushed back. Moving
  /// along the bottom row with the remote then lost the bars four seconds in,
  /// mid-press. Listening at the keyboard, ahead of the focus tree, covers
  /// every key whoever ends up handling it. Returns false: it only watches.
  bool _keepControlsUpOnKey(KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        mounted &&
        _showControls &&
        _activeMenu == null) {
      _startHideControlsTimer();
    }
    return false;
  }

  /// Brings the controls back and keeps them up a while longer. Any key a
  /// remote sends means someone is watching, and a remote has no pointer to
  /// do it the way [_handlePointerActivity] does.
  void _revealControls() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  /// Whether the three overlays (top bar, center buttons, transport bar) can
  /// take focus. They are hidden with opacity and `IgnorePointer`, neither of
  /// which stops a remote's focus landing on them, which is how a D-pad ended
  /// up moving invisibly between controls nobody could see.
  bool get _controlsFocusable => _showControls || _isLoading || _activeMenu != null;

  void _handlePointerActivity() {
    if (_isLoading) return;
    if (!_showControls) setState(() => _showControls = true);

    final now = DateTime.now();
    if (_lastPointerTimerReset == null ||
        now.difference(_lastPointerTimerReset!) >=
            const Duration(milliseconds: 250)) {
      _lastPointerTimerReset = now;
      _startHideControlsTimer();
    }
  }

  // ── Gesture handlers: vertical swipe left = volume, right = brightness ──


  /// The language of the audio track currently playing, which is what the
  /// CC button matches a subtitle against: subtitles are there to put in
  /// writing what is being said, so the written words should be the spoken
  /// ones. Null before the media reports its tracks, or when the track
  /// carries no language tag.
  String? get _selectedAudioLanguage {
    if (_audioTracks.isEmpty) return null;
    final match = _audioTracks
        .where((t) => t.index == _selectedAudioTrackIndex)
        .firstOrNull;
    return (match ?? _audioTracks.first).language;
  }

  /// Closes whichever menu is open: what the scrim, a sheet's close button and
  /// its swipe all call.
  void _closeActiveMenu() {
    if (!mounted || _activeMenu == null) return;
    setState(() {
      _activeMenu = null;
      _menuParent = null;
    });
    _startHideControlsTimer();
  }

  void _toggleMenu(String menuName) {
    setState(() {
      if (_activeMenu == menuName) {
        _activeMenu = null;
        _menuParent = null;
        _startHideControlsTimer();
      } else {
        _activeMenu = menuName;
        // Opened straight from the transport bar, so there is nothing
        // behind it: a stale parent here would show a back arrow leading
        // to a panel the user never came from.
        _menuParent = null;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _hideTimer?.cancel();
      }
    });
  }

  Future<void> _selectEmbeddedSubtitle(PlayerEmbeddedSubtitle embedded) async {
    setState(() {
      _selectedEmbeddedSubtitleIndex = embedded.index;
      _currentSubtitleVariant = SubtitleVariant(
        providerName: 'Embedded',
        language: embedded.language ?? 'Embedded',
        title: embedded.title,
        downloadUrl: '',
        format: 'ass',
      );
      _isSubtitleEnabled = true;
      _currentSubtitlePath = null;
      _currentCues = [];
    });

    // The state is set *before* the track is selected.
    //
    // How the track reaches the screen depends on what it is. Only ASS goes
    // through libass: its tags are rendering instructions, so the overlay
    // would show raw markup beside libass's styled line. Every other text
    // track is drawn from the text mpv emits -- which is what older releases
    // did, and why this worked there -- with mpv's own rendering off so the
    // line is not drawn twice. A bitmap track emits no text at all, so it
    // renders through mpv's OSD with visibility left on.
    //
    // The selection itself is verified, not assumed: the player's property
    // set never throws -- it only logs -- so a rejected track id used to
    // fail silently, with the menu showing selected and mpv on `no`.
    final selected = await _selectEmbeddedTrack(embedded);
    if (selected) {
      if (embedded.needsLibass) {
        PlayerSettings.embeddedSubtitleActive.value = true;
        await _enableLibassForEmbedded();
      } else {
        PlayerSettings.embeddedSubtitleActive.value = false;
        if (embedded.isImageSubtitle) {
          final dynamic platform = _player.platform;
          try {
            await platform?.setProperty('sub-visibility', 'yes');
          } catch (e) {
            debugPrint('[PlayerScreen] could not show OSD subtitles: $e');
          }
        } else {
          await PlayerSettings.applySubtitleStyling(_player);
        }
      }
    }
    _setSubtitleScale(_subtitleScale);
    _logSubtitleDiagnostics(embedded);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected
                ? context.l10n.playerSubSwitchedEmbedded(embedded.title)
                : context.l10n.playerSubLoadFailed(embedded.title),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Selects the embedded track in mpv and reports whether it stuck.
  ///
  /// Reads `sid` back because the property set below it never throws: a
  /// rejected id fails silently, and without this the menu claimed a track
  /// mpv had never heard of. One retry, for the transient case; a second
  /// miss is logged by the diagnostics call that follows and left alone.
  Future<bool> _selectEmbeddedTrack(PlayerEmbeddedSubtitle embedded) async {
    final wanted = embedded.index.toString();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _player.setSubtitleTrack(
          SubtitleTrack(
            wanted,
            embedded.title,
            embedded.language,
          ),
        );
      } catch (e) {
        debugPrint('[PlayerScreen] could not select embedded subtitle: $e');
        return false;
      }
      try {
        final dynamic platform = _player.platform;
        final sid = await platform?.getProperty('sid') as String?;
        if (sid == wanted) return true;
        debugPrint(
          '[PlayerScreen] sid stuck at $sid, wanted $wanted '
          '(attempt $attempt)',
        );
      } catch (e) {
        debugPrint('[PlayerScreen] could not read sid back: $e');
        return true;
      }
    }
    return false;
  }

  /// Logs what mpv actually reports about the subtitle state, after an
  /// embedded track has been selected.
  ///
  /// This exists because fixes have been made to this path by reading the
  /// code, and the bug survived them -- so the guesswork stops here. One run
  /// separates the causes:
  ///
  ///  * `sid` is `no` -- the selection never reached mpv. The property set
  ///    never throws, so without the read-back in [_selectEmbeddedTrack]
  ///    this failed silently.
  ///  * `sid` is right but nothing renders -- the roster below says what the
  ///    track is (codec, language, title) and which renderer owns it, so a
  ///    wrong engine choice shows itself instead of being reasoned about.
  ///
  /// `sub-text` being empty proves nothing on its own: at any instant there
  /// may simply be no dialogue, and a libass track never emits text anyway.
  ///
  /// Deliberately read-only. It changes no property and no state, so it can
  /// be removed without touching anything else.
  Future<void> _logSubtitleDiagnostics(PlayerEmbeddedSubtitle embedded) async {
    try {
      final dynamic platform = _player.platform;
      if (platform == null) return;
      Future<String> read(String property) async =>
          (await platform.getProperty(property) as String?) ?? '<null>';

      final sid = await read('sid');
      final visibility = await read('sub-visibility');
      final ass = await read('sub-ass');
      final text = await read('sub-text');
      // Every subtitle entry mpv knows, so an id-mapping mismatch shows
      // itself: the menu's index must be a track-list id, and a flat
      // `track-list/N/selected` read cannot say that -- N is a position in
      // the interleaved video/audio/subtitle array, not an id.
      final roster = <String>[];
      final count = int.tryParse(await read('track-list/count')) ?? 0;
      for (var i = 0; i < count; i++) {
        if (await read('track-list/$i/type') != 'sub') continue;
        roster.add(
          '[${await read('track-list/$i/id')}'
          ':${await read('track-list/$i/lang')}'
          ':${await read('track-list/$i/codec')}'
          ':${await read('track-list/$i/title')}'
          ':${await read('track-list/$i/selected')}]',
        );
      }

      debugPrint(
        '[SubDiag] selected embedded #${embedded.index} '
        '(${embedded.language ?? embedded.title}) '
        'codec=${embedded.codec} | '
        'sid=$sid sub-visibility=$visibility sub-ass=$ass '
        'sub-text=${text.isEmpty ? '<empty>' : '"$text"'} | '
        'roster=${roster.join(' ')}',
      );
    } catch (e) {
      debugPrint('[SubDiag] could not read subtitle state: $e');
    }
  }

  /// Turns mpv's own subtitle rendering on, for an embedded ASS track.
  ///
  /// Only ASS takes this path (see [_selectEmbeddedSubtitle]): its tags need
  /// libass, while text tracks use the overlay and bitmap tracks use the OSD.
  /// The state is set first, because [PlayerSettings.applySubtitleStyling]
  /// reads it rather than taking a flag -- see
  /// [PlayerSettings.embeddedSubtitleActive] for why.
  Future<void> _enableLibassForEmbedded() async {
    try {
      PlayerSettings.embeddedSubtitleActive.value = true;
      final dynamic platform = _player.platform;
      if (platform == null) return;
      await platform.setProperty('sub-visibility', 'yes');
      await platform.setProperty('sub-ass', 'yes');
      await PlayerSettings.applySubtitleStyling(_player);
    } catch (e) {
      debugPrint('[PlayerScreen] could not enable libass for embedded subs: $e');
    }
  }

  void _disableSubtitles() {
    setState(() {
      _isSubtitleEnabled = false;
      _currentSubtitleVariant = null;
      _selectedEmbeddedSubtitleIndex = null;
      _currentSubtitlePath = null;
      _currentCues = [];
    });
    // Cleared here, so an appearance change after this does not turn libass
    // back on for a track that is no longer selected.
    PlayerSettings.embeddedSubtitleActive.value = false;
    _player.setSubtitleTrack(SubtitleTrack.no());
  }

  /// Turns subtitles on or off, for the `C` shortcut.
  ///
  /// On is not a bare "show something": it matches the language you are
  /// hearing. A viewer whose audio is English wants English subtitles, and
  /// one who switched to a dub wants that dub's subtitles -- the language
  /// they are listening to is the one they can be assumed to read.
  ///
  /// There is no "original" flag to read: mpv's track list carries the
  /// container's `default` marker, which plenty of releases set on the dub,
  /// and nothing else that claims which track the film was made in. So the
  /// selected audio track is the answer, and [_pickBestSubtitle]'s own
  /// fallbacks cover a file whose tracks carry no language tag at all.
  void _toggleSubtitleShortcut() {
    if (_isSubtitleEnabled) {
      _disableSubtitles();
      return;
    }

    final preferred = _selectedAudioLanguage;
    final embedded = SubtitleAutoPick.embedded(
      _embeddedSubtitles,
      audioLanguage: preferred,
    );
    if (embedded != null) {
      _selectEmbeddedSubtitle(embedded);
      return;
    }

    final variant = SubtitleAutoPick.variant(
      _subtitleGroups,
      audioLanguage: preferred,
    );
    if (variant != null) {
      _loadSubtitle(variant);
      return;
    }

    // Nothing to turn on -- say so rather than leaving the key inert.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playerNoSubtitlesForStream),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Turns on the best subtitle there is -- the audio language's embedded
  /// track, then a matching online one -- whatever is on now. It is the
  /// panel's "Auto" pill: a choice, so pressing it twice never switches
  /// subtitles off. (The `C` key is the toggle; see
  /// [_toggleSubtitleShortcut].)
  void _pickBestSubtitle() {
    final auto = SubtitleAutoPick.embedded(
      _embeddedSubtitles,
      audioLanguage: _selectedAudioLanguage,
    );
    if (auto != null) {
      _selectEmbeddedSubtitle(auto);
      return;
    }

    final variant = SubtitleAutoPick.variant(
      _subtitleGroups,
      audioLanguage: _selectedAudioLanguage,
    );
    if (variant != null) {
      _loadSubtitle(variant);
      return;
    }

    // Genuinely nothing to turn on. Say so, rather than leaving a button
    // that looks broken.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playerNoSubtitlesForStream),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadSubtitle(SubtitleVariant variant) async {
    // setState, not bare assignments: the subtitle panel stays open after a
    // pick (a viewer is often just trying tracks), and it shows what is
    // selected from these fields.
    setState(() {
      _currentSubtitleVariant = variant;
      _selectedEmbeddedSubtitleIndex = null;
      _isSubtitleEnabled = true;
    });
    // An online subtitle is a downloaded file drawn by the Flutter overlay,
    // not by libass. Leaving the embedded state set would keep libass on for
    // a track that is no longer selected.
    PlayerSettings.embeddedSubtitleActive.value = false;
    _player.setSubtitleTrack(SubtitleTrack.no());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playerSubDownloading(variant.language)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final path = await SubtitleService().downloadSubtitle(variant);
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.playerSubDownloadFailed)),
        );
      }
      return;
    }

    // The player may have been disposed (user backed out) while the
    // download above was in flight -- don't touch the native player or
    // widget state after that.
    if (!mounted) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final content = SubtitleParser.decodeBytesWithFallback(bytes);
        final parseResult = SubtitleParser.parse(content);
        _currentCues = parseResult.cues;
        _currentSubFormat = parseResult.format;
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Subtitle cues parse error: $e');
    }

    _currentSubtitlePath = path;
    final resolvedUri = _resolveSubtitleUri(path);
    _player.setSubtitleTrack(
      SubtitleTrack.uri(resolvedUri, title: variant.language),
    );
    _setSubtitleScale(_subtitleScale);
    PlayerSettings.applySubtitleStyling(_player);

    if (_subtitleDelayMs != 0) {
      await _applyLiveDelay(_subtitleDelayMs / 1000.0);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.playerSubLoaded(variant.language, _currentCues.length),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _resolveSubtitleUri(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    try {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        final canonicalPath = file.resolveSymbolicLinksSync();
        return Uri.file(canonicalPath).toString();
      }
    } catch (_) {
      // resolveSymbolicLinksSync throws for anything that is not a real file,
      // which is how a URL falls through to being treated as one.
    }

    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null &&
        uri.hasScheme &&
        !(Platform.isWindows &&
            RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(pathOrUrl))) {
      return pathOrUrl;
    }
    return Uri.file(pathOrUrl).toString();
  }

  void _setSubtitleScale(double scale) {
    if (!mounted) return;
    final clamped = scale.clamp(0.5, 3.0);
    setState(() => _subtitleScale = clamped);
    PlayerSettings.setSubScale(clamped, player: _player);
  }

  Future<void> _applyLiveDelay(double delaySec) async {
    _subtitleDelayMs = delaySec * 1000.0;
    final np = _player.platform as dynamic;
    try {
      np.setProperty('sub-delay', delaySec.toString());
    } catch (e) {
      debugPrint('[PlayerScreen] applyLiveDelay error: $e');
    }
  }

  Future<void> _saveTextSyncedCues(
    List<SubCue> syncedCues,
    double offsetSec,
  ) async {
    _currentCues = syncedCues;
    _subtitleDelayMs =
        0.0; // Reset live delay since timestamps are now permanently baked into cues
    if (_currentSubtitlePath != null) {
      final content = _currentSubFormat == SubFormat.vtt
          ? SubtitleParser.toVtt(syncedCues)
          : SubtitleParser.toSrt(syncedCues);
      final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
      final cleanBase = _currentSubtitlePath!.replaceAll(
        RegExp(r'(_delayed.*|_synced.*)?\.(srt|vtt)$', caseSensitive: false),
        '',
      );
      final newPath =
          '${cleanBase}_synced_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(newPath).writeAsString(content, flush: true);
      _currentSubtitlePath = newPath;
      final resolvedUri = _resolveSubtitleUri(newPath);
      _player.setSubtitleTrack(SubtitleTrack.uri(resolvedUri));
      _setSubtitleScale(_subtitleScale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.playerSubSyncSaved),
          ),
        );
      }
    }
  }

  void _onControllerError(dynamic err) {
    if (!mounted) return;
    final errorMsg = err.toString();
    final lower = errorMsg.toLowerCase();

    // 1. Subtitle track loading errors - non-fatal, notify user briefly without interrupting playback
    if (lower.contains('can not open external file') ||
        lower.contains('subtitle') ||
        lower.contains('sub-add') ||
        lower.contains('.srt') ||
        lower.contains('.vtt') ||
        lower.contains('.ass')) {
      debugPrint('[PlayerScreen] Ignored non-fatal subtitle warning: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.playerSubLoadFailed(errorMsg)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 2. Ignore non-fatal MPV/FFmpeg network and demuxer warnings (e.g. "tcp: ffurl_read returned 0xffffff99")
    if (PlayerSettings.isNonFatalError(err)) {
      debugPrint('[PlayerScreen] Ignored non-fatal player warning: $errorMsg');
      return;
    }

    // 3. Active playback protection:
    // Only routine non-fatal hiccups during ongoing playback (where media has actively loaded and progressed)
    // should be suppressed. Startup errors where media has not loaded must trigger error handling.
    final bool hasActivelyProgressed = _duration > Duration.zero &&
        (_position > Duration.zero || _player.state.position > Duration.zero) &&
        (_isPlaying || _player.state.playing);

    final bool isFatalOpenFailure = lower.contains('failed to open') ||
        lower.contains('cannot open') ||
        lower.contains('could not open') ||
        lower.contains('failed to recognize file format') ||
        lower.contains('unsupported file format') ||
        lower.contains('server returned 4') ||
        lower.contains('server returned 5') ||
        lower.contains('failed to resolve') ||
        lower.contains('no such host');

    if (hasActivelyProgressed && !isFatalOpenFailure) {
      debugPrint('[PlayerScreen WARNING] Ignored player warning during active playback: $errorMsg');
      return;
    }

    // 4. Critical error on dead stream
    debugPrint('[PlayerScreen ERROR] Critical player error on dead stream: $errorMsg');

    if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
      setState(() {
        _endFirstFrameWait();
        _isLoading = false;
        _showSourcesPanel = true;
        _sourcesEpisode = _currentEpisode;
        _sourcesErrorMessage =
            'Playback error: $errorMsg. Please select another source below.';
      });
      return;
    }

    setState(() {
      _endFirstFrameWait();
      _isLoading = false;
      final message = context.l10n.playerPlaybackError(errorMsg);
      _status = (_) => message;
      _fatalError = message;
    });
  }

  /// Re-runs stream setup after a failure, so a transient error (a dead CDN
  /// link, a stalled torrent handshake) does not require leaving the player.
  Future<void> _retryPlayback() async {
    if (!mounted) return;
    setState(() {
      _fatalError = null;
      _isLoading = true;
      _status = (l10n) => l10n.playerStatusRetrying;
    });
    await _initStream();
  }

  Widget _buildFatalErrorView() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(context.rem(AppRem.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: context.rem(2.75),
            ),
            SizedBox(height: context.rem(AppRem.md)),
            Text(
              context.l10n.playerThisSourceFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.lead,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.rem(0.625)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.rem(28.75)),
              child: Text(
                _fatalError ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: AppType.small),
              ),
            ),
            SizedBox(height: context.rem(AppRem.lg)),
            Wrap(
              spacing: context.rem(AppRem.ms),
              runSpacing: context.rem(AppRem.ms),
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _retryPlayback,
                  icon: Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconSm)),
                  label: Text(context.l10n.playerTryAgain),
                  style: FilledButton.styleFrom(
                    backgroundColor: PlayerTheme.accent,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_rounded, size: context.rem(AppRem.iconSm)),
                  label: Text(context.l10n.playerPickAnotherSource),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyVolume(double vol, {bool showHud = false}) {
    if (!mounted) return;
    final clamped = ((vol * 100).round() / 100.0).clamp(
      0.0,
      PlayerVolumeControl.maxVolume,
    );
    setState(() {
      _volume = clamped;
      _isMuted = clamped == 0;
      if (showHud) _showVolumeHud = true;
    });

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }

    _player.setVolume(clamped * 100.0);
  }

  void _toggleMute({bool showHud = false}) {
    if (_volume > 0 && !_isMuted) {
      _lastVolumeBeforeMute = _volume;
      setState(() {
        _isMuted = true;
        if (showHud) _showVolumeHud = true;
      });
      _player.setVolume(0.0);
    } else {
      final restore = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0;
      setState(() {
        _volume = restore;
        _isMuted = false;
        if (showHud) _showVolumeHud = true;
      });
      _player.setVolume(restore * 100.0);
    }

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _startHideControlsTimer();
  }

  void _toggleFullscreen() {
    WindowService.instance.toggleFullscreen();
    _startHideControlsTimer();
  }

  void _seekRelative(Duration offset) {
    final cur = _player.state.position;
    final dur = _player.state.duration;
    final target = cur + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    _player.seek(clamped);
    _flashSeek(offset.inSeconds);
    _startHideControlsTimer();
  }

  /// Which menu, if any, the open one was stepped into from. Only
  /// 'settings' today: a sub-menu opened straight from the transport bar
  /// has nothing to go back to, and offering an arrow there would promise a
  /// screen that does not exist.
  String? _menuParent;

  /// The back action for a sub-menu, or null when it was not stepped into.
  VoidCallback? get _backToSettings => _menuParent == 'settings'
      ? () => setState(() {
          _activeMenu = 'settings';
          _menuParent = null;
        })
      : null;

  SeekFlash? _seekFlash;
  int _seekFlashSeq = 0;
  Timer? _seekFlashTimer;

  /// Shows the step that was just taken, on the side it moved the video.
  /// Every fixed-step seek routes through [_seekRelative], so the double-tap
  /// zones, the centered ±10s buttons, the ±30s buttons and the arrow keys
  /// all land here -- there is no second path that could animate
  /// differently, or not at all.
  void _flashSeek(int seconds) {
    if (seconds == 0) return;
    // Keep counting while the taps keep coming the same way: three quick
    // +10s taps should read "30 seconds", which is what the viewer is
    // actually doing, rather than flashing "10 seconds" three times.
    setState(() {
      _seekFlash = SeekFlash.next(_seekFlash, seconds, id: ++_seekFlashSeq);
    });
    _seekFlashTimer?.cancel();
    _seekFlashTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _seekFlash = null);
    });
  }

  void _toggleEpisodesPanel() {
    setState(() {
      _showEpisodesPanel = !_showEpisodesPanel;
      if (_showEpisodesPanel) {
        _showSourcesPanel = false;
        _activeMenu = null;
        _menuParent = null;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _showControls = true;
      }
    });
  }

  void _onEpisodeChosen(Video episode) {
    setState(() {
      _showEpisodesPanel = false;
      _showSourcesPanel = true;
      _sourcesEpisode = episode;
      _sourcesErrorMessage = null;
      _activeMenu = null;
      _menuParent = null;
      _showControls = true;
    });
  }

  void _onBackToEpisodes() {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = true;
      _sourcesErrorMessage = null;
    });
  }

  void _playNewSource(StreamSource newSource, Video episode) {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = false;
      _sourcesErrorMessage = null;
    });
    _switchStream(newSource, episode);
  }

  void _switchStream(StreamSource newSource, Video newEpisode) async {
    _progressSaveTimer?.cancel();
    _savePlaybackProgress();

    final prevVariant = _currentSubtitleVariant;
    final wasSubEnabled = _isSubtitleEnabled;

    setState(() {
      _currentSource = newSource;
      _currentEpisode = newEpisode;
      final showName = widget.detail?.name ?? widget.title;
      final epNum = newEpisode.episode ?? 1;
      final sNum = newEpisode.season ?? 1;
      _currentTitle = '$showName - S${sNum}E$epNum ${newEpisode.title}';
      _isLoading = true;
      _status = (l10n) => l10n.playerStatusBuffering(
        _episodeStatusLabel(l10n, newEpisode),
      );
      _showEpisodesPanel = false;
      _showSourcesPanel = false;
      _activeMenu = null;
      _menuParent = null;
      _showSubSyncBar = false;
      _showTextSyncOverlay = false;
      _showSkipButton = false;
      _activeSkipSegment = null;
      _skipSegments = [];
      _subtitleGroups = [];
      _currentSubtitlePath = null;
      _currentCues = [];
      _currentSubtitleVariant = prevVariant;
      _isSubtitleEnabled = wasSubEnabled;
    });

    // Cleanup previous torrent engine if was P2P
    TorrentStreamService().cleanup();

    _initStream();
  }

  void _fetchSkipSegments() async {
    try {
      final detail = widget.detail;
      final showName = widget.detail?.name ?? widget.title;
      final skipData = await SkipSegmentsService.instance.fetchSkipSegments(
        tmdbId: detail?.tmdbId,
        imdbId: (detail != null && detail.id.startsWith('tt'))
            ? detail.id
            : null,
        title: showName,
        year: int.tryParse(detail?.year ?? ''),
        type: detail?.type ?? (_currentEpisode != null ? 'tv' : 'movie'),
        season: _currentEpisode?.season,
        episode: _currentEpisode?.episode,
        durationMs: _player.state.duration.inMilliseconds,
      );

      if (skipData != null && mounted) {
        setState(() {
          _skipSegments = skipData.segments;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading skip segments: $e');
    }
  }

  void _onPlaybackTick(Duration pos) {
    if (_skipSegments.isEmpty) return;

    final dur = _player.state.duration;

    MediaSkipSegment? matched;
    for (final seg in _skipSegments) {
      if (seg.contains(pos, dur)) {
        matched = seg;
        break;
      }
    }

    if (matched != null) {
      if (!_dismissedSegmentKeys.contains(matched.uniqueKey)) {
        if (_activeSkipSegment?.uniqueKey != matched.uniqueKey) {
          setState(() {
            _activeSkipSegment = matched;
            _showSkipButton = true;
          });
        }
      }
    } else {
      if (_activeSkipSegment != null) {
        setState(() {
          _activeSkipSegment = null;
          _showSkipButton = false;
        });
      }
    }
  }

  void _handleSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    final target = seg.endMs != null
        ? Duration(milliseconds: seg.endMs!)
        : _player.state.duration;

    _player.seek(target + const Duration(milliseconds: 300));

    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _handleDismissSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _savePlaybackProgress() {
    if (widget.detail == null) return;

    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur <= 0) return;

    ContinueWatchingService.saveProgress(
      detail: widget.detail!,
      episode: _currentEpisode,
      source: _currentSource,
      positionSeconds: pos,
      totalDurationSeconds: dur,
    );
  }

  @override
  void dispose() {
    // The timer keeps running across screens by design -- a viewer who sets
    // it and backs out of the player still wants the pause -- but its pause
    // callback pointed at this screen's player, so it is detached here.
    SleepTimerService.instance.onExpired = null;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _progressSaveTimer?.cancel();
    _volumeHudTimer?.cancel();
    _audioHudTimer?.cancel();
    _exitArmTimer?.cancel();
    _savePlaybackProgress();
    WakelockPlus.disable();
    _hideTimer?.cancel();
    _autoNextTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_keepControlsUpOnKey);
    _focusNode.dispose();
    _playPauseFocus.dispose();
    _seekFocus.dispose();
    _volumeFocus.dispose();
    PlaybackCoordinator.release(
      'video:${widget.episode?.id ?? widget.detail?.id ?? widget.source.url}',
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    PlayerSettings.changeNotifier.removeListener(_onPlayerSettingsChanged);
    _positionNotifier.dispose();
    _bufferNotifier.dispose();
    _player.dispose();
    _endFirstFrameWait();
    _loadProgress.dispose();
    TorrentStreamService().cleanup();
    if (!_wasFullscreenBeforeEntering && WindowService.instance.isFullscreen) {
      WindowService.instance.exitFullscreen();
    }
    _seekFlashTimer?.cancel();
    super.dispose();
  }

  void _onPlayerSettingsChanged() {
    PlayerSettings.applyToPlayer(_player);
  }

  DateTime? _lastScreenTapTime;

  void _handleScreenTap(TapDownDetails details) {
    if (_showTextSyncOverlay || _activeMenu != null) return;
    final now = DateTime.now();
    if (_lastScreenTapTime != null &&
        now.difference(_lastScreenTapTime!) <
            const Duration(milliseconds: 280)) {
      _lastScreenTapTime = null;
      // Left/right thirds seek ±10s (YouTube-style), touch only -- mouse
      // users already have the center ±10s buttons and don't need a
      // double-click gesture for the same thing. The middle third keeps the
      // existing double-tap-to-fullscreen behavior on every platform.
      if (!WindowService.instance.isDesktop) {
        final width = MediaQuery.sizeOf(context).width;
        final dx = details.localPosition.dx;
        if (dx < width / 3) {
          _seekRelative(const Duration(seconds: -10));
          return;
        } else if (dx > width * 2 / 3) {
          _seekRelative(const Duration(seconds: 10));
          return;
        }
      }
      WindowService.instance.toggleFullscreen();
    } else {
      _lastScreenTapTime = now;
      // A single tap only reveals/hides the controls overlay. It used to
      // also toggle play/pause, but this handler can't tell a lone tap from
      // the first half of a double-tap until the second one does or
      // doesn't arrive -- so every double-tap-to-fullscreen also fired an
      // unwanted play/pause blip from its first tap, and an accidental tap
      // (repositioning the device, wiping the screen) silently paused
      // playback. The dedicated play/pause button is the one deliberate way
      // to do that now.
      setState(() => _showControls = !_showControls);
      if (_showControls) _startHideControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back peels one layer at a time (see [decideBackPress]): the route only
      // pops once there is nothing left to close.
      canPop: _backAction == BackAction.exit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _applyBackAction(_backAction);
          return;
        }
        if (!_wasFullscreenBeforeEntering && WindowService.instance.isFullscreen) {
          WindowService.instance.exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            // Never intercept key events when typing or searching in text inputs or overlay
            if (_showTextSyncOverlay) {
              return KeyEventResult.ignored;
            }
            final primaryFocus = FocusManager.instance.primaryFocus;
            if (primaryFocus != null && primaryFocus.context != null) {
              final focusedWidget = primaryFocus.context!.widget;
              if (focusedWidget is EditableText) {
                return KeyEventResult.ignored;
              }
            }

            if (event is KeyDownEvent) {
              // On a real TV the 4 arrows are the only way to move focus
              // between controls (play/pause, seek, the volume slider, the
              // transport bar) -- claiming arrowUp/Down/Left/Right here for
              // volume/seek instead meant a D-pad could never reach anything
              // but this one handler. Off TV they keep the desktop-player
              // convention (arrows for seek/volume, same as most
              // keyboard-driven players); a mouse-and-keyboard user never
              // needs the arrows for focus movement the way a D-pad-only
              // remote does. The hardware volume keys and J/K/L keep working
              // everywhere either way -- they never meant "move focus".
              final isTv = TvModeService.isTv.value;

              // A remote has no pointer to bring the controls back with, so
              // an arrow or OK does. On a TV, with them hidden, Left/Right
              // seek (the way a streaming app's remote does) and Up/Down
              // just show them; with them up, the first arrow lands on
              // play/pause and the rest move focus between the controls as
              // the traversal always did.
              final decision = decideRemoteKey(
                key: event.logicalKey,
                isTv: isTv,
                controlsVisible: _showControls,
                // Not while a menu or a side panel has the screen: those take
                // the arrows for their own lists.
                hasOverlayOpen: _activeMenu != null ||
                    _showEpisodesPanel ||
                    _showSourcesPanel ||
                    _showSubSyncBar,
                screenHoldsFocus:
                    FocusManager.instance.primaryFocus == _focusNode,
              );
              if (decision.revealControls) _revealControls();
              switch (decision.action) {
                case RemoteKeyAction.seekBack:
                  _seekRelative(const Duration(seconds: -10));
                case RemoteKeyAction.seekForward:
                  _seekRelative(const Duration(seconds: 10));
                case RemoteKeyAction.focusPlayPause:
                  _playPauseFocus.requestFocus();
                case RemoteKeyAction.revealOnly || RemoteKeyAction.none:
                  break;
              }
              if (decision.isHandled) return KeyEventResult.handled;

              if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
                  (!isTv && event.logicalKey == LogicalKeyboardKey.arrowUp)) {
                _applyVolume(
                  (_volume + 0.05).clamp(0.0, PlayerVolumeControl.maxVolume),
                  showHud: true,
                );
                return KeyEventResult.handled;
              } else if (event.logicalKey ==
                      LogicalKeyboardKey.audioVolumeDown ||
                  (!isTv && event.logicalKey == LogicalKeyboardKey.arrowDown)) {
                _applyVolume(
                  (_volume - 0.05).clamp(0.0, PlayerVolumeControl.maxVolume),
                  showHud: true,
                );
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                _toggleMute(showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.keyK ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                // The D-pad's OK/center button and a gamepad's A button, in
                // addition to the existing desktop shortcuts. Only reached
                // when nothing more specific already took the key (a
                // focused button's own Focus handles it first), so this is
                // the "OK does something sane" fallback for whenever this
                // outer node still holds focus -- e.g. right after the
                // player opens, before focus has moved anywhere.
                _togglePlayPause();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyJ ||
                  (!isTv && event.logicalKey == LogicalKeyboardKey.arrowLeft)) {
                _seekRelative(const Duration(seconds: -10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyL ||
                  (!isTv &&
                      event.logicalKey == LogicalKeyboardKey.arrowRight)) {
                _seekRelative(const Duration(seconds: 10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF ||
                  event.logicalKey == LogicalKeyboardKey.f11) {
                WindowService.instance.toggleFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
                // Subtitles on/off, VLC's key. Turning them on matches the
                // language being heard.
                //
                // The panel is not behind this key -- it is one panel for
                // audio, subtitles and sleep, and it opens on A with the
                // audio menu it replaced. Both keys would be a coin flip.
                _toggleSubtitleShortcut();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
                // Opens the merged panel. "A" was the audio menu and the
                // panel is where that menu went, so the key follows the
                // content rather than being retired.
                _toggleMenu('settings');
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
                _toggleMenu('speed');
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
                _toggleMenu('aspect');
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                // The same ladder as the system Back, so Esc on a keyboard and
                // Back on a remote agree.
                _applyBackAction(_backAction);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              // Pointer scroll signals aren't gesture-arena arbitrated like
              // taps -- they reach every Listener along the hit-test chain,
              // so without this guard scrolling a menu's own list (e.g. the
              // subtitle picker) both scrolled the list *and* changed the
              // volume underneath it.
              if (_activeMenu != null || _showTextSyncOverlay) return;
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
                final next = (_volume + delta).clamp(
                  0.0,
                  PlayerVolumeControl.maxVolume,
                );
                _applyVolume((next * 100).round() / 100.0, showHud: true);
              }
            },
            child: MouseRegion(
              cursor: (_showControls || _isLoading || _activeMenu != null)
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.none,
              onHover: (_) => _handlePointerActivity(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: _handleScreenTap,
                // No swipe-to-adjust. It was desktop-only by the end --
                // mobile had already lost it, because hardware volume keys
                // and the OS brightness control do the same job reliably
                // and an accidental swipe changed either one mid-watch. On
                // desktop the same argument holds: there is a volume slider
                // in the bar, and the screen's brightness is the display's
                // business, not a video player's.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPlayerBody(),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundStack() {
    return Stack(
      children: [
        // Loading Backdrop
        if (_isLoading && widget.backdropUrl != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.network(widget.backdropUrl!, fit: BoxFit.cover),
            ),
          ),

        // Terminal failure: an actionable panel rather than an endless spinner.
        if (_fatalError != null) Positioned.fill(child: _buildFatalErrorView()),

        // Video Player
        Center(
          child: _isLoading
              ? _buildLoadingContent()
              : SizedBox.expand(
                  child: ValueListenableBuilder<int>(
                    valueListenable: PlayerSettings.changeNotifier,
                    builder: (context, _, __) {
                      // media_kit's own subtitle view is off: SubtitleOverlay
                      // below draws the text, so alignment and vertical
                      // position actually apply (see its doc comment).
                      final video = mk.Video(
                        controller: _videoController,
                        fit: _videoFit,
                        controls: mk.NoVideoControls,
                        subtitleViewConfiguration:
                            const mk.SubtitleViewConfiguration(visible: false),
                      );
                      // A forced ratio wraps the video in an AspectRatio:
                      // the picture is letterboxed into the chosen shape and
                      // BoxFit.contain inside it keeps the pixels whole.
                      // Null ratio means the video fills the box on its own
                      // terms -- that is the "Original" option.
                      final picture = _forcedAspectRatio == null
                          ? video
                          : Center(
                              child: AspectRatio(
                                aspectRatio: _forcedAspectRatio!,
                                child: video,
                              ),
                            );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          picture,
                          SubtitleOverlay(
                            lines: _player.stream.subtitle,
                            initialLines: _player.state.subtitle,
                            showSample: _showSubtitleSample,
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),

        // The same loading screen, held over the video until it has a frame.
        // IgnorePointer so the controls and gestures underneath still work:
        // you can back out, or pause, while a slow torrent fills.
        if (_awaitingFirstFrame && !_isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.backdropUrl != null)
                      Opacity(
                        opacity: 0.4,
                        child: Image.network(widget.backdropUrl!, fit: BoxFit.cover),
                      ),
                    Center(child: _buildLoadingContent()),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The logo filling with load progress, and what is being waited on.
  Widget _buildLoadingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _loadProgress,
          builder: (context, progress, _) => PlayerLoadingLogo(progress: progress),
        ),
        SizedBox(height: context.rem(AppRem.lg)),
        Text(
          _status(context.l10n),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: AppType.bodyLg,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Whether there is another source to switch to, so the Cast snackbar only
  /// offers the picker when opening it would show something.
  bool get _hasOtherSources =>
      (_cachedSourcesByEpisode[_sourcesEpisode?.id ?? ''] ?? const [])
          .length >
      1;

  /// The stats popover's source line: who serves this stream. Falls back to
  /// the title when the source carries neither name.
  String get _statsSourceLabel {
    final parts = [
      _currentSource.addonName,
      _currentSource.name ?? '',
    ].where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return _currentTitle;
    return parts.join(' · ');
  }

  /// The host the player opened, for anything fetched over the network. A
  /// P2P torrent resolves to this device's own loopback, which names no host
  /// worth showing, so that case reports no host at all.
  String? get _statsHost {
    if (_statsMagnet != null) return null;
    final uri = _resolvedStreamUrl == null
        ? null
        : Uri.tryParse(_resolvedStreamUrl!);
    final host = uri?.host ?? '';
    return host.isEmpty ? null : host;
  }

  /// The torrent hash behind a P2P stream, from the source or from its magnet
  /// link. A debrid link started as a magnet too, but its bytes come from the
  /// debrid host now, so a hash there would answer a question nobody asked.
  String? get _statsHash {
    if (_statsMagnet == null) return null;
    final direct = _currentSource.infoHash;
    if (direct != null && direct.isNotEmpty) return direct;
    final raw = _currentSource.url;
    if (raw == null) return null;
    return RegExp(r'btih:([a-zA-Z0-9]+)').firstMatch(raw)?.group(1);
  }

  void _handleCast() {
    final url = _resolvedStreamUrl;
    // A null url is the offline path: a downloaded file played straight off
    // this device's disk, which has no URL at all for a receiver to fetch.
    // Same answer as an unreachable one, so the button never just does
    // nothing.
    if (url == null || !_isCastableSource) {
      // The message names the actual reason, not the source's category. The
      // old copy said "torrent ones do not", which is wrong and contradicted
      // the rule that decides this: `canCastUrl` tests the *host*, because a
      // torrent that resolves through a debrid or a torrent server on
      // another machine is perfectly fetchable by a receiver. What a
      // receiver cannot reach is this device's own loopback -- which is
      // where TorrServer serves from, and where a downloaded file lives.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playerCastUnreachable),
          duration: const Duration(seconds: 5),
          action: _hasOtherSources
              ? SnackBarAction(
                  label: context.l10n.playerSources,
                  onPressed: () => setState(() => _showSourcesPanel = true),
                )
              : null,
        ),
      );
      return;
    }
    PlayerCastSheet.show(
      context,
      title: widget.detail?.name ?? _currentTitle,
      streamUrl: url,
      posterUrl: widget.detail?.poster,
    );
  }

  void _handleCopyStreamUrl() {
    final url = _resolvedStreamUrl;
    if (url == null) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.playerStreamUrlCopied)),
    );
  }

  /// Whether this video can be downloaded from here: it has a title behind
  /// it to file the download under, and it is not already a local file.
  bool get _canDownload {
    final url = _currentSource.url;
    // A torrent may carry only an info hash and no URL, so a missing URL is
    // not by itself a reason to hide the button.
    final isLocal =
        _currentSource.name == 'Downloaded' ||
        (url != null && File(url).existsSync());
    return widget.detail != null && !isLocal;
  }

  void _handleDownload() {
    final detail = widget.detail;
    if (detail == null) return;
    startSourceDownload(
      context,
      detail: detail,
      episode: _currentEpisode,
      source: _currentSource,
    );
  }

  /// "S1:E2 - Title" for the loading screen, with a translated stand-in when
  /// the episode has no title.
  String _episodeStatusLabel(AppLocalizations l10n, Video episode) {
    final number = episode.episode ?? 1;
    final title =
        episode.title.isNotEmpty ? episode.title : l10n.playerEpisodeN(number);
    return 'S${episode.season ?? 1}:E$number - $title';
  }

  Widget _buildControlsOverlay() {
    final buffered = _buffered;

    final isColl = widget.detail?.isCollection == true;
    final episodeTitle = _currentEpisode?.title;
    final episodeSubtitle = _currentEpisode != null
        ? (isColl
            ? '${context.l10n.playerEpisodePart(_currentEpisode!.episode ?? 1)}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}'
            : 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}')
        : widget.detail?.year;

    return Stack(
      children: [
        // Outside Tap Barrier to dismiss active floating menu
        if (_activeMenu != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() {
                _activeMenu = null;
                _menuParent = null;
              }),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Top Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeFocus(
            excluding: !_controlsFocusable,
            child: IgnorePointer(
            ignoring:
                (!_showControls && !_isLoading) ||
                _showSubSyncBar ||
                _showTextSyncOverlay,
            child: AnimatedOpacity(
              opacity:
                  (_showControls || _isLoading) &&
                      !_showSubSyncBar &&
                      !_showTextSyncOverlay
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 200),
              child: MouseRegion(
                onEnter: (_) {
                  _isHoveringUI = true;
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  _isHoveringUI = false;
                  _startHideControlsTimer();
                },
                child: PlayerTopBar(
                  title: widget.detail?.name ?? _currentTitle,
                  subtitle: episodeSubtitle,
                  quality: _currentSource.name,
                  // Shown whenever the platform has a Cast SDK at all --
                  // there is none on desktop. It used to be hidden for any
                  // source this device serves itself, which on a phone meant
                  // it was absent from the movie player almost always, with
                  // nothing to say why. Now it is there, and tapping it on
                  // an unreachable stream explains the problem instead of
                  // the button silently not existing.
                  onCast: (_isLoading || !CastService.isSupported)
                      ? null
                      : _handleCast,
                  onCopyStreamUrl: (_isLoading || _resolvedStreamUrl == null)
                      ? null
                      : _handleCopyStreamUrl,
                  onDownload: (_isLoading || !_canDownload) ? null : _handleDownload,
                  onToggleFullscreen: _toggleFullscreen,
                  onToggleEpisodes:
                      (!_isLoading &&
                          widget.detail?.videos.isNotEmpty == true)
                      ? _toggleEpisodesPanel
                      : null,
                  isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                  onBack: () {
                    if (!_wasFullscreenBeforeEntering &&
                        WindowService.instance.isFullscreen) {
                      WindowService.instance.exitFullscreen();
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
          ),
        ),

        // Seek feedback. Deliberately not gated on _showControls: a
        // double-tap seek happens with the overlay hidden, and that is
        // exactly when some confirmation that the tap registered matters
        // most.
        if (!_isLoading)
          Positioned.fill(
            child: PlayerSeekFeedback(flash: _seekFlash),
          ),

        // Centered Play/Pause + ±10s (YouTube/Netflix style)
        if (!_isLoading)
          Positioned.fill(
            child: ExcludeFocus(
              excluding: !_controlsFocusable,
              child: IgnorePointer(
              ignoring: !_showControls || _showTextSyncOverlay,
              child: AnimatedOpacity(
                opacity: (_showControls && !_showTextSyncOverlay) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  // Down from the centered buttons is the seek bar, by name,
                  // on a TV: the nearest thing below the left or right seek
                  // button is not always it.
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (node, event) {
                      if (!TvModeService.isTv.value ||
                          event is! KeyDownEvent ||
                          event.logicalKey != LogicalKeyboardKey.arrowDown) {
                        return KeyEventResult.ignored;
                      }
                      _seekFocus.requestFocus();
                      return KeyEventResult.handled;
                    },
                    child: PlayerCenterControls(
                      playPauseFocusNode: _playPauseFocus,
                      isPlaying: _isPlaying,
                      onPlayPause: _togglePlayPause,
                      onSeekBack30: () =>
                          _seekRelative(const Duration(seconds: -30)),
                      onSeekForward30: () =>
                          _seekRelative(const Duration(seconds: 30)),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),

        // Bottom Transport Bar
        if (!_isLoading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ExcludeFocus(
              excluding: !_controlsFocusable,
              child: IgnorePointer(
              ignoring:
                  (!_showControls && _activeMenu == null) ||
                  _showTextSyncOverlay,
              child: AnimatedOpacity(
                opacity:
                    (_showControls || _activeMenu != null) &&
                        !_showTextSyncOverlay
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: MouseRegion(
                  onEnter: (_) {
                    _isHoveringUI = true;
                    _hideTimer?.cancel();
                  },
                  onExit: (_) {
                    _isHoveringUI = false;
                    _startHideControlsTimer();
                  },
                  child: PlayerTransport(
                    position: _position,
                    duration: _duration,
                    buffered: buffered,
                    positionListenable: _positionNotifier,
                    bufferedListenable: _bufferNotifier,
                    skipSegments: _skipSegments,
                    volume: _volume,
                    isMuted: _isMuted || _volume == 0,
                    playbackRate: _playbackRate,
                    isSubtitlesActive:
                        _isSubtitleEnabled && _currentSubtitleVariant != null,
                    onSeek: (pos) => _player.seek(pos),
                    onVolumeChanged: (vol) => _applyVolume(vol),
                    onToggleMute: () => _toggleMute(),
                    onOpenSubtitleMenu: () => _toggleMenu('subtitle'),
                    onOpenSpeedMenu: () => _toggleMenu('speed'),
                    onOpenStatsMenu: () => _toggleMenu('stats'),
                    onOpenAudioMenu: () => _toggleMenu('audio'),
                    onOpenAspectMenu: () => _toggleMenu('aspect'),
                    onOpenSleepTimerMenu: () => _toggleMenu('sleep'),
                    onOpenVolumeMenu: () => _toggleMenu('volume'),
                    seekFocusNode: _seekFocus,
                    volumeFocusNode: _volumeFocus,
                    playPauseFocusNode: _playPauseFocus,
                  ),
                ),
              ),
            ),
            ),
          ),

        // Floating Subtitle Menu Popover
        if (_activeMenu == 'subtitle' && !_isLoading)
          // Floating Subtitle Menu Popover
        if (_activeMenu == 'subtitle' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerSubtitleMenu(
              onBack: _backToSettings,
              onAppearanceOpenChanged: (open) {
                if (mounted && _showSubtitleSample != open) {
                  setState(() => _showSubtitleSample = open);
                }
              },
              groups: _subtitleGroups,
              embeddedSubtitles: _embeddedSubtitles,
              audioLanguage: _selectedAudioLanguage,
              selectedEmbeddedIndex: _selectedEmbeddedSubtitleIndex,
              selectedVariant: _currentSubtitleVariant,
              isSubtitleEnabled: _isSubtitleEnabled,
              delaySec: _subtitleDelayMs / 1000.0,
              onSelectVariant: _loadSubtitle,
              onSelectEmbedded: _selectEmbeddedSubtitle,
              // One button, and it does whichever of these is not already
              // done: on picks the track for the language being heard, off
              // clears it.
              onEnable: _pickBestSubtitle,
              onDisable: _disableSubtitles,
              onRefresh: _refreshOnlineSubtitles,
              onOpenSyncBar: () {
                if (_selectedEmbeddedSubtitleIndex != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.playerSubSyncEmbeddedUnsupported,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() {
                  _activeMenu = null;
                  _menuParent = null;
                  _showSubSyncBar = true;
                });
              },
              player: _player,
            ),
          ),

        // Floating Audio Menu Popover
        if (_activeMenu == 'audio' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerAudioMenu(
              onBack: _backToSettings,
              audioTracks: _audioTracks,
              selectedIndex: _selectedAudioTrackIndex,
              onTrackSelected: (idx) {
                setState(() => _selectedAudioTrackIndex = idx);
                try {
                  final matching = _player.state.tracks.audio.firstWhere(
                    (t) => t.id == idx.toString(),
                    orElse: () => AudioTrack(idx.toString(), null, null),
                  );
                  _player.setAudioTrack(matching);
                  final np = _player.platform as dynamic;
                  np.setProperty('aid', idx.toString());
                } catch (_) {
                  // Setting 'aid' through the platform handle repeats
                  // setAudioTrack above for builds that ignore the Dart-side
                  // call. Older ones reject the property instead.
                }
                final match = _audioTracks
                    .where((t) => t.index == idx)
                    .firstOrNull;
                _showAudioHudToast(match?.title ?? 'Track $idx');
              },
            ),
          ),

        // Floating Sleep Timer Popover
        if (_activeMenu == 'sleep' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: const SleepTimerMenu(),
          ),

        // Floating Volume Popover (a TV's way in; see PlayerVolumeMenu)
        if (_activeMenu == 'volume' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerVolumeMenu(
              onBack: _backToSettings,
              volume: _volume,
              isMuted: _isMuted || _volume == 0,
              onVolumeChanged: (vol) => _applyVolume(vol),
              onToggleMute: () => _toggleMute(),
            ),
          ),

        // Floating Speed Menu Popover
        if (_activeMenu == 'speed' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerSpeedMenu(
              onBack: _backToSettings,
              currentRate: _playbackRate,
              onRateSelected: (rate) {
                setState(() => _playbackRate = rate);
                _player.setRate(rate);
              },
              onClose: () => setState(() {
                _activeMenu = null;
                _menuParent = null;
              }),
            ),
          ),

        // Floating Stream Statistics Popover
        if (_activeMenu == 'stats' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerStatsMenu(
              sourceLabel: _statsSourceLabel,
              streamKind: _statsKind,
              isLive: _statsIsLive,
              host: _statsHost,
              infoHash: _statsHash,
              torrentMagnet: _statsMagnet,
              buffered: _bufferNotifier,
            ),
          ),

        // Floating Aspect Ratio Popover
        if (_activeMenu == 'aspect' && !_isLoading)
          PlayerMenuAnchor(
            onClose: _closeActiveMenu,
            child: PlayerAspectMenu(
              onBack: _backToSettings,
              currentFit: _videoFit,
              currentForcedRatio: _forcedAspectRatio,
              onFitSelected: (fit) => setState(() {
                _videoFit = fit;
                // A fit and a forced ratio are two answers to the same
                // question, so picking one clears the other.
                _forcedAspectRatio = null;
              }),
              onRatioSelected: (ratio) => setState(() {
                _forcedAspectRatio = ratio;
                // Contain is the fit that respects a forced ratio: cover
                // would crop the reshaped frame and fill would distort it,
                // either of which defeats the point of forcing the shape.
                _videoFit = BoxFit.contain;
              }),
              onClose: () => setState(() {
                _activeMenu = null;
                _menuParent = null;
              }),
            ),
          ),

        // Top Floating Live SubSyncBar
        if (_showSubSyncBar &&
            !_isLoading &&
            _selectedEmbeddedSubtitleIndex == null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + context.rem(AppRem.md),
            left: 0,
            right: 0,
            child: SubSyncBar(
              delaySec: _subtitleDelayMs / 1000.0,
              isTextSyncAvailable:
                  _selectedEmbeddedSubtitleIndex == null &&
                  _currentSubtitlePath != null &&
                  _currentCues.isNotEmpty,
              onDelayChanged: (sec) => _applyLiveDelay(sec),
              onEnterTextSync: () {
                setState(() {
                  _showSubSyncBar = false;
                  _showTextSyncOverlay = true;
                });
              },
              onClose: () {
                setState(() => _showSubSyncBar = false);
                _startHideControlsTimer();
              },
            ),
          ),

        // In-Player Episodes Side Panel
        if (_showEpisodesPanel &&
            widget.detail?.videos.isNotEmpty == true &&
            !_isLoading)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showEpisodesPanel = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: GestureDetector(
                  onTap: () {},
                  child: PlayerEpisodesPanel(
                    videos: widget.detail!.videos,
                    currentEpisode: _currentEpisode,
                    onEpisodeSelected: _onEpisodeChosen,
                    onClose: () => setState(() => _showEpisodesPanel = false),
                  ),
                ),
              ),
            ),
          ),

        // In-Player Sources Side Panel (Targeted Scraping & Error Recovery)
        if (_showSourcesPanel && _sourcesEpisode != null && !_isLoading)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showSourcesPanel = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: GestureDetector(
                  onTap: () {},
                  child: PlayerSourcesPanel(
                    episode: _sourcesEpisode!,
                    detail: widget.detail,
                    currentAddonName: _currentSource.addonName,
                    errorMessage: _sourcesErrorMessage,
                    cachedSources:
                        _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'],
                    onSourcesLoaded: (sources) {
                      _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'] =
                          sources;
                    },
                    onPlaySource: _playNewSource,
                    onBackToEpisodes: _onBackToEpisodes,
                    onClose: () => setState(() => _showSourcesPanel = false),
                  ),
                ),
              ),
            ),
          ),

        // Right Drawer Text Sync
        if (_showTextSyncOverlay &&
            !_isLoading &&
            _currentCues.isNotEmpty &&
            _selectedEmbeddedSubtitleIndex == null)
          Positioned.fill(
            child: TextSyncOverlay(
              player: _player,
              initialCues: _currentCues,
              baseOffsetSec: _subtitleDelayMs / 1000.0,
              onClose: () {
                setState(() => _showTextSyncOverlay = false);
                _startHideControlsTimer();
              },
              onSave: _saveTextSyncedCues,
            ),
          ),

        // Floating Skip Button (Skip Intro, Skip Recap, Skip Credits, Skip Preview)
        if (_showSkipButton &&
            _activeSkipSegment != null &&
            !_isLoading &&
            !_showTextSyncOverlay &&
            !_showEpisodesPanel &&
            !_showSourcesPanel)
          Positioned(
            bottom: (_showControls || _activeMenu != null)
                ? (MediaQuery.paddingOf(context).bottom +
                      context.rem(MediaQuery.sizeOf(context).width < 680 ? 6.75 : 8))
                : (MediaQuery.paddingOf(context).bottom +
                      context.rem(MediaQuery.sizeOf(context).width < 680 ? 1.375 : 2.25)),
            right: context.rem(MediaQuery.sizeOf(context).width < 680 ? AppRem.md : 1.75),
            child: AnimatedOpacity(
              opacity: _showSkipButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: PlayerSkipButton(
                segment: _activeSkipSegment!,
                onSkip: () => _handleSkipSegment(_activeSkipSegment!),
                onDismiss: () => _handleDismissSkipSegment(_activeSkipSegment!),
              ),
            ),
          ),

        // Center Heads-Up Volume Display (HUD)
        if (_showVolumeHud)
          Positioned.fill(child: IgnorePointer(child: _buildVolumeHud())),

        // Center Heads-Up Audio Display (HUD)
        if (_showAudioHud)
          Positioned.fill(child: IgnorePointer(child: _buildAudioHud())),
      ],
    );
  }

  Widget _buildVolumeHud() {
    final effectiveVol = _isMuted ? 0.0 : _volume;
    final isBoosting = !_isMuted && _volume > 1.001;
    final pct = (effectiveVol * 100).round();
    final boostColor = _volume > 1.75
        ? const Color(0xFFFF3D00)
        : (_volume > 1.0 ? const Color(0xFFFF8A00) : Colors.white);

    IconData volIcon;
    if (_isMuted || _volume == 0) {
      volIcon = Icons.volume_off_rounded;
    } else if (_volume > 1.0) {
      volIcon = Icons.volume_up_rounded;
    } else if (_volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    } else {
      volIcon = Icons.volume_up_rounded;
    }

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.lg), vertical: context.rem(AppRem.md)),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(context.rem(1.25)),
          border: Border.all(
            color: isBoosting
                ? boostColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2, // px: a hairline, not a layout size
          ),
          boxShadow: [
            BoxShadow(
              color: isBoosting
                  ? boostColor.withValues(alpha: 0.28)
                  : Colors.black54,
              blurRadius: context.rem(1.875),
              spreadRadius: context.rem(AppRem.xxs),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  volIcon,
                  color: isBoosting ? boostColor : Colors.white,
                  size: context.rem(1.75),
                ),
                SizedBox(width: context.rem(AppRem.ms)),
                Text(
                  _isMuted ? 'Muted' : '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : Colors.white,
                    fontSize: AppType.titleMd,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isBoosting) ...[
                  SizedBox(width: context.rem(AppRem.sm)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(AppRem.sm),
                      vertical: context.rem(0.1875),
                    ),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                      border: Border.all(
                        color: boostColor.withValues(alpha: 0.4),
                        width: 0.8, // px: a hairline, not a layout size
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: context.rem(0.8125), color: boostColor),
                        SizedBox(width: context.rem(AppRem.xxs)),
                        Text(
                          _volume > 1.75 ? 'MAX BOOST' : 'BOOST',
                          style: TextStyle(
                            color: boostColor,
                            fontSize: TvType.scale(AppType.microPlus),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: context.rem(AppRem.ms)),
            SizedBox(
              width: context.rem(8.75),
              height: context.rem(AppRem.snug),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.rem(0.1875)),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          (effectiveVol / PlayerVolumeControl.maxVolume).clamp(
                            0.0,
                            1.0,
                          ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isBoosting
                              ? LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFFF8A00),
                                    if (_volume > 1.75) const Color(0xFFFF3D00),
                                  ],
                                )
                              : null,
                          color: isBoosting ? null : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioHudToast(String text) {
    _audioHudTimer?.cancel();
    setState(() {
      _audioHudText = text;
      _showAudioHud = true;
    });
    _audioHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showAudioHud = false);
    });
  }

  Widget _buildAudioHud() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.rem(1.375), vertical: context.rem(0.875)),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.5),
            width: 1.2, // px: a hairline, not a layout size
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              blurRadius: context.rem(AppRem.lg),
              spreadRadius: context.rem(AppRem.xxs),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.audiotrack_rounded,
              color: const Color(0xFF00D2EF),
              size: context.rem(AppRem.iconLg),
            ),
            SizedBox(width: context.rem(0.625)),
            Text(
              _audioHudText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.bodyPlus,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: _buildBackgroundStack()),
        RepaintBoundary(child: _buildControlsOverlay()),
      ],
    );
  }
}
