import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/iptv/iptv_models.dart';
import '../../services/iptv/custom_channels_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/playback_coordinator.dart';
import '../../services/player/player_settings.dart';
import '../../services/window/window_service.dart';
import '../../services/cast/cast_service.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../widgets/player/player_cast_sheet.dart';
import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_aspect_menu.dart';
import '../../widgets/player/player_settings_menu.dart';
import '../../widgets/player/player_center_controls.dart';
import '../../widgets/player/player_volume_control.dart';

class IptvPlayerPage extends StatefulWidget {
  final HardcodedChannel channel;
  final List<ChannelHit> hits;
  final int initialHitIndex;
  final bool? isLive;
  final String? categoryTitle;

  const IptvPlayerPage({
    super.key,
    required this.channel,
    required this.hits,
    this.initialHitIndex = 0,
    this.isLive,
    this.categoryTitle,
  });

  @override
  State<IptvPlayerPage> createState() => _IptvPlayerPageState();
}

class _IptvPlayerPageState extends State<IptvPlayerPage>
    with SingleTickerProviderStateMixin {
  late final Player _player = Player(
    configuration: PlayerSettings.getMediaKitPlayerConfiguration(),
  );
  late final VideoController _videoController = VideoController(
    _player,
    configuration: PlayerSettings.getVideoControllerConfiguration(),
  );
  final List<StreamSubscription> _subscriptions = [];

  late int _activeHitIndex;
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration?> _bufferedNotifier = ValueNotifier<Duration?>(
    null,
  );

  String _statusMessage = 'Connecting to stream…';
  bool _showControls = true;
  bool _showSourcesDrawer = false;
  Timer? _hideControlsTimer;
  Timer? _watchdogTimer;
  late final ScrollController _sourcesScrollController;

  BoxFit _videoFit = BoxFit.contain;
  /// Which popover is open, by the same names the Movies/Series/Anime
  /// player uses: 'settings' for the gear's root list, 'aspect' for the
  /// panel it steps into. A bool could only ever describe one menu, which
  /// is why this page had a bespoke aspect-ratio pill instead of the gear
  /// every other player has.
  String? _activeMenu;
  bool _showAspectHud = false;
  String _aspectHudText = '';
  Timer? _aspectHudTimer;
  double _volume = 1.0;
  double _lastVolumeBeforeMute = 1.0;
  bool _isMuted = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;

  // Stream watchdog metrics
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionChange = DateTime.now();
  int _retryCount = 0;

  /// Bumped on every [_initPlayer] entry so a call that has been superseded
  /// can bail instead of finishing.
  ///
  /// Three things call `_initPlayer` and none of them used to coordinate: the
  /// freeze watchdog every 3s, `_switchSource` when the user picks another
  /// source, and the auto-failover timer after an error. The watchdog's
  /// `!_isLoading` check only stopped it re-entering itself. A source tap
  /// during a failover ran two `player.open()` calls against the same
  /// long-lived player, each having read `_activeHitIndex` at its own start --
  /// so whichever open landed last decided which channel you got, and the
  /// first to finish cleared `_isLoading` while the second was still
  /// buffering.
  int _initGeneration = 0;

  bool get _isLiveStream {
    if (widget.isLive != null) return widget.isLive!;
    final currentHit =
        widget.hits.isNotEmpty && _activeHitIndex < widget.hits.length
        ? widget.hits[_activeHitIndex]
        : null;
    final kind = currentHit?.stream.kind.toLowerCase();
    if (kind == 'movie' || kind == 'series' || kind == 'vod') return false;
    final cat = widget.channel.category.toLowerCase();
    if (cat.contains('movie') ||
        cat.contains('series') ||
        cat.contains('vod') ||
        cat.contains('show')) {
      return false;
    }
    return true;
  }

  bool get _isCategoryList {
    if (widget.hits.length <= 1) return false;
    if (widget.categoryTitle != null && widget.categoryTitle!.isNotEmpty) {
      return true;
    }
    return widget.hits.first.stream.streamId !=
        widget.hits.last.stream.streamId;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _activeHitIndex = widget.initialHitIndex.clamp(0, widget.hits.length - 1);
    _sourcesScrollController = ScrollController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    PlayerSettings.applyToPlayer(_player);
    PlayerSettings.changeNotifier.addListener(_onPlayerSettingsChanged);

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (mounted && _isPlaying != playing) {
          setState(() => _isPlaying = playing);
        }
      }),
      _player.stream.position.listen((pos) {
        _position = pos;
        _positionNotifier.value = pos;
        _onPlaybackUpdate();
      }),
      _player.stream.duration.listen((dur) {
        if (mounted && _duration != dur) setState(() => _duration = dur);
      }),
      _player.stream.buffer.listen((buf) {
        _bufferedNotifier.value = buf;
      }),
      _player.stream.error.listen((error) {
        debugPrint('[IPTV Player Error] $error');
      }),
    ]);

    _initPlayer();
    if (_isLiveStream) {
      _startWatchdog();
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    PlayerSettings.changeNotifier.removeListener(_onPlayerSettingsChanged);
    WakelockPlus.disable();
    _hideControlsTimer?.cancel();
    _watchdogTimer?.cancel();
    _volumeHudTimer?.cancel();
    _aspectHudTimer?.cancel();
    _sourcesScrollController.dispose();
    PlaybackCoordinator.release('iptv:${widget.channel.id}');
    _positionNotifier.dispose();
    _bufferedNotifier.dispose();
    _player.dispose();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowService.instance.exitFullscreen();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _onPlaybackUpdate() {
    final state = _player.state;
    PlaybackCoordinator.setProgress(state.position, state.duration);
    PlaybackCoordinator.setPlaying(state.playing);
  }

  void _onPlayerSettingsChanged() {
    PlayerSettings.applyToPlayer(_player);
  }

  Future<void> _initPlayer() async {
    final myGeneration = ++_initGeneration;
    DiscordRpcService.instance.setWatchingLiveTv(
      channelName: widget.channel.name,
      logoUrl: widget.channel.iconUrl,
    );
    if (widget.hits.isEmpty) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'No stream sources available for this channel.';
      });
      return;
    }

    final currentHit = widget.hits[_activeHitIndex];
    final streamUrl = currentHit.streamUrl;

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Buffering ${currentHit.stream.name.isNotEmpty ? currentHit.stream.name : currentHit.portal.name}…';
    });

    try {
      await PlayerSettings.applyToPlayer(_player, isLive: true);
      if (myGeneration != _initGeneration) return;
      // Volume before open: open() starts playback immediately, so setting it
      // afterwards let a muted channel blast a moment of full-volume audio.
      _player.setVolume(_isMuted ? 0.0 : _volume * 100.0);

      await _player.open(
        Media(
          streamUrl,
          httpHeaders: const {
            'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
            'Accept': '*/*',
            'Connection': 'keep-alive',
          },
        ),
        play: true,
      );
      // A newer call is already opening its own stream; leaving this one to
      // finish would overwrite its coordinator registration and its loading
      // state with a channel the user has moved on from.
      if (myGeneration != _initGeneration) return;

      // Ensure only one source plays app-wide: stop any other active source.
      // Keyed by channel (not by hit/source), so switching sources or
      // reconnecting the same channel doesn't re-register with the
      // coordinator.
      PlaybackCoordinator.activate(
        'iptv:${widget.channel.id}',
        () => _player.pause(),
        kind: 'video',
        title: widget.channel.name,
        subtitle: widget.categoryTitle ?? widget.channel.category,
        coverUrl: widget.channel.iconUrl ?? widget.channel.backdropUrl,
        onTogglePlayPause: () {
          if (_player.state.playing) {
            _player.pause();
          } else {
            _player.play();
          }
        },
        onSeek: (position) => _player.seek(position),
        // See PlaybackCoordinator.activate's onShutdownDispose doc -- a
        // native window close never runs this screen's own dispose(),
        // which is the only place _player normally gets disposed.
        // Believed to be ROADMAP #12's "Unknown hard error" on close.
        onShutdownDispose: () => _player.dispose(),
      );

      await PlayerSettings.applyToPlayer(_player, isLive: true);

      if (!mounted || myGeneration != _initGeneration) return;
      setState(() {
        _isLoading = false;
        _retryCount = 0;
        _lastPosition = Duration.zero;
        _lastPositionChange = DateTime.now();
      });

      _startHideControlsTimer();
    } catch (e) {
      debugPrint('[IPTV Player Error] $e');
      // A superseded call's failure is not this channel's failure -- letting
      // it through would show an error over a stream that is loading fine,
      // and start a failover chain for a source nobody is watching.
      if (!mounted || myGeneration != _initGeneration) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Feed failed. Trying alternative source…';
      });

      // Auto-failover to next hit if available
      if (widget.hits.length > 1 && _retryCount < 3) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted || myGeneration != _initGeneration) return;
          final nextIdx = (_activeHitIndex + 1) % widget.hits.length;
          _switchSource(nextIdx);
        });
      }
    }
  }

  void _switchSource(int index) {
    if (index < 0 || index >= widget.hits.length) return;
    setState(() {
      _activeHitIndex = index;
      _showSourcesDrawer = false;
    });
    _initPlayer();
  }

  void _openSourcesDrawer() {
    setState(() => _showSourcesDrawer = true);
    _hideControlsTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sourcesScrollController.hasClients) {
        final targetOffset = (_activeHitIndex * 62.0) - 120.0;
        final maxOffset = _sourcesScrollController.position.maxScrollExtent;
        final safeOffset = targetOffset.clamp(0.0, maxOffset);
        _sourcesScrollController.animateTo(
          safeOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      final isPlaying = _isPlaying;
      final currentPos = _position;

      if (isPlaying && currentPos != _lastPosition) {
        _lastPosition = currentPos;
        _lastPositionChange = DateTime.now();
      }

      // If live and position frozen for > 10 seconds, trigger reconnect
      if (_isLiveStream &&
          isPlaying &&
          DateTime.now().difference(_lastPositionChange).inSeconds > 10 &&
          !_isLoading) {
        debugPrint('[IPTV Watchdog] Stream frozen > 10s — reconnecting…');
        _initPlayer();
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_showSourcesDrawer) {
        setState(() => _showControls = false);
      }
    });
  }

  DateTime? _lastScreenTapTime;

  /// Taps on the video surface, detected by hand rather than with
  /// `onTap` + `onDoubleTap` on the same detector.
  ///
  /// Those two together make Flutter wait to see whether a second tap
  /// follows before firing either, so every single tap -- the common one,
  /// the one that just reveals the controls -- landed with a visible delay.
  /// Movies/Series/Anime already detect this by hand for exactly that
  /// reason; this is the same 280ms window, so both players answer a tap at
  /// the same speed.
  void _handleScreenTap(TapDownDetails details) {
    final now = DateTime.now();
    if (_lastScreenTapTime != null &&
        now.difference(_lastScreenTapTime!) <
            const Duration(milliseconds: 280)) {
      _lastScreenTapTime = null;
      if (WindowService.instance.isDesktop) {
        WindowService.instance.toggleFullscreen();
      }
      return;
    }
    _lastScreenTapTime = now;
    _toggleControls();
  }

  void _toggleControls() {
    if (_activeMenu != null) {
      setState(() => _activeMenu = null);
      return;
    }
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) {
        _showSourcesDrawer = false;
        _activeMenu = null;
      }
    });
    if (_showControls) _startHideControlsTimer();
  }

  /// Opens the gear, or closes whatever it opened. Same contract as the
  /// Movies/Series/Anime player's `_toggleMenu`.
  void _toggleSettingsMenu() {
    setState(() {
      _activeMenu = _activeMenu == null ? 'settings' : null;
      if (_activeMenu != null) _showSourcesDrawer = false;
    });
    if (_activeMenu != null) {
      _hideControlsTimer?.cancel();
    } else {
      _startHideControlsTimer();
    }
  }

  void _setVideoFit(BoxFit fit) {
    setState(() {
      _videoFit = fit;
      _aspectHudText = _fitLabel(fit);
      _showAspectHud = true;
      _activeMenu = null;
    });
    _aspectHudTimer?.cancel();
    _aspectHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showAspectHud = false);
    });
    _startHideControlsTimer();
  }

  String _fitLabel(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'ASPECT: FIT (CONTAIN)';
      case BoxFit.cover:
        return 'ASPECT: FILL (ZOOM / CROP)';
      case BoxFit.fill:
        return 'ASPECT: STRETCH (FILL)';
      default:
        return 'ASPECT: ${fit.name.toUpperCase()}';
    }
  }

  void _cycleVideoFit() {
    final nextFit = _videoFit == BoxFit.contain
        ? BoxFit.cover
        : (_videoFit == BoxFit.cover ? BoxFit.fill : BoxFit.contain);
    _setVideoFit(nextFit);
  }

  void _seekRelative(int seconds) {
    if (_isLiveStream) return;
    final cur = _position;
    final max = _duration;
    final target = cur + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > max ? max : target);
    _player.seek(clamped);
    _startHideControlsTimer();
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _startHideControlsTimer();
  }

  /// The stream currently playing, as a URL a Cast receiver on the network
  /// could fetch. Null when there is no hit to play, which is also when
  /// there is nothing to cast.
  String? get _castableUrl {
    if (widget.hits.isEmpty) return null;
    final url = widget.hits[_activeHitIndex].streamUrl;
    // A portal stream is already a plain HTTP(S) URL -- unlike the VOD
    // player, there is no torrent or local-file case to rule out here.
    return url.isEmpty ? null : url;
  }

  bool get _canCast =>
      CastService.isSupported &&
      !_isLoading &&
      CastService.canCastUrl(_castableUrl);

  void _handleCast() {
    final url = _castableUrl;
    if (url == null) return;
    PlayerCastSheet.show(
      context,
      title: widget.channel.name,
      streamUrl: url,
      posterUrl: widget.channel.iconUrl,
      isLive: _isLiveStream,
    );
  }

  /// True when this page was opened from a portal stream rather than from a
  /// channel tile. The ad-hoc channel built for a stream carries the
  /// stream's own id, which is not in the catalogue -- a real channel's is.
  bool get _canSaveAsChannel =>
      HardcodedChannels.byId(widget.channel.id) == null;

  bool _savedAsChannel = false;

  Future<void> _saveAsChannel() async {
    final saved = await CustomChannelsService.addFromStream(
      streamName: widget.channel.name,
      category: widget.categoryTitle ?? widget.channel.category,
    );
    if (!mounted) return;
    setState(() => _savedAsChannel = saved != null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Could not save this stream as a channel'
              : 'Saved "${saved.name}" to Live TV',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _adjustVolume(double delta) =>
      _applyVolume((_volume + delta).clamp(0.0, PlayerVolumeControl.maxVolume));

  /// Sets the volume, matching the VOD player's semantics rather than this
  /// page's old 0-100% Slider: the same 250% boost ceiling, the same
  /// "0 means muted" rule, the same rounding.
  void _applyVolume(double vol) {
    final clamped = ((vol * 100).round() / 100.0).clamp(
      0.0,
      PlayerVolumeControl.maxVolume,
    );
    setState(() {
      _volume = clamped;
      _isMuted = clamped == 0;
      _showVolumeHud = true;
    });
    _player.setVolume(clamped * 100.0);
    _restartVolumeHud();
  }

  void _toggleMute() {
    setState(() {
      if (_volume > 0 && !_isMuted) {
        _lastVolumeBeforeMute = _volume;
        _isMuted = true;
        _player.setVolume(0.0);
      } else {
        // Unmuting a stream that was left at zero has to land somewhere
        // audible, or the button looks broken.
        _volume = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 0.5;
        _isMuted = false;
        _player.setVolume(_volume * 100.0);
      }
      _showVolumeHud = true;
    });
    _restartVolumeHud();
  }

  void _restartVolumeHud() {
    _volumeHudTimer?.cancel();
    _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
    _startHideControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final currentHit = widget.hits.isNotEmpty
        ? widget.hits[_activeHitIndex]
        : null;
    final isLive = _isLiveStream;
    final isCategoryList = _isCategoryList;
    final currentTitle = currentHit != null && currentHit.stream.name.isNotEmpty
        ? currentHit.stream.name
        : ch.name;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              !isLive) {
            _seekRelative(-10);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              !isLive) {
            _seekRelative(10);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _adjustVolume(0.05);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _adjustVolume(-0.05);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.pageDown ||
              event.logicalKey == LogicalKeyboardKey.keyN) {
            if (_activeHitIndex + 1 < widget.hits.length) {
              _switchSource(_activeHitIndex + 1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.pageUp ||
              event.logicalKey == LogicalKeyboardKey.keyP) {
            if (_activeHitIndex - 1 >= 0) {
              _switchSource(_activeHitIndex - 1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _toggleMute();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _cycleVideoFit();
            _startHideControlsTimer();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.f11) {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              WindowService.instance.toggleFullscreen();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
                WindowService.instance.isFullscreen) {
              WindowService.instance.exitFullscreen();
            } else {
              Navigator.pop(context);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerSignal: (pointerSignal) {
            // Pointer scroll signals reach every Listener along the hit-test
            // chain, not just the arena winner -- without this guard,
            // scrolling a panel's own list (sources drawer, aspect menu)
            // also changed the volume underneath it.
            if (_showSourcesDrawer || _activeMenu != null) return;
            if (pointerSignal is PointerScrollEvent) {
              if (pointerSignal.scrollDelta.dy < 0) {
                _adjustVolume(0.05); // Scroll up -> Volume up
              } else if (pointerSignal.scrollDelta.dy > 0) {
                _adjustVolume(-0.05); // Scroll down -> Volume down
              }
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // A single tap only reveals/hides the controls overlay; it never
            // toggles playback, because an accidental tap (repositioning the
            // device, wiping the screen) would silently pause a live
            // channel. The dedicated play/pause button is the one
            // deliberate way to do that.
            //
            // Detected by hand -- see _handleScreenTap -- so that the
            // single tap is not held up waiting for a second one.
            onTapDown: _handleScreenTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Surface
                if (!_isLoading)
                  Center(
                    child: SizedBox.expand(
                      child: ValueListenableBuilder<int>(
                        valueListenable: PlayerSettings.changeNotifier,
                        builder: (context, _, __) {
                          return Video(
                            controller: _videoController,
                            fit: _videoFit,
                            controls: NoVideoControls,
                            subtitleViewConfiguration:
                                PlayerSettings.getSubtitleViewConfiguration(),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Center(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),

                // Loading / Buffering Banner
                if (_isLoading)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF7C5CFF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Volume HUD Overlay (when changing volume)
                if (_showVolumeHud)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60D101A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF7C5CFF,
                            ).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C5CFF,
                              ).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMuted || _volume == 0
                                  ? Icons.volume_off_rounded
                                  : (_volume < 0.5
                                        ? Icons.volume_down_rounded
                                        : Icons.volume_up_rounded),
                              color: _isMuted
                                  ? Colors.redAccent
                                  : const Color(0xFF00D2EF),
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 130,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  // Over the full range, boost included --
                                  // at 250% a 0..1 bar would sit pinned at
                                  // the end and stop telling you anything.
                                  value: (_isMuted ? 0.0 : _volume) /
                                      PlayerVolumeControl.maxVolume,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isMuted
                                        ? Colors.redAccent
                                        : const Color(0xFF7C5CFF),
                                  ),
                                  minHeight: 7,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isMuted
                                  ? 'MUTED'
                                  : '${(_volume * 100).toInt()}%',
                              style: TextStyle(
                                color: _isMuted
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Aspect Ratio HUD Overlay (when changing aspect ratio)
                if (_showAspectHud)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60D101A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF7C5CFF,
                            ).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C5CFF,
                              ).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.aspect_ratio_rounded,
                              color: Color(0xFF00D2EF),
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _aspectHudText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Tap anywhere off an open menu to dismiss it -- the same
                // barrier the Movies/Series/Anime player puts behind its
                // popovers, and the reason neither needs a close button.
                if (_activeMenu != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() => _activeMenu = null);
                        _startHideControlsTimer();
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),

                // Controls Overlay
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Top Bar
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xCC000000), Colors.transparent],
                              ),
                            ),
                            child: Row(
                              children: [
                                // The same pill as every button in the
                                // Movies/Series/Anime top bar. These were
                                // bare IconButtons, which is why the two top
                                // bars read as different chrome even once
                                // they carried the same actions.
                                PlayerIconButton(
                                  size: 40,
                                  iconSize: 20,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  tooltip: 'Back',
                                  backgroundColor: const Color(0x22080C12),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLive
                                                  ? const Color(0xFFFF3B30)
                                                  : const Color(0xFF7C5CFF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isLive
                                                  ? 'LIVE'
                                                  : (ch.category.isNotEmpty
                                                        ? ch.category
                                                              .toUpperCase()
                                                        : 'VOD'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              currentTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (currentHit != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          isCategoryList
                                              ? 'Channel ${_activeHitIndex + 1}/${widget.hits.length} · ${currentHit.portal.name}'
                                              : 'Source ${_activeHitIndex + 1}/${widget.hits.length} · ${currentHit.portal.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Cast. Live TV had none at all, while
                                // Movies/Series/Anime have carried one in
                                // this same slot -- and a channel is the
                                // most natural thing to throw at a TV.
                                if (_canCast)
                                  PlayerIconButton(
                                    size: 40,
                                    iconSize: 20,
                                    icon: const Icon(Icons.cast_rounded),
                                    tooltip: 'Cast',
                                    backgroundColor: const Color(0x22080C12),
                                    onPressed: _handleCast,
                                  ),
                                // Save this stream as a Live TV channel.
                                // Only shown for a stream that is not
                                // already one: opened from a portal, the
                                // channel handed to this page is built ad
                                // hoc from the stream and disappears with
                                // the route, so this is the moment the user
                                // can keep it -- and the moment they know
                                // they want to.
                                if (_canSaveAsChannel)
                                  PlayerIconButton(
                                    size: 40,
                                    iconSize: 20,
                                    backgroundColor: const Color(0x22080C12),
                                    active: _savedAsChannel,
                                    activeColor: const Color(0xFF00D2EF),
                                    icon: Icon(
                                      _savedAsChannel
                                          ? Icons.library_add_check_rounded
                                          : Icons.library_add_outlined,
                                    ),
                                    tooltip: _savedAsChannel
                                        ? 'Saved to Live TV'
                                        : 'Save as a Live TV channel',
                                    onPressed: _savedAsChannel
                                        ? null
                                        : _saveAsChannel,
                                  ),
                                // Category Channels / Sources Drawer Toggle
                                if (widget.hits.length > 1)
                                  PlayerIconButton(
                                    size: 40,
                                    iconSize: 20,
                                    backgroundColor: const Color(0x22080C12),
                                    icon: Icon(
                                      isCategoryList
                                          ? Icons.format_list_bulleted_rounded
                                          : Icons.video_library_rounded,
                                    ),
                                    tooltip: isCategoryList
                                        ? (widget.categoryTitle ??
                                              'Category Channels')
                                        : 'Alternative Feeds',
                                    onPressed: _openSourcesDrawer,
                                  ),
                                if (Platform.isWindows ||
                                    Platform.isLinux ||
                                    Platform.isMacOS) ...[
                                  const SizedBox(width: 4),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: WindowService
                                        .instance
                                        .isFullscreenNotifier,
                                    builder: (context, isFullscreen, _) {
                                      return PlayerIconButton(
                                        size: 40,
                                        iconSize: 20,
                                        backgroundColor: const Color(
                                          0x22080C12,
                                        ),
                                        icon: Icon(
                                          isFullscreen
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fullscreen_rounded,
                                        ),
                                        tooltip: isFullscreen
                                            ? 'Exit Fullscreen (F11)'
                                            : 'Fullscreen (F11)',
                                        onPressed: () => WindowService.instance
                                            .toggleFullscreen(),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Centred play/pause -- the same widget, size and
                        // position as Movies/Series/Anime, minus the ±10s
                        // buttons, which have no meaning on a live stream.
                        // It used to be a bare IconButton at the left end of
                        // the bottom bar, which is the single most visible
                        // way this player read as a different app.
                        Center(
                          child: PlayerCenterControls(
                            isPlaying: _isPlaying,
                            onPlayPause: _togglePlayPause,
                            // ±30s, matching Movies/Series/Anime: the
                            // buttons are the bigger jump, the double-tap
                            // zones the small nudge. Null on live, where
                            // seeking has no meaning.
                            onSeekBack30: isLive
                                ? null
                                : () => _seekRelative(-30),
                            onSeekForward30: isLive
                                ? null
                                : () => _seekRelative(30),
                          ),
                        ),

                        // Bottom Bar
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xCC000000), Colors.transparent],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── SEEKBAR (ONLY FOR MOVIES & SHOWS / VOD) ──
                                if (!isLive) ...[
                                  _IptvCustomProgressBar(
                                    player: _player,
                                    positionNotifier: _positionNotifier,
                                    duration: _duration,
                                    bufferedNotifier: _bufferedNotifier,
                                    onSeekStart: () =>
                                        _hideControlsTimer?.cancel(),
                                    onSeekEnd: () => _startHideControlsTimer(),
                                  ),
                                  const SizedBox(height: 6),
                                ] else ...[
                                  // Where the seek bar would be. Without it
                                  // the bar just had a gap, which reads as a
                                  // control that failed to load rather than
                                  // one that does not apply; this says the
                                  // stream is live and there is nothing to
                                  // scrub.
                                  const _LiveEdgeRow(),
                                  const SizedBox(height: 6),
                                ],

                                // Controls Buttons Row. Play/pause is not
                                // here: it is centred over the video like
                                // every other player in the app.
                                Row(
                                  children: [
                                    if (!isLive) ...[
                                      // Position / Duration Readout
                                      ValueListenableBuilder<Duration>(
                                        valueListenable: _positionNotifier,
                                        builder: (context, pos, _) {
                                          return Text(
                                            '${_formatDuration(pos)} / ${_formatDuration(_duration)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'monospace',
                                            ),
                                          );
                                        },
                                      ),
                                    ],

                                    const SizedBox(width: 8),

                                    // The same volume control as every
                                    // other player: one widget, so the mute
                                    // icon, the track and the boost range
                                    // cannot drift. This page had its own
                                    // Slider, capped at 100% where the rest
                                    // of the app boosts to 250% -- which
                                    // matters more here than anywhere, since
                                    // portal streams are often quiet.
                                    PlayerVolumeControl(
                                      volume: _volume,
                                      isMuted: _isMuted || _volume == 0,
                                      onVolumeChanged: _applyVolume,
                                      onToggleMute: _toggleMute,
                                    ),

                                    const Spacer(),

                                    // The same gear, in the same corner of
                                    // the same bar, as Movies/Series/Anime.
                                    // This was a bespoke bordered pill
                                    // reading FIT/ZOOM/STRETCH -- the last
                                    // control on this page that had no
                                    // counterpart in the other player. The
                                    // menu behind it is shorter, because a
                                    // live stream has fewer settings, which
                                    // is the whole intended difference.
                                    PlayerIconButton(
                                      size: 40,
                                      iconSize: 20,
                                      icon: const Icon(Icons.settings_rounded),
                                      tooltip: 'Settings',
                                      active: _activeMenu != null,
                                      backgroundColor: const Color(0x22080C12),
                                      onPressed: _toggleSettingsMenu,
                                    ),

                                    // Fullscreen toggle on desktop
                                    if (Platform.isWindows ||
                                        Platform.isLinux ||
                                        Platform.isMacOS) ...[
                                      const SizedBox(width: 8),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: WindowService
                                            .instance
                                            .isFullscreenNotifier,
                                        builder: (context, isFullscreen, _) {
                                          return PlayerIconButton(
                                            size: 40,
                                            iconSize: 20,
                                            backgroundColor: const Color(
                                              0x22080C12,
                                            ),
                                            icon: Icon(
                                              isFullscreen
                                                  ? Icons
                                                        .fullscreen_exit_rounded
                                                  : Icons.fullscreen_rounded,
                                            ),
                                            tooltip: isFullscreen
                                                ? 'Exit Fullscreen (F11)'
                                                : 'Fullscreen (F11)',
                                            onPressed: () => WindowService
                                                .instance
                                                .toggleFullscreen(),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // The gear's root list. Shorter than the other player's --
                // no playback speed on a live feed, and no subtitle rows
                // until a portal stream carries subtitles -- which is the
                // intended relationship between the two: same panel, fewer
                // rows.
                if (_activeMenu == 'settings')
                  PlayerMenuAnchor(
                    child: PlayerSettingsMenu(
                      currentRate: 1.0,
                      aspectLabel: switch (_videoFit) {
                        BoxFit.cover => 'Fill',
                        BoxFit.fill => 'Stretch',
                        _ => 'Fit',
                      },
                      onTapAspect: () => setState(() => _activeMenu = 'aspect'),
                    ),
                  ),

                // Floating Aspect Ratio Popover
                if (_activeMenu == 'aspect')
                  PlayerMenuAnchor(
                    child: PlayerAspectMenu(
                      onBack: () => setState(() => _activeMenu = 'settings'),
                      currentFit: _videoFit,
                      subtitleScale: PlayerSettings.subScale.value,
                      onFitSelected: (fit) => _setVideoFit(fit),
                      onSubtitleScaleChanged: (scale) {
                        PlayerSettings.setSubScale(scale, player: _player);
                      },
                      onClose: () => setState(() => _activeMenu = null),
                    ),
                  ),

                // Channels / Feeds Side Drawer
                if (_showSourcesDrawer)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: 360,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xF2080A10),
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFF1E2336),
                            width: 1.2,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 24,
                            offset: Offset(-6, 0),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCategoryList
                                    ? Icons.format_list_bulleted_rounded
                                    : Icons.tune_rounded,
                                color: const Color(0xFF7C5CFF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.categoryTitle ??
                                      (isCategoryList
                                          ? 'Category Channels'
                                          : 'Stream Feeds'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7C5CFF,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.hits.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF9D4EDD),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _showSourcesDrawer = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              controller: _sourcesScrollController,
                              itemCount: widget.hits.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final hit = widget.hits[index];
                                final isSelected = index == _activeHitIndex;
                                final numFormatted = (index + 1)
                                    .toString()
                                    .padLeft(3, '0');

                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _switchSource(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF7C5CFF,
                                              ).withValues(alpha: 0.25)
                                            : Colors.white.withValues(
                                                alpha: 0.04,
                                              ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF7C5CFF)
                                              : Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Number
                                          SizedBox(
                                            width: 28,
                                            child: Text(
                                              numFormatted,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFF00E5FF)
                                                    : Colors.white30,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // Icon / Logo
                                          Container(
                                            width: 38,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF080A10),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFF1E2336),
                                              ),
                                            ),
                                            child: hit.stream.icon.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                    child: CachedNetworkImage(
                                                      imageUrl: hit.stream.icon,
                                                      fit: BoxFit.contain,
                                                      memCacheWidth: 64,
                                                      errorWidget: (_, _, _) => Icon(
                                                        isLive
                                                            ? Icons
                                                                  .live_tv_rounded
                                                            : Icons
                                                                  .movie_rounded,
                                                        color: Colors.white38,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  )
                                                : Icon(
                                                    isLive
                                                        ? Icons.live_tv_rounded
                                                        : Icons.movie_rounded,
                                                    color: Colors.white38,
                                                    size: 16,
                                                  ),
                                          ),

                                          const SizedBox(width: 10),

                                          // Channel Title
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hit.stream.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  hit
                                                          .portal
                                                          .portal
                                                          .username
                                                          .isNotEmpty
                                                      ? hit
                                                            .portal
                                                            .portal
                                                            .username
                                                      : hit.portal.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.4),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF7C5CFF,
                                                ).withValues(alpha: 0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Color(0xFF00E5FF),
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
  }
  return '$twoDigitMinutes:$twoDigitSeconds';
}

/// What sits where the seek bar would be on a live stream.
///
/// A live stream has no duration to scrub, so the seek bar is absent -- but
/// absent alone reads as a control that failed to load. This says the stream
/// is at its live edge and there is nothing to scrub, using the same red the
/// LIVE badge in the top bar uses so the two read as one statement.
class _LiveEdgeRow extends StatelessWidget {
  const _LiveEdgeRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFFF3B30),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Live',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        // Takes the seek bar's width so the bar keeps its shape, and reads
        // as a track already at its end rather than an empty gap.
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _IptvCustomProgressBar extends StatefulWidget {
  final Player player;
  final ValueNotifier<Duration> positionNotifier;
  final Duration duration;
  final ValueNotifier<Duration?> bufferedNotifier;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const _IptvCustomProgressBar({
    required this.player,
    required this.positionNotifier,
    required this.duration,
    required this.bufferedNotifier,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  State<_IptvCustomProgressBar> createState() => _IptvCustomProgressBarState();
}

class _IptvCustomProgressBarState extends State<_IptvCustomProgressBar> {
  double? _hoverX;
  bool _isDragging = false;
  Duration? _dragPosition;

  void _seekTo(double x, double width, Duration totalDuration) {
    if (width <= 0 || totalDuration <= Duration.zero) return;
    final percent = (x / width).clamp(0.0, 1.0);
    final position = totalDuration * percent;
    widget.player.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.duration;

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.positionNotifier,
      builder: (context, livePosition, _) {
        final position = _isDragging
            ? (_dragPosition ?? livePosition)
            : livePosition;

        return ValueListenableBuilder<Duration?>(
          valueListenable: widget.bufferedNotifier,
          builder: (context, bufferedDuration, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) {
                    setState(() {
                      _hoverX = event.localPosition.dx.clamp(0.0, width);
                    });
                  },
                  onExit: (event) {
                    setState(() {
                      _hoverX = null;
                    });
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      widget.onSeekStart?.call();
                      setState(() {
                        _isDragging = true;
                        _hoverX = details.localPosition.dx.clamp(0.0, width);
                        if (duration > Duration.zero) {
                          _dragPosition = duration * (_hoverX! / width);
                        }
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _hoverX = details.localPosition.dx.clamp(0.0, width);
                        if (duration > Duration.zero) {
                          _dragPosition = duration * (_hoverX! / width);
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragPosition != null) {
                        widget.player.seek(_dragPosition!);
                      }
                      setState(() {
                        _isDragging = false;
                        _dragPosition = null;
                      });
                      widget.onSeekEnd?.call();
                    },
                    onTapDown: (details) {
                      _seekTo(details.localPosition.dx, width, duration);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          // Invisible hit target
                          Container(
                            height: 24,
                            width: double.infinity,
                            color: Colors.transparent,
                          ),

                          // Background Bar
                          Container(
                            height: 5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // Buffered Bar
                          if (bufferedDuration != null &&
                              duration.inMilliseconds > 0)
                            Positioned(
                              left: 0,
                              child: Container(
                                height: 5,
                                width:
                                    (width *
                                            (bufferedDuration.inMilliseconds /
                                                duration.inMilliseconds))
                                        .clamp(0.0, width),
                                decoration: BoxDecoration(
                                  color: Colors.white38,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                          // Played Bar
                          Container(
                            height: 5,
                            width: duration.inMilliseconds > 0
                                ? (width *
                                          (position.inMilliseconds /
                                              duration.inMilliseconds))
                                      .clamp(0.0, width)
                                : 0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C5CFF), Color(0xFF00D2EF)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // Scrubber Handle
                          Positioned(
                            left: duration.inMilliseconds > 0
                                ? (width *
                                              (position.inMilliseconds /
                                                  duration.inMilliseconds))
                                          .clamp(0.0, width) -
                                      7
                                : -7,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7C5CFF,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Hover Tooltip
                          if (_hoverX != null && duration > Duration.zero)
                            Positioned(
                              left: (_hoverX! - 30).clamp(0.0, width - 60),
                              bottom: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C0E15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatDuration(
                                    duration * (_hoverX! / width),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
