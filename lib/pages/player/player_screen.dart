import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:playtorrio/models/movie/video.dart';
import 'package:playtorrio/models/movie/movie_detail.dart';
import 'package:playtorrio/models/subtitle/subtitle_model.dart';
import 'package:playtorrio/services/subtitles/subtitle_service.dart';
import 'package:playtorrio/services/subtitles/subtitle_parser.dart';

import '../../models/stream/stream_model.dart';
import '../../services/playback_coordinator.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/player/player_settings.dart';
import '../../services/discord/discord_rpc_service.dart';

import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/player_transport.dart';
import '../../widgets/player/player_speed_menu.dart';
import '../../services/window/window_service.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/skip_segments_service.dart';
import '../../widgets/player/player_aspect_menu.dart';
import '../../widgets/player/player_audio_menu.dart';
import '../../widgets/player/player_subtitle_menu.dart';
import '../../widgets/player/player_sub_style_modal.dart';
import '../../widgets/player/player_skip_button.dart';
import '../../widgets/player/player_episodes_panel.dart';
import '../../widgets/player/player_sources_panel.dart';
import '../../widgets/player/player_volume_control.dart';
import '../../widgets/player/sub_sync_bar.dart';
import '../../widgets/player/text_sync_overlay.dart';
import '../../models/download/download_task_model.dart';
import '../../services/download/download_service.dart';
import '../../utils/download/download_path_helper.dart';

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
    with SingleTickerProviderStateMixin {
  late final Player _player = Player(configuration: PlayerSettings.getMediaKitPlayerConfiguration());
  late final mk.VideoController _videoController = mk.VideoController(
    _player,
    configuration: PlayerSettings.getVideoControllerConfiguration(),
  );
  final List<StreamSubscription> _subscriptions = [];

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration?> _bufferNotifier = ValueNotifier<Duration?>(null);

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
  String _statusMessage = 'Initializing...';
  bool _showControls = true;
  bool _isHoveringUI = false;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  DateTime? _lastPointerTimerReset;
  late AnimationController _logoAnimController;

  // Active Menu / Popover
  String? _activeMenu; // 'subtitle' | 'audio' | 'speed' | 'aspect' | 'style' | null
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
  List<PlayerAudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = 0;
  double _audioDelaySec = 0.0;
  bool _showAudioHud = false;
  String _audioHudText = '';
  Timer? _audioHudTimer;

  // Subtitle State
  List<SubtitleLanguageGroup> _subtitleGroups = [];
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
  bool _showSourcesPanel = false;
  Video? _sourcesEpisode;
  String? _sourcesErrorMessage;
  final Map<String, List<StreamSource>> _cachedSourcesByEpisode = {};

  // ── Gesture state (volume / brightness swipes) ──
  double _brightness = 1.0;
  bool _showGestureIndicator = false;
  String _gestureIndicatorLabel = '';
  double _gestureIndicatorValue = 0.0;
  IconData _gestureIndicatorIcon = Icons.volume_up_rounded;
  Timer? _gestureIndicatorTimer;
  Offset? _gestureStartPosition;
  double _gestureStartVolume = 1.0;
  double _gestureStartBrightness = 1.0;

  // ── Auto-next episode state ──
  bool _autoNextShown = false;
  bool _autoNextDialogVisible = false;
  int _autoNextCountdown = 10;
  Timer? _autoNextTimer;

  // ── Accessibility / keyboard focus ──
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentSource = widget.source;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;

    WakelockPlus.enable();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    PlayerSettings.changeNotifier.addListener(_onPlayerSettingsChanged);

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
          _updateDiscordRpc(isPaused: !playing);
        }
      }),
      _player.stream.position.listen((pos) {
        _position = pos;
        _positionNotifier.value = pos;
        _onPlaybackTick(pos);
        _onPlaybackUpdate();
      }),
      _player.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
          _updateDiscordRpc();
        }
      }),
      _player.stream.buffer.listen((buf) {
        _buffered = buf;
        _bufferNotifier.value = buf;
      }),
      _player.stream.buffering.listen((isBuffering) {
        if (_wasBuffering && !isBuffering && PlayerSettings.autoResyncOnStall.value) {
          try {
            if (PlayerSettings.hardwareAudioClock.value) {
              final np = _player.platform as dynamic;
              np.setProperty('video-sync', 'audio');
            }
          } catch (_) {}
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

  Future<void> _initStream() async {
    String? streamUrl;

    // Ensure only one source plays app-wide: stop any other active source.
    final sourceId = 'video:${widget.episode?.id ?? widget.detail?.id ?? widget.source.url}';
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
      onSeek: (position) => _player.seek(position),
    );

    print('[PlayerScreen] Initializing playback:');
    print('[PlayerScreen]   Title: $_currentTitle');
    print('[PlayerScreen]   Source Name: ${_currentSource.name}');
    print('[PlayerScreen]   Addon Name: ${_currentSource.addonName}');
    print('[PlayerScreen]   Source Title: ${_currentSource.title}');
    print('[PlayerScreen]   Raw URL: ${_currentSource.url}');

    try {
      final rawUrl = _currentSource.url;

      // Handle offline downloaded file playback directly
      if (rawUrl != null && (File(rawUrl).existsSync() || _currentSource.name == 'Downloaded')) {
        print('[PlayerScreen] Initializing offline local file playback: $rawUrl');
        await PlayerSettings.applyPreOpenProperties(_player);
        // Volume before open: open() starts playback immediately, so applying
        // it afterwards let a muted or quietened video blast a moment of
        // full-volume audio first.
        _applyVolume(_isMuted ? 0.0 : _volume);
        await _player.open(Media(rawUrl), play: true);
        await PlayerSettings.applyPostOpenProperties(_player);
        _setSubtitleScale(_subtitleScale);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final infoHash = _currentSource.infoHash;
      final isMagnetUrl = rawUrl != null && rawUrl.startsWith('magnet:');
      final isTorrent = (infoHash != null && infoHash.isNotEmpty) || isMagnetUrl;

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
          setState(() => _statusMessage = 'Using $activeService for files...');

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
          print('[PlayerScreen] Debrid resolved stream URL: $streamUrl');
        } else {
          if (!mounted) return;
          setState(() => _statusMessage = 'Gathering metadata & peers...');

          streamUrl = await TorrentStreamService().streamTorrent(
            magnet,
            fileIdx: _currentSource.fileIdx,
          );
        }
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        streamUrl = rawUrl;
      } else {
        throw Exception('No valid stream source found.');
      }

      if (streamUrl == null) throw Exception('Stream URL is null');

      final sanitizedUrlStr = streamUrl.contains('::')
          ? streamUrl.replaceAll('::', '%3A%3A')
          : streamUrl;

      // Automatically resolve complete CDN headers (Referer, Origin, User-Agent)
      final playerHeaders = PlayerSettings.resolveStreamHeaders(
        sanitizedUrlStr,
        _currentSource.headers,
      );

      // Also merge any proxyHeaders from behaviorHints if present
      final proxyReqHeaders = _currentSource.behaviorHints?['proxyHeaders']?['request'];
      if (proxyReqHeaders is Map) {
        playerHeaders.addAll(Map<String, String>.from(proxyReqHeaders));
      }

      final cleanUri = Uri.parse(sanitizedUrlStr);
      print('[PlayerScreen] Opening direct network stream URL: $cleanUri (headers: ${playerHeaders.keys})');

      if (!mounted) return;
      final epLabel = _currentEpisode != null
          ? 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1} - ${_currentEpisode!.title.isNotEmpty ? _currentEpisode!.title : "Episode ${_currentEpisode!.episode ?? 1}"}'
          : (widget.detail?.name ?? _currentTitle);
      setState(() => _statusMessage = 'Buffering $epLabel...');

      final lowerClean = sanitizedUrlStr.toLowerCase();
      final bool isLive = _currentSource.behaviorHints?['isLive'] == true ||
          _currentSource.addonName.toLowerCase() == 'iptv' ||
          _currentSource.name?.toLowerCase() == 'iptv' ||
          lowerClean.contains('/live/') ||
          lowerClean.contains('/hls/live');

      final bool isTorrentStream = isTorrent ||
          sanitizedUrlStr.contains(':8090') ||
          sanitizedUrlStr.contains('/stream?link=') ||
          sanitizedUrlStr.contains('/stream?');

      await PlayerSettings.applyPreOpenProperties(_player, isLive: isLive, isTorrent: isTorrentStream);

      // Set native MPV properties for referer and user-agent directly on the player for web streams
      if (!isTorrentStream) {
        try {
          final dynamic platform = _player.platform;
          if (platform != null) {
            final referer = playerHeaders['Referer'] ?? playerHeaders['referer'];
            if (referer != null && referer.isNotEmpty) {
              await platform.setProperty('referrer', referer);
            }
            final ua = playerHeaders['User-Agent'] ?? playerHeaders['user-agent'];
            if (ua != null && ua.isNotEmpty) {
              await platform.setProperty('user-agent', ua);
            }
          }
        } catch (e) {
          print('[PlayerScreen] Warning setting native header properties: $e');
        }
      }

      // Volume before open, for the same reason as the offline path above.
      _applyVolume(_isMuted ? 0.0 : _volume);

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

      print('[PlayerScreen SUCCESS] Player opened media successfully for $streamUrl');

      _updateMediaTracks(_player.state.tracks);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

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
          final targetId = detail.id.startsWith('tt') ? detail.id : (detail.tmdbId ?? detail.id);
          if (targetId.isNotEmpty) {
            final s = _currentEpisode?.season;
            final e = _currentEpisode?.episode;
            final initPos = widget.initialPosition?.inSeconds ?? 0;
            final dur = _player.state.duration.inSeconds;
            final progress = (dur > 0 ? (initPos / dur) * 100.0 : 0.0).clamp(0.0, 100.0);

            TraktService.instance.isAuthenticated().then((authed) {
              if (authed) {
                TraktService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
              }
            });
            SimklService.instance.isAuthenticated().then((authed) {
              if (authed) {
                SimklService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
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
      print('[PlayerScreen ERROR] Failed to initialize stream URL: "$streamUrl"');
      print('[PlayerScreen ERROR] Exception: $e');
      print('[PlayerScreen ERROR] StackTrace:\n$stackTrace');

      if (!mounted) return;

      // If we have an episode context (TV show), reopen the sources panel with error notice!
      if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
        setState(() {
          _isLoading = false;
          _showSourcesPanel = true;
          _sourcesEpisode = _currentEpisode;
          _sourcesErrorMessage = 'Source failed to play. Please select another source below.';
        });
        return;
      }

      String displayMessage = 'Error: $e';
      if (e is PlatformException &&
          (e.message?.contains('invalid or unsupported media') ?? false)) {
        displayMessage =
            'Media Open Error: Stream server quota exceeded or invalid media format.\nPlease select another stream.';
      }

      setState(() {
        _isLoading = false;
        _statusMessage = displayMessage;
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
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.skip_next_rounded,
                    color: Color(0xFF7C5CFF),
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Up Next',
                    style: TextStyle(
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
                    'Playing next episode in $_autoNextCountdown seconds...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'S${widget.episode?.season ?? '?'}E${(widget.episode?.episode ?? 0) + 1}',
                    style: const TextStyle(
                      color: Color(0xFF7C5CFF),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _autoNextTimer?.cancel();
                    Navigator.pop(dialogContext);
                    _autoNextDialogVisible = false;
                    _playNextEpisode();
                  },
                  child: const Text(
                    'Play Next',
                    style: TextStyle(
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

  void _updateMediaTracks(Tracks tracks) {
    if (!mounted) return;
    final audioList = tracks.audio;
    final audioTracks = <PlayerAudioTrack>[];
    for (int i = 0; i < audioList.length; i++) {
      final t = audioList[i];
      if (t.id == 'no' || t.id == 'auto') continue;
      final lang = t.language;
      final title = t.title ?? (lang != null ? lang.toUpperCase() : 'Track ${i + 1}');
      final idx = int.tryParse(t.id) ?? (i + 1);
      audioTracks.add(PlayerAudioTrack(
        index: idx,
        title: title,
        language: lang,
        channels: int.tryParse(t.channels?.toString() ?? ''),
      ));
    }

    final subList = tracks.subtitle;
    final embeddedSubs = <PlayerEmbeddedSubtitle>[];
    for (int i = 0; i < subList.length; i++) {
      final t = subList[i];
      if (t.id == 'no' || t.id == 'auto') continue;
      final lang = t.language;
      final title = t.title ?? (lang != null ? lang.toUpperCase() : 'Track ${i + 1}');
      final idx = int.tryParse(t.id) ?? (i + 1);
      embeddedSubs.add(PlayerEmbeddedSubtitle(
        index: idx,
        title: title,
        language: lang,
      ));
    }

    int activeIdx = _selectedAudioTrackIndex;
    if (activeIdx == 0 && audioTracks.isNotEmpty) {
      final activeAid = _player.state.track.audio.id;
      activeIdx = int.tryParse(activeAid) ?? audioTracks.first.index;
    }

    setState(() {
      _audioTracks = audioTracks;
      _embeddedSubtitles = embeddedSubs;
      if (_selectedAudioTrackIndex == 0 && audioTracks.isNotEmpty) {
        _selectedAudioTrackIndex = activeIdx;
      }
    });
  }

  static String cleanMediaTitle(String raw) {
    var name = raw;
    name = name.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|ts|mov|m4v|srt|vtt)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[._]'), ' ');
    name = name.replaceAll(RegExp(r'\b(2160p|1080p|720p|480p|4k|uhd|ds4k|webrip|web-dl|bluray|brrip|h264|x264|h265|x265|hevc|10bit|ddp5\.1|dd5\.1|atmos|aac|ac3|dts|flac|remux|hdr|dv|proper|repack|hdtv)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _fetchInitialSubtitles() async {
    try {
      int? searchYear;
      if (widget.detail?.year != null && widget.detail!.year!.isNotEmpty) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(widget.detail!.year!);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final rawName = widget.detail?.name ?? widget.title;
      if (searchYear == null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawName);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final showName = cleanMediaTitle(rawName);
      print('[PlayerScreen] Scraping initial subtitles for "$showName" (year: $searchYear, imdb: ${widget.detail?.id})...');

      final groups = await SubtitleService().fetchAllSubtitles(
        showName,
        imdbId: widget.detail?.id,
        season: _currentEpisode?.season,
        episode: _currentEpisode?.episode,
        year: searchYear,
      );
      print('[PlayerScreen] Scraped ${groups.length} subtitle language groups with ${groups.fold(0, (s, g) => s + g.variants.length)} total variants');
      if (mounted && groups.isNotEmpty) {
        setState(() => _subtitleGroups = groups);

        // Auto-load matching language subtitle for the new episode if subtitles were enabled
        if (_isSubtitleEnabled && _currentSubtitleVariant != null) {
          final previousLang = _currentSubtitleVariant!.language.toLowerCase();
          final matchingGroup = groups.firstWhere(
            (g) => g.language.toLowerCase() == previousLang,
            orElse: () => groups.firstWhere(
              (g) => g.language.toLowerCase().contains('english') || g.language.toLowerCase() == 'en',
              orElse: () => groups.first,
            ),
          );
          if (matchingGroup.variants.isNotEmpty) {
            _loadSubtitle(matchingGroup.variants.first);
          }
        }
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
      }
    });
  }

  void _toggleControls() {
    if (_showTextSyncOverlay || _activeMenu != null) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _handlePointerActivity() {
    if (_isLoading) return;
    if (!_showControls) setState(() => _showControls = true);

    final now = DateTime.now();
    if (_lastPointerTimerReset == null ||
        now.difference(_lastPointerTimerReset!) >= const Duration(milliseconds: 250)) {
      _lastPointerTimerReset = now;
      _startHideControlsTimer();
    }
  }

  // ── Gesture handlers: vertical swipe left = volume, right = brightness ──

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isLoading) return;
    _gestureStartPosition = details.globalPosition;
    _gestureStartVolume = _volume;
    _gestureStartBrightness = _brightness;
    _hideTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isLoading || _gestureStartPosition == null) {
      return;
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (screenHeight <= 0) return;

    final delta = details.globalPosition.dy - _gestureStartPosition!.dy;
    final normalized = (delta / screenHeight).clamp(-1.0, 1.0);

    // Left half of screen = volume, right half = brightness
    final isLeftSide =
        details.globalPosition.dx < MediaQuery.sizeOf(context).width / 2;

    if (isLeftSide) {
      final newVolume = (_gestureStartVolume - normalized).clamp(0.0, PlayerVolumeControl.maxVolume);
      _applyVolume(newVolume);
      _updateGestureIndicator(
        label: 'Volume',
        value: newVolume / PlayerVolumeControl.maxVolume,
        icon: newVolume == 0
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded,
      );
    } else {
      final newBrightness = (_gestureStartBrightness - normalized).clamp(0.0, 1.0);
      _brightness = newBrightness;
      _updateGestureIndicator(
        label: 'Brightness',
        value: newBrightness,
        icon: Icons.brightness_6_rounded,
      );
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _gestureStartPosition = null;
    _startHideControlsTimer();
  }

  void _updateGestureIndicator({
    required String label,
    required double value,
    required IconData icon,
  }) {
    _gestureIndicatorTimer?.cancel();
    setState(() {
      _showGestureIndicator = true;
      _gestureIndicatorLabel = label;
      _gestureIndicatorValue = value.clamp(0.0, 1.0);
      _gestureIndicatorIcon = icon;
    });
    _gestureIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showGestureIndicator = false);
    });
  }

  void _toggleMenu(String menuName) {
    setState(() {
      if (_activeMenu == menuName) {
        _activeMenu = null;
        _startHideControlsTimer();
      } else {
        _activeMenu = menuName;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _hideTimer?.cancel();
      }
    });
  }

  void _selectEmbeddedSubtitle(PlayerEmbeddedSubtitle embedded) {
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

    _player.setSubtitleTrack(SubtitleTrack(embedded.index.toString(), embedded.title, embedded.language));
    _setSubtitleScale(_subtitleScale);
    PlayerSettings.applySubtitleStyling(_player);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to embedded subtitle: ${embedded.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
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
    _player.setSubtitleTrack(SubtitleTrack.no());
  }

  Future<void> _loadSubtitle(SubtitleVariant variant) async {
    _currentSubtitleVariant = variant;
    _selectedEmbeddedSubtitleIndex = null;
    _isSubtitleEnabled = true;
    _player.setSubtitleTrack(SubtitleTrack.no());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${variant.language} subtitle...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final path = await SubtitleService().downloadSubtitle(variant);
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download subtitle')),
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
      print('[PlayerScreen] Subtitle cues parse error: $e');
    }

    _currentSubtitlePath = path;
    final resolvedUri = _resolveSubtitleUri(path);
    _player.setSubtitleTrack(SubtitleTrack.uri(resolvedUri, title: variant.language));
    _setSubtitleScale(_subtitleScale);
    PlayerSettings.applySubtitleStyling(_player);

    if (_subtitleDelayMs != 0) {
      await _applyLiveDelay(_subtitleDelayMs / 1000.0);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${variant.language} subtitle loaded (${_currentCues.length} lines)'),
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
    } catch (_) {}

    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null && uri.hasScheme && !(Platform.isWindows && RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(pathOrUrl))) {
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
      print('[PlayerScreen] applyLiveDelay error: $e');
    }
  }

  Future<void> _saveTextSyncedCues(List<SubCue> syncedCues, double offsetSec) async {
    _currentCues = syncedCues;
    _subtitleDelayMs = 0.0; // Reset live delay since timestamps are now permanently baked into cues
    if (_currentSubtitlePath != null) {
      final content = _currentSubFormat == SubFormat.vtt
          ? SubtitleParser.toVtt(syncedCues)
          : SubtitleParser.toSrt(syncedCues);
      final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
      final cleanBase = _currentSubtitlePath!.replaceAll(
        RegExp(r'(_delayed.*|_synced.*)?\.(srt|vtt)$', caseSensitive: false),
        '',
      );
      final newPath = '${cleanBase}_synced_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(newPath).writeAsString(content, flush: true);
      _currentSubtitlePath = newPath;
      final resolvedUri = _resolveSubtitleUri(newPath);
      _player.setSubtitleTrack(SubtitleTrack.uri(resolvedUri));
      _setSubtitleScale(_subtitleScale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtitle timing synchronized and saved!')),
        );
      }
    }
  }

  void _onControllerError(dynamic err) {
    if (!mounted) return;
    final errorMsg = err.toString();
    print('[PlayerScreen ERROR] Player error: $errorMsg');

    // Ignore non-fatal subtitle track loading errors so video playback is not interrupted
    final lower = errorMsg.toLowerCase();
    if (lower.contains('can not open external file') ||
        lower.contains('subtitle') ||
        lower.contains('sub-add') ||
        lower.contains('.srt') ||
        lower.contains('.vtt') ||
        lower.contains('.ass')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load subtitle: $errorMsg'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
      setState(() {
        _isLoading = false;
        _showSourcesPanel = true;
        _sourcesEpisode = _currentEpisode;
        _sourcesErrorMessage = 'Playback error: $errorMsg. Please select another source below.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Playback error: $errorMsg';
      _fatalError = 'Playback error: $errorMsg';
    });
  }

  /// Re-runs stream setup after a failure, so a transient error (a dead CDN
  /// link, a stalled torrent handshake) does not require leaving the player.
  Future<void> _retryPlayback() async {
    if (!mounted) return;
    setState(() {
      _fatalError = null;
      _isLoading = true;
      _statusMessage = 'Retrying...';
    });
    await _initStream();
  }

  Widget _buildFatalErrorView() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white70, size: 44),
            const SizedBox(height: 16),
            const Text(
              'This source failed to play',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                _fatalError ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _retryPlayback,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PlayerTheme.accent,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Pick another source'),
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
    final clamped = ((vol * 100).round() / 100.0).clamp(0.0, PlayerVolumeControl.maxVolume);
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

  void _seekRelative(Duration offset) {
    final cur = _player.state.position;
    final dur = _player.state.duration;
    final target = cur + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    _player.seek(clamped);
    _startHideControlsTimer();
  }

  void _toggleEpisodesPanel() {
    setState(() {
      _showEpisodesPanel = !_showEpisodesPanel;
      if (_showEpisodesPanel) {
        _showSourcesPanel = false;
        _activeMenu = null;
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
      _statusMessage = 'Buffering S$sNum:E$epNum - ${newEpisode.title.isNotEmpty ? newEpisode.title : "Episode $epNum"}...';
      _showEpisodesPanel = false;
      _showSourcesPanel = false;
      _activeMenu = null;
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
        imdbId: (detail != null && detail.id.startsWith('tt')) ? detail.id : null,
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

  void _updateDiscordRpc({bool? isPaused}) {
    final paused = isPaused ?? !_isPlaying;
    final detail = widget.detail;
    final episode = _currentEpisode;
    final title = detail?.name ?? _currentTitle;
    final poster = widget.backdropUrl ?? detail?.poster ?? detail?.background;

    final type = (detail?.type ?? '').toLowerCase();
    final isAnime = type == 'anime' || (detail == null && _currentTitle.toLowerCase().contains('episode') && episode != null);
    final isSeries = type == 'series' || type == 'tv' || (!isAnime && episode != null);

    if (isAnime) {
      DiscordRpcService.instance.setWatchingAnime(
        title: title,
        season: episode?.season,
        episode: episode?.episode,
        episodeTitle: episode?.title,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    } else if (isSeries) {
      DiscordRpcService.instance.setWatchingSeries(
        title: title,
        season: episode?.season,
        episode: episode?.episode,
        episodeTitle: episode?.title,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    } else {
      DiscordRpcService.instance.setWatchingMovie(
        title: title,
        year: detail?.year,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _progressSaveTimer?.cancel();
    _volumeHudTimer?.cancel();
    _audioHudTimer?.cancel();
    _savePlaybackProgress();
    WakelockPlus.disable();
    _hideTimer?.cancel();
    _gestureIndicatorTimer?.cancel();
    _autoNextTimer?.cancel();
    _focusNode.dispose();
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
    _logoAnimController.dispose();
    TorrentStreamService().cleanup();
    WindowService.instance.exitFullscreen();
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _onPlayerSettingsChanged() {
    PlayerSettings.applyToPlayer(_player);
  }

  DateTime? _lastScreenTapTime;

  void _handleScreenTap() {
    final now = DateTime.now();
    if (_lastScreenTapTime != null &&
        now.difference(_lastScreenTapTime!) < const Duration(milliseconds: 280)) {
      _lastScreenTapTime = null;
      WindowService.instance.toggleFullscreen();
    } else {
      _lastScreenTapTime = now;
      _toggleControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        WindowService.instance.exitFullscreen();
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
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
                _applyVolume((_volume + 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
                _applyVolume((_volume - 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                _toggleMute(showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.keyK) {
                _togglePlayPause();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.keyJ) {
                _seekRelative(const Duration(seconds: -10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.keyL) {
                _seekRelative(const Duration(seconds: 10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                WindowService.instance.toggleFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(context);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
                final next = (_volume + delta).clamp(0.0, PlayerVolumeControl.maxVolume);
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
                onTap: _handleScreenTap,
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPlayerBody(),
                    // Brightness overlay (dim the screen)
                    if (_brightness < 1.0)
                      IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: (1.0 - _brightness) * 0.9,
                          ),
                        ),
                      ),
                    // Gesture indicator overlay
                    if (_showGestureIndicator)
                      IgnorePointer(
                        child: Center(
                          child: _buildGestureIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_gestureIndicatorIcon, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          Text(
            _gestureIndicatorLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _gestureIndicatorValue,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7C5CFF)),
              ),
            ),
          ),
        ],
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
        if (_fatalError != null)
          Positioned.fill(child: _buildFatalErrorView()),

        // Video Player
        Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.logoUrl != null)
                      AnimatedBuilder(
                        animation: _logoAnimController,
                        builder: (context, child) {
                          final val = _logoAnimController.value;
                          return Opacity(
                            opacity: 0.3 + (val * 0.7),
                            child: Transform.scale(
                              scale: 0.95 + (val * 0.1),
                              child: child,
                            ),
                          );
                        },
                        child: Image.network(
                          widget.logoUrl!,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: PlayerTheme.accent),
                    const SizedBox(height: 32),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                )
              : SizedBox.expand(
                  child: ValueListenableBuilder<int>(
                    valueListenable: PlayerSettings.changeNotifier,
                    builder: (context, _, __) {
                      return mk.Video(
                        controller: _videoController,
                        fit: _videoFit,
                        controls: mk.NoVideoControls,
                        subtitleViewConfiguration: PlayerSettings.getSubtitleViewConfiguration(),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _handleDownloadMedia() async {
    final mediaId = widget.detail?.id ?? _currentTitle;
    final season = _currentEpisode?.season;
    final episode = _currentEpisode?.episode;

    final existing = DownloadService.instance.tasksNotifier.value.where((t) {
      if (t.mediaId == mediaId && t.season == season && t.episode == episode) {
        return true;
      }
      return false;
    }).firstOrNull;

    if (existing != null) {
      if (existing.status == DownloadStatus.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download already in progress in background.')),
        );
        return;
      } else if (existing.status == DownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This media is already downloaded.')),
        );
        return;
      }
    }

    try {
      String? customDir;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        customDir = await DownloadPathHelper.pickDownloadsDirectory();
        if (customDir == null) {
          // User canceled folder selection
          return;
        }
      }

      await DownloadService.instance.startDownload(
        title: widget.detail?.name ?? _currentTitle,
        mediaId: mediaId,
        type: widget.detail?.type ?? (widget.detail?.videos.isNotEmpty == true ? 'series' : 'movie'),
        season: season,
        episode: episode,
        episodeTitle: _currentEpisode?.title,
        posterUrl: widget.detail?.poster,
        backdropUrl: widget.detail?.background,
        year: widget.detail?.year,
        source: _currentSource,
        customDownloadDir: customDir,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started in background. Track progress in Downloads tab.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed to start: $e')),
        );
      }
    }
  }

  Widget _buildControlsOverlay() {
    final buffered = _buffered;

    final episodeTitle = _currentEpisode?.title;
    final episodeSubtitle = _currentEpisode != null
        ? 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}'
        : widget.detail?.year;

    final isOfflineFile = _currentSource.name == 'Downloaded';

    return Stack(
      children: [
        // Outside Tap Barrier to dismiss active floating menu
        if (_activeMenu != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _activeMenu = null),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Top Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: (!_showControls && !_isLoading) || _showSubSyncBar || _showTextSyncOverlay,
            child: AnimatedOpacity(
              opacity: (_showControls || _isLoading) && !_showSubSyncBar && !_showTextSyncOverlay
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
                child: ValueListenableBuilder<List<DownloadTask>>(
                  valueListenable: DownloadService.instance.tasksNotifier,
                  builder: (context, tasks, _) {
                    final mediaId = widget.detail?.id ?? _currentTitle;
                    final season = _currentEpisode?.season;
                    final episode = _currentEpisode?.episode;
                    final isDownloading = tasks.any((t) =>
                        t.mediaId == mediaId &&
                        t.season == season &&
                        t.episode == episode &&
                        t.status == DownloadStatus.downloading);

                    return PlayerTopBar(
                      title: widget.detail?.name ?? _currentTitle,
                      subtitle: episodeSubtitle,
                      quality: _currentSource.name,
                      onDownload: (_isLoading || isOfflineFile) ? null : _handleDownloadMedia,
                      isDownloading: isDownloading,
                      onToggleEpisodes: (!_isLoading && widget.detail?.videos.isNotEmpty == true)
                          ? _toggleEpisodesPanel
                          : null,
                      isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                      onBack: () {
                        WindowService.instance.exitFullscreen();
                        Navigator.pop(context);
                      },
                    );
                  },
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
              child: IgnorePointer(
                ignoring: (!_showControls && _activeMenu == null) || _showTextSyncOverlay,
                child: AnimatedOpacity(
                  opacity: (_showControls || _activeMenu != null) && !_showTextSyncOverlay ? 1.0 : 0.0,
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
                    child: ValueListenableBuilder<bool>(
                      valueListenable: WindowService.instance.isFullscreenNotifier,
                      builder: (context, isFs, _) {
                        return PlayerTransport(
                          isPlaying: _isPlaying,
                          position: _position,
                          duration: _duration,
                          buffered: buffered,
                          positionListenable: _positionNotifier,
                          bufferedListenable: _bufferNotifier,
                          skipSegments: _skipSegments,
                          volume: _volume,
                          isMuted: _isMuted || _volume == 0,
                          playbackRate: _playbackRate,
                          isSubtitlesActive: _isSubtitleEnabled && _currentSubtitleVariant != null,
                          isAudioActive: _selectedAudioTrackIndex > 0,
                          isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                          isFullscreen: isFs,
                          onToggleEpisodes: (widget.detail?.videos.isNotEmpty == true)
                              ? _toggleEpisodesPanel
                              : null,
                          onPlayPause: () {
                            _togglePlayPause();
                          },
                          onSeek: (pos) => _player.seek(pos),
                          onSeekBack10: () {
                            _seekRelative(const Duration(seconds: -10));
                          },
                          onSeekForward10: () {
                            _seekRelative(const Duration(seconds: 10));
                          },
                          onVolumeChanged: (vol) => _applyVolume(vol),
                          onToggleMute: () => _toggleMute(),
                          onToggleAspectMenu: () => _toggleMenu('aspect'),
                          onToggleSpeedMenu: () => _toggleMenu('speed'),
                          onToggleAudioMenu: () => _toggleMenu('audio'),
                          onToggleSubtitleMenu: () => _toggleMenu('subtitle'),
                          onToggleFullscreen: () => WindowService.instance.toggleFullscreen(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Floating Subtitle Menu Popover
          if (_activeMenu == 'subtitle' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 44
                  : (MediaQuery.sizeOf(context).width < 560
                      ? 60
                      : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96)),
              right: MediaQuery.sizeOf(context).width < 560
                  ? 8
                  : (MediaQuery.sizeOf(context).width < 680 ? 12 : 28),
              left: MediaQuery.sizeOf(context).width < 560 ? 8 : null,
              child: Align(
                alignment: MediaQuery.sizeOf(context).width < 560
                    ? Alignment.bottomCenter
                    : Alignment.bottomRight,
                child: PlayerSubtitleMenu(
                  groups: _subtitleGroups,
                  embeddedSubtitles: _embeddedSubtitles,
                  selectedEmbeddedIndex: _selectedEmbeddedSubtitleIndex,
                  selectedVariant: _currentSubtitleVariant,
                  isSubtitleEnabled: _isSubtitleEnabled,
                  movieTitle: widget.detail?.name ?? widget.title,
                  imdbId: widget.detail?.id,
                  season: _currentEpisode?.season,
                  episode: _currentEpisode?.episode,
                  year: widget.detail?.year != null ? int.tryParse(widget.detail!.year!) : null,
                  delaySec: _subtitleDelayMs / 1000.0,
                  onSelectVariant: (v) {
                    if (v != null) _loadSubtitle(v);
                  },
                  onSelectEmbedded: (emb) => _selectEmbeddedSubtitle(emb),
                  onToggleOff: _disableSubtitles,
                  onOpenSyncBar: () {
                    if (_selectedEmbeddedSubtitleIndex != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subtitle sync is not supported for embedded subtitles.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _activeMenu = null;
                      _showSubSyncBar = true;
                    });
                  },
                  onOpenStyleBar: () {
                    setState(() => _activeMenu = 'style');
                  },
                  onOpenTextSync: () {
                    if (_selectedEmbeddedSubtitleIndex != null || _currentSubtitlePath == null || _currentCues.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Speech sync requires an external subtitle file.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _activeMenu = null;
                      _showTextSyncOverlay = true;
                    });
                  },
                  onClose: () => setState(() => _activeMenu = null),
                ),
              ),
            ),

          // Floating Audio Menu Popover
          if (_activeMenu == 'audio' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerAudioMenu(
                audioTracks: _audioTracks,
                selectedIndex: _selectedAudioTrackIndex,
                delaySec: _audioDelaySec,
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
                  } catch (_) {}
                  final match = _audioTracks.where((t) => t.index == idx).firstOrNull;
                  _showAudioHudToast(match?.title ?? 'Track $idx');
                },
                onDelayChanged: (sec) {
                  setState(() => _audioDelaySec = sec);
                  try {
                    final np = _player.platform as dynamic;
                    np.setProperty('audio-delay', sec.toString());
                  } catch (_) {}
                  _showAudioHudToast('AUDIO SYNC: ${sec > 0 ? "+" : ""}${sec.toStringAsFixed(2)}s');
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Speed Menu Popover
          if (_activeMenu == 'speed' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerSpeedMenu(
                currentRate: _playbackRate,
                onRateSelected: (rate) {
                  setState(() => _playbackRate = rate);
                  _player.setRate(rate);
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Aspect Ratio Popover
          if (_activeMenu == 'aspect' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerAspectMenu(
                currentFit: _videoFit,
                subtitleScale: _subtitleScale,
                onFitSelected: (fit) => setState(() => _videoFit = fit),
                onSubtitleScaleChanged: _setSubtitleScale,
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Subtitle Appearance & Customization Modal
          if (_activeMenu == 'style' && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _activeMenu = null),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap through
                    child: PlayerSubStyleModal(
                      player: _player,
                      onClose: () => setState(() => _activeMenu = null),
                    ),
                  ),
                ),
              ),
            ),

          // Top Floating Live SubSyncBar
          if (_showSubSyncBar && !_isLoading && _selectedEmbeddedSubtitleIndex == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 0,
              right: 0,
              child: SubSyncBar(
                delaySec: _subtitleDelayMs / 1000.0,
                isTextSyncAvailable: _selectedEmbeddedSubtitleIndex == null && _currentSubtitlePath != null && _currentCues.isNotEmpty,
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
          if (_showEpisodesPanel && widget.detail?.videos.isNotEmpty == true && !_isLoading)
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
                      cachedSources: _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'],
                      onSourcesLoaded: (sources) {
                        _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'] = sources;
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
          if (_showTextSyncOverlay && !_isLoading && _currentCues.isNotEmpty && _selectedEmbeddedSubtitleIndex == null)
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
          if (_showSkipButton && _activeSkipSegment != null && !_isLoading && !_showTextSyncOverlay && !_showEpisodesPanel && !_showSourcesPanel)
            Positioned(
              bottom: (_showControls || _activeMenu != null)
                  ? (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 108 : 128))
                  : (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 22 : 36)),
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
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
            Positioned.fill(
              child: IgnorePointer(
                child: _buildVolumeHud(),
              ),
            ),

          // Center Heads-Up Audio Display (HUD)
          if (_showAudioHud)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildAudioHud(),
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBoosting
                ? boostColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isBoosting ? boostColor.withValues(alpha: 0.28) : Colors.black54,
              blurRadius: 30,
              spreadRadius: 2,
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
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _isMuted ? 'Muted' : '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isBoosting) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boostColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: boostColor),
                        const SizedBox(width: 2),
                        Text(
                          _volume > 1.75 ? 'MAX BOOST' : 'BOOST',
                          style: TextStyle(
                            color: boostColor,
                            fontSize: 10.5,
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
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (effectiveVol / PlayerVolumeControl.maxVolume).clamp(0.0, 1.0),
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.audiotrack_rounded,
              color: Color(0xFF00D2EF),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              _audioHudText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
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
    return ValueListenableBuilder<bool>(
      valueListenable: GlassSettings.enabled,
      builder: (context, enabled, _) {
        if (enabled) {
          return LiquidGlassView(
            realTimeCapture: _showControls && !_isLoading,
            useSync: true,
            pixelRatio: 0.85,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            regionCapture: true,
            backgroundWidget: _buildBackgroundStack(),
            child: _buildControlsOverlay(),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: _buildBackgroundStack()),
            RepaintBoundary(child: _buildControlsOverlay()),
          ],
        );
      },
    );
  }
}
