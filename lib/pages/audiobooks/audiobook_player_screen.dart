import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:media_kit/media_kit.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../../models/download/download_task_model.dart';
import '../../models/stream/stream_model.dart';
import '../../services/audiobook/audiobook_player_controller.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/audiobook/audiobook_progress_service.dart';
import '../../services/download/download_service.dart';
import '../../services/playback_coordinator.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../utils/download/download_path_helper.dart';
import '../../widgets/audiobook/audiobook_interactive_physics_button.dart';
import '../../widgets/audiobook/audiobook_waveform_seekbar.dart';
import '../settings/appearance/audiobook_player_studio_page.dart';

class AudiobookPlayerScreen extends StatefulWidget {
  final Audiobook audiobook;
  final List<AudiobookChapter> chapters;
  final int initialChapterIndex;
  final Duration? initialPosition;

  const AudiobookPlayerScreen({
    super.key,
    required this.audiobook,
    required this.chapters,
    this.initialChapterIndex = 0,
    this.initialPosition,
  });

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen> with SingleTickerProviderStateMixin {
  Player? _player;
  final List<StreamSubscription> _playerSubscriptions = [];
  int _loadGeneration = 0;
  late int _currentChapterIndex;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _autoplayNext = true;
  String _statusMessage = 'Initializing chapter...';
  String? _errorMessage;

  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _showChaptersDrawer = false;
  String _chapterSearchQuery = '';
  late AnimationController _discAnimController;
  Timer? _progressTimer;
  bool _hasRestoredPosition = false;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    AudiobookSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);

    _initChapter(_currentChapterIndex);

    // Save progress every 5 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _updateDiscordRpc({bool? isPaused}) {
    final chapter = (widget.chapters.isNotEmpty && _currentChapterIndex < widget.chapters.length)
        ? widget.chapters[_currentChapterIndex]
        : null;
    DiscordRpcService.instance.setListeningAudiobook(
      title: widget.audiobook.title,
      author: widget.audiobook.author,
      chapter: chapter?.title,
      coverUrl: widget.audiobook.coverImage,
      position: _position,
      duration: _duration,
      isPaused: isPaused ?? !_isPlaying,
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    PlaybackCoordinator.release(
      'audiobook:${widget.audiobook.uuid}:$_currentChapterIndex',
    );
    AudiobookSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    for (final s in _playerSubscriptions) {
      s.cancel();
    }
    _playerSubscriptions.clear();
    _player?.dispose();
    _discAnimController.dispose();
    TorrentStreamService().cleanup();
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _saveProgress() {
    if (_player != null && _duration > Duration.zero) {
      AudiobookProgressService.instance.saveProgress(
        audiobook: widget.audiobook,
        chapters: widget.chapters,
        chapterIndex: _currentChapterIndex,
        position: _position,
        duration: _duration,
      );
    }
  }

  Future<void> _initChapter(int index) async {
    if (index < 0 || index >= widget.chapters.length) return;
    final int myGeneration = ++_loadGeneration;

    // This screen builds its own playback engine for the fullscreen view,
    // separate from the background AudiobookPlayerController the play bar
    // drives. If that controller is already playing this same audiobook
    // (the common "tap the play bar to expand" path), stop it first —
    // otherwise PlaybackCoordinator.activate() below is a no-op for a
    // repeated source id, leaving the background engine playing
    // unsupervised (a second, overlapping audio stream) after this screen
    // takes over.
    if (AudiobookPlayerController.instance.hasAudiobook &&
        AudiobookPlayerController.instance.audiobook?.uuid ==
            widget.audiobook.uuid) {
      await AudiobookPlayerController.instance.stop();
    }

    // Ensure only one source plays app-wide: stop any other active source.
    final sourceId = 'audiobook:${widget.audiobook.uuid}:$index';
    PlaybackCoordinator.activate(
      sourceId,
      () {
        _player?.pause();
      },
      kind: 'audiobook',
      title: widget.audiobook.title,
      subtitle: widget.chapters[index].title,
      coverUrl: widget.audiobook.coverImage,
      onTogglePlayPause: () {
        if (_player == null) return;
        if (_player!.state.playing) {
          _player!.pause();
        } else {
          _player!.play();
        }
      },
    );

    // Save progress before switching
    _saveProgress();

    for (final s in _playerSubscriptions) {
      s.cancel();
    }
    _playerSubscriptions.clear();

    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }

    if (myGeneration != _loadGeneration) return;

    setState(() {
      _currentChapterIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Preparing ${widget.chapters[index].title}...';
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    final chapter = widget.chapters[index];
    String? streamUrl;

    try {
      if (chapter.isTorrent) {
        final useDebrid = await DebridService().isDebridActiveForStreams();
        if (useDebrid) {
          final activeService = await DebridService().getSelectedService();
          if (!mounted) return;
          setState(() => _statusMessage = 'Resolving audio via $activeService cloud...');

          final debridFiles = await DebridService().resolveMagnet(
            magnet: chapter.url,
            fileIndex: chapter.torrentFileIndex,
            filename: chapter.title,
          );

          if (debridFiles.isEmpty || debridFiles.first.downloadUrl.isEmpty) {
            throw Exception('$activeService could not resolve audio stream.');
          }

          streamUrl = debridFiles.first.downloadUrl;
        } else {
          setState(() => _statusMessage = 'Fetching torrent metadata & peers...');
          streamUrl = await TorrentStreamService().streamTorrent(
            chapter.url,
            fileIdx: chapter.torrentFileIndex,
          );
        }
      } else {
        streamUrl = chapter.url;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Audio stream URL could not be resolved.');
      }

      if (myGeneration != _loadGeneration) return;

      final isLocal = !streamUrl.startsWith('http://') && !streamUrl.startsWith('https://');
      final player = Player();

      final Media media;
      if (isLocal) {
        media = Media(File(streamUrl).uri.toString());
      } else {
        final sanitizedUrlStr = streamUrl.contains('::')
            ? streamUrl.replaceAll('::', '%3A%3A')
            : streamUrl;
        final cleanUri = Uri.parse(sanitizedUrlStr);

        final headers = <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
        if (chapter.httpHeaders != null) {
          headers.addAll(chapter.httpHeaders!);
        }

        media = Media(cleanUri.toString(), httpHeaders: headers);
      }

      // Held locally (not in the shared `_playerSubscriptions` field) until
      // this call is confirmed to still be the current one -- otherwise a
      // superseded call's cleanup could cancel a newer call's subscriptions
      // out from under it.
      final localSubs = [
        player.stream.playing.listen((playing) {
          if (mounted) {
            setState(() => _isPlaying = playing);
            _updateDiscordRpc(isPaused: !playing);
            if (playing && !_discAnimController.isAnimating) {
              _discAnimController.repeat();
            } else if (!playing && _discAnimController.isAnimating) {
              _discAnimController.stop();
            }
          }
        }),
        player.stream.position.listen((pos) {
          if (mounted) {
            setState(() => _position = pos);
          }
        }),
        player.stream.duration.listen((dur) {
          if (mounted && dur > Duration.zero) {
            setState(() {
              _duration = dur;
              _isLoading = false;
            });
            _updateDiscordRpc();
          }
        }),
        player.stream.completed.listen((completed) {
          if (completed && mounted) {
            if (_autoplayNext && _currentChapterIndex < widget.chapters.length - 1) {
              _initChapter(_currentChapterIndex + 1);
            }
          }
        }),
        player.stream.error.listen((err) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Playback Error: $err';
            });
          }
        }),
      ];

      // Open paused, then configure, then play. open() defaults to play:true,
      // so the chapter started at libmpv's own volume, at 1.0x, and from
      // 0:00 before the lines below took effect -- audible as a blast at the
      // head of every chapter, a lurch to the chosen speed, and a blip of
      // chapter-start audio before the resume seek, which happens on nearly
      // every open here since audiobooks almost always resume.
      await player.open(media, play: false);
      await player.setVolume(_volume * 100.0);
      await player.setRate(_playbackSpeed);

      // Auto-seek if resuming initial position
      if (!_hasRestoredPosition &&
          index == widget.initialChapterIndex &&
          widget.initialPosition != null &&
          widget.initialPosition! > Duration.zero) {
        await player.seek(widget.initialPosition!);
        _hasRestoredPosition = true;
      }

      if (!mounted) {
        for (final s in localSubs) {
          s.cancel();
        }
        await player.dispose();
        return;
      }

      if (myGeneration != _loadGeneration) {
        for (final s in localSubs) {
          s.cancel();
        }
        await player.dispose();
        return;
      }

      await player.play();

      _playerSubscriptions.addAll(localSubs);

      setState(() {
        _player = player;
        _isLoading = false;
        _isPlaying = true;
      });

      _discAnimController.repeat();
    } catch (e) {
      if (!mounted || myGeneration != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Playback Error: $e';
      });
    }
  }

  void _togglePlayPause() {
    if (_player == null) return;

    if (_isPlaying) {
      _player!.pause();
      _discAnimController.stop();
      setState(() => _isPlaying = false);
    } else {
      _player!.play();
      _discAnimController.repeat();
      setState(() => _isPlaying = true);
    }
  }

  void _seekRelative(int seconds) {
    if (_player == null) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _player!.seek(clamped);
  }

  void _cycleSpeed() {
    final nextIdx = (_speeds.indexOf(_playbackSpeed) + 1) % _speeds.length;
    final newSpeed = _speeds[nextIdx];
    setState(() => _playbackSpeed = newSpeed);
    _player?.setRate(newSpeed);
  }

  Future<void> _handleDownloadChapter() async {
    final chapter = widget.chapters[_currentChapterIndex];
    final mediaId = '${widget.audiobook.uuid}:$_currentChapterIndex';

    final existing = DownloadService.instance.tasksNotifier.value
        .where((t) => t.mediaId == mediaId)
        .firstOrNull;
    if (existing != null) {
      if (existing.status == DownloadStatus.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download already in progress in background.')),
        );
        return;
      } else if (existing.status == DownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This chapter is already downloaded.')),
        );
        return;
      }
    }

    try {
      String? customDir;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        customDir = await DownloadPathHelper.pickDownloadsDirectory();
        if (customDir == null) return; // User canceled folder selection
      }

      await DownloadService.instance.startDownload(
        title: '${widget.audiobook.title} - ${chapter.title}',
        mediaId: mediaId,
        type: 'audiobook',
        posterUrl: widget.audiobook.coverImage,
        source: StreamSource(
          url: chapter.url,
          fileIdx: chapter.torrentFileIndex,
          addonName: widget.audiobook.source,
          headers: chapter.httpHeaders,
        ),
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

  void _showPlayerCustomizer(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF10131C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 490),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: palette.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Audio Player Style & Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  const Text('Select Player Design Preset', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<AudiobookPlayerPreset>(
                    valueListenable: AudiobookSettings.selectedPlayerPreset,
                    builder: (context, currentPreset, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AudiobookPlayerPreset.values.map((p) {
                          final isSelected = p == currentPreset;
                          return ChoiceChip(
                            label: Text(p.label),
                            selected: isSelected,
                            selectedColor: palette.primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF0D1017),
                            labelStyle: TextStyle(
                              color: isSelected ? palette.primaryColor : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? palette.primaryColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                            ),
                            onSelected: (selected) {
                              if (selected) AudiobookSettings.setSelectedPlayerPreset(p);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  const Text('Seek Bar Scrubber Style', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<AudiobookSeekbarStyle>(
                    valueListenable: AudiobookSettings.customSeekbarStyle,
                    builder: (context, currentStyle, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AudiobookSeekbarStyle.values.map((s) {
                          final isSelected = s == currentStyle;
                          return ChoiceChip(
                            label: Text(s.label),
                            selected: isSelected,
                            selectedColor: palette.primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF0D1017),
                            labelStyle: TextStyle(
                              color: isSelected ? palette.primaryColor : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? palette.primaryColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                            ),
                            onSelected: (selected) {
                              if (selected) AudiobookSettings.setCustomSeekbarStyle(s);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  const Text('Play / Pause Button Style', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<AudiobookPlayButtonStyle>(
                    valueListenable: AudiobookSettings.customPlayButtonStyle,
                    builder: (context, currentStyle, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AudiobookPlayButtonStyle.values.map((b) {
                          final isSelected = b == currentStyle;
                          return ChoiceChip(
                            label: Text(b.label),
                            selected: isSelected,
                            selectedColor: palette.primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF0D1017),
                            labelStyle: TextStyle(
                              color: isSelected ? palette.primaryColor : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? palette.primaryColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                            ),
                            onSelected: (selected) {
                              if (selected) AudiobookSettings.setCustomPlayButtonStyle(b);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryColor.withValues(alpha: 0.15),
                        foregroundColor: palette.primaryColor,
                        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                      label: const Text('Open Drag & Drop Player Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AudiobookPlayerStudioPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.audiobook.coverImage.isNotEmpty;
    final currentChapter = widget.chapters.isNotEmpty && _currentChapterIndex < widget.chapters.length
        ? widget.chapters[_currentChapterIndex]
        : null;

    final palette = AppThemeService.currentPalette.value;
    final preset = AudiobookSettings.selectedPlayerPreset.value;

    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Dismissible Scrim with blur
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),
              ),
            ),

            // Floating Modal Window
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 680,
                  maxHeight: math.min(780, screenSize.height * 0.90),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0F17),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 40,
                        spreadRadius: 8,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        // Background ambient cover blur & atmosphere
                        if (hasCover && widget.audiobook.coverImage.trim().isNotEmpty)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.22,
                              child: CachedNetworkImage(
                                imageUrl: widget.audiobook.coverImage.trim(),
                                httpHeaders: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                },
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const SizedBox.shrink(),
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                            child: Container(color: Colors.black.withValues(alpha: 0.68)),
                          ),
                        ),

                        // Main Modal Content
                        Column(
                          children: [
                            // Top App Bar
                            _buildTopAppBar(context, palette, isDesktop: true),

                            // Main Content Rendered by Selected Player Preset
                            Expanded(
                              child: _buildPlayerContentByPreset(preset, false, hasCover, currentChapter, palette),
                            ),
                          ],
                        ),

                        // Sliding Premade Chapters Drawer Overlay
                        if (_showChaptersDrawer)
                          Positioned.fill(
                            child: _buildPremadeChaptersDrawer(palette),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // Background ambient cover blur & atmosphere
          if (hasCover && widget.audiobook.coverImage.trim().isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.22,
                child: CachedNetworkImage(
                  imageUrl: widget.audiobook.coverImage.trim(),
                  httpHeaders: const {
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  },
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(color: Colors.black.withValues(alpha: 0.68)),
            ),
          ),

          // Main Layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;

                return Column(
                  children: [
                    // Top App Bar
                    _buildTopAppBar(context, palette),

                    // Main Content Rendered by Selected Player Preset
                    Expanded(
                      child: _buildPlayerContentByPreset(preset, isWide, hasCover, currentChapter, palette),
                    ),
                  ],
                );
              },
            ),
          ),

          // Sliding Premade Chapters Drawer Overlay
          if (_showChaptersDrawer)
            Positioned.fill(
              child: _buildPremadeChaptersDrawer(palette),
            ),
        ],
      ),
    );
  }

  // ── Top Header Bar ──
  Widget _buildTopAppBar(BuildContext context, AppThemePalette palette, {bool isDesktop = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _PlayerIconButton(
            icon: isDesktop ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
            palette: palette,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.audiobook.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Builder(
                  builder: (context) {
                    final isTorrent = widget.audiobook.source.toLowerCase().contains('audiobookbay');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTorrent) ...[
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isTorrent ? 'AUDIOBOOKBAY (TORRENT)' : widget.audiobook.source.toUpperCase(),
                          style: TextStyle(
                            color: isTorrent ? const Color(0xFFFFB74D) : palette.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Autoplay Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Autoplay',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _autoplayNext,
                  onChanged: (val) => setState(() => _autoplayNext = val),
                  activeColor: palette.primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Customizer Button
          _PlayerIconButton(
            icon: Icons.tune_rounded,
            palette: palette,
            tooltip: 'Customize Audio Player',
            onTap: () => _showPlayerCustomizer(context),
          ),
          const SizedBox(width: 6),
          // Chapters Button
          _PlayerIconButton(
            icon: Icons.format_list_bulleted_rounded,
            palette: palette,
            tooltip: 'Chapters List',
            onTap: () => setState(() => _showChaptersDrawer = true),
          ),
          const SizedBox(width: 6),
          // Download Chapter Button
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadService.instance.tasksNotifier,
            builder: (context, tasks, _) {
              final mediaId = '${widget.audiobook.uuid}:$_currentChapterIndex';
              final isDownloading = tasks.any(
                (t) => t.mediaId == mediaId && t.status == DownloadStatus.downloading,
              );
              return _PlayerIconButton(
                icon: isDownloading ? Icons.downloading_rounded : Icons.download_rounded,
                palette: palette,
                tooltip: isDownloading ? 'Downloading...' : 'Download Chapter',
                onTap: isDownloading ? null : _handleDownloadChapter,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Multi-Player Preset Dispatcher ──
  Widget _buildPlayerContentByPreset(
    AudiobookPlayerPreset preset,
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: palette.primaryColor),
            const SizedBox(height: 18),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _initChapter(_currentChapterIndex),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Retry Chapter', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: palette.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (preset == AudiobookPlayerPreset.vinylStudio) {
      return _buildVinylStudioPlayer(isWide, hasCover, currentChapter, palette);
    }
    if (preset == AudiobookPlayerPreset.minimalCapsule) {
      return _buildMinimalCapsulePlayer(isWide, hasCover, currentChapter, palette);
    }
    if (preset == AudiobookPlayerPreset.immersiveCanvas) {
      return _buildImmersiveCanvasPlayer(isWide, hasCover, currentChapter, palette);
    }
    if (preset == AudiobookPlayerPreset.customStudio) {
      return _buildCustomStudioPlayer(isWide, hasCover, currentChapter, palette);
    }
    // Default: Modern Glass Island
    return _buildModernGlassPlayer(isWide, hasCover, currentChapter, palette);
  }

  // ── 1. Modern Glass Island Player ──
  Widget _buildModernGlassPlayer(
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    final seekStyle = AudiobookSettings.customSeekbarStyle.value;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Cover Art with 3D Float Shadow
              _buildCoverArtCard(hasCover, palette, size: isWide ? 220 : 170),
              const SizedBox(height: 20),
              _buildTitleSection(currentChapter),
              const Spacer(),

              // Glass Control Island
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F121C).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primaryColor.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform Seekbar
                    AudiobookWaveformSeekbar(
                      position: _position,
                      duration: _duration,
                      isPlaying: _isPlaying,
                      style: seekStyle,
                      onSeek: (pos) => _player?.seek(pos),
                    ),
                    const SizedBox(height: 12),

                    // Controls Row
                    _buildMainControlsCluster(palette),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. Vinyl Turntable Studio Player ──
  Widget _buildVinylStudioPlayer(
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning Vinyl Disc
              _buildVinylDiscWidget(hasCover, palette, size: isWide ? 240 : 190),
              const SizedBox(height: 18),
              _buildTitleSection(currentChapter),
              const SizedBox(height: 18),

              // Animated VU Meters
              _buildVuMetersWidget(palette),
              const SizedBox(height: 16),

              // Waveform Seekbar
              AudiobookWaveformSeekbar(
                position: _position,
                duration: _duration,
                isPlaying: _isPlaying,
                style: AudiobookSeekbarStyle.audioWaveformCanvas,
                onSeek: (pos) => _player?.seek(pos),
              ),
              const SizedBox(height: 14),

              // Controls Cluster
              _buildMainControlsCluster(palette),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Minimalist Focus Capsule Player ──
  Widget _buildMinimalCapsulePlayer(
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0F17).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: palette.primaryColor.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: palette.primaryColor.withValues(alpha: 0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasCover
                        ? CachedNetworkImage(imageUrl: widget.audiobook.coverImage, width: 48, height: 48, fit: BoxFit.cover)
                        : Container(width: 48, height: 48, color: Colors.white12),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentChapter?.title ?? 'Chapter ${_currentChapterIndex + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        Text(
                          widget.audiobook.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AudiobookWaveformSeekbar(
                position: _position,
                duration: _duration,
                isPlaying: _isPlaying,
                style: AudiobookSeekbarStyle.gradientProgress,
                onSeek: (pos) => _player?.seek(pos),
              ),
              const SizedBox(height: 12),
              _buildMainControlsCluster(palette),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Immersive Canvas Studio Player ──
  Widget _buildImmersiveCanvasPlayer(
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Oversized 3D Card
              _buildCoverArtCard(hasCover, palette, size: isWide ? 260 : 200),
              const SizedBox(height: 24),
              _buildTitleSection(currentChapter),
              const Spacer(),
              AudiobookWaveformSeekbar(
                position: _position,
                duration: _duration,
                isPlaying: _isPlaying,
                style: AudiobookSeekbarStyle.audioWaveformCanvas,
                onSeek: (pos) => _player?.seek(pos),
              ),
              const SizedBox(height: 16),
              _buildMainControlsCluster(palette),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Custom Drag & Drop Studio Player ──
  Widget _buildCustomStudioPlayer(
    bool isWide,
    bool hasCover,
    AudiobookChapter? currentChapter,
    AppThemePalette palette,
  ) {
    final order = AudiobookSettings.componentOrder.value;
    final seekStyle = AudiobookSettings.customSeekbarStyle.value;
    final artStyle = AudiobookSettings.customArtworkStyle.value;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: order.map((key) {
              switch (key) {
                case 'artwork':
                  if (artStyle == AudiobookArtworkStyle.hidden) return const SizedBox.shrink();
                  if (artStyle == AudiobookArtworkStyle.vinylDisc) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildVinylDiscWidget(hasCover, palette, size: isWide ? 220 : 170),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCoverArtCard(hasCover, palette, size: isWide ? 210 : 160),
                  );
                case 'title':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTitleSection(currentChapter),
                  );
                case 'seekbar':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AudiobookWaveformSeekbar(
                      position: _position,
                      duration: _duration,
                      isPlaying: _isPlaying,
                      style: seekStyle,
                      onSeek: (pos) => _player?.seek(pos),
                    ),
                  );
                case 'mainControls':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildMainControlsCluster(palette),
                  );
                case 'secondaryControls':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSpeedSelectorPill(palette),
                        const SizedBox(width: 16),
                        _VolumeButton(
                          volume: _volume,
                          palette: palette,
                          onVolumeChanged: (v) {
                            setState(() => _volume = v);
                            _player?.setVolume(v * 100.0);
                          },
                        ),
                      ],
                    ),
                  );
                case 'chaptersButton':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _showChaptersDrawer = true),
                      icon: Icon(Icons.format_list_bulleted_rounded, color: palette.primaryColor, size: 18),
                      label: const Text('Open Chapters Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  );
                default:
                  return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Cover Art Card ──
  Widget _buildCoverArtCard(bool hasCover, AppThemePalette palette, {double size = 200}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: _isPlaying ? 0.45 : 0.25),
            blurRadius: _isPlaying ? 32 : 18,
            spreadRadius: _isPlaying ? 3 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: hasCover
            ? CachedNetworkImage(
                imageUrl: widget.audiobook.coverImage,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF161A26)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF161A26),
                  child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white54),
                ),
              )
            : Container(
                color: const Color(0xFF161A26),
                child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white54),
              ),
      ),
    );
  }

  // ── Spinning Vinyl Disc Widget ──
  Widget _buildVinylDiscWidget(bool hasCover, AppThemePalette palette, {double size = 220}) {
    return AnimatedBuilder(
      animation: _discAnimController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _discAnimController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: _isPlaying ? 0.45 : 0.2),
              blurRadius: _isPlaying ? 32 : 16,
              spreadRadius: _isPlaying ? 4 : 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasCover)
                CachedNetworkImage(
                  imageUrl: widget.audiobook.coverImage,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF161A26),
                    child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white54),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF161A26),
                  child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white54),
                ),
              // Center Vinyl Ring Hole
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF080A0F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── VU Audio Meters Widget ──
  Widget _buildVuMetersWidget(AppThemePalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(16, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 4,
          height: _isPlaying ? (8 + ((i % 5) * 4.5)) : 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: _isPlaying ? palette.primaryColor : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // ── Title Section ──
  Widget _buildTitleSection(AudiobookChapter? currentChapter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            currentChapter?.title ?? 'Chapter ${_currentChapterIndex + 1}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Chapter ${_currentChapterIndex + 1} of ${widget.chapters.length} • ${widget.audiobook.title}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Main Controls Cluster (Prev, Rewind, Play, Forward, Next, Speed) ──
  Widget _buildMainControlsCluster(AppThemePalette palette) {
    final playBtnStyle = AudiobookSettings.customPlayButtonStyle.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Speed Selector Pill
        _buildSpeedSelectorPill(palette),

        // Prev Chapter
        _PlayerIconButton(
          icon: Icons.skip_previous_rounded,
          size: 28,
          palette: palette,
          onTap: _currentChapterIndex > 0 ? () => _initChapter(_currentChapterIndex - 1) : null,
        ),

        // Rewind 10s
        _PlayerIconButton(
          icon: Icons.replay_10_rounded,
          size: 28,
          palette: palette,
          onTap: () => _seekRelative(-10),
        ),

        // Custom Styled Play/Pause Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: _buildPlayButtonByStyle(playBtnStyle, palette),
        ),

        // Forward 10s
        _PlayerIconButton(
          icon: Icons.forward_10_rounded,
          size: 28,
          palette: palette,
          onTap: () => _seekRelative(10),
        ),

        // Next Chapter
        _PlayerIconButton(
          icon: Icons.skip_next_rounded,
          size: 28,
          palette: palette,
          onTap: _currentChapterIndex < widget.chapters.length - 1
              ? () => _initChapter(_currentChapterIndex + 1)
              : null,
        ),

        // Volume Button
        _VolumeButton(
          volume: _volume,
          palette: palette,
          onVolumeChanged: (v) {
            setState(() => _volume = v);
            _player?.setVolume(v * 100.0);
          },
        ),
      ],
    );
  }

  Widget _buildSpeedSelectorPill(AppThemePalette palette) {
    return InkWell(
      onTap: _cycleSpeed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: TextStyle(
            color: palette.primaryColor,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButtonByStyle(AudiobookPlayButtonStyle style, AppThemePalette palette) {
    final icon = _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final hoverEffect = AudiobookSettings.customHoverEffect.value;

    Widget buttonCore;
    BorderRadius borderRadius;

    if (style == AudiobookPlayButtonStyle.liquidGlassNeo) {
      borderRadius = BorderRadius.circular(20);
      final glassStyle = LiquidGlassStyle(
        shape: const LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: 20,
          clipQuality: LiquidGlassClipQuality.exact,
          borderWidth: 1.6,
          lightIntensity: 1.5,
          lightColor: Color(0xE6FFFFFF),
          lightDirection: 115,
          borderType: OpticalBorder(
            borderSaturation: 1.5,
            ambientIntensity: 1.2,
            borderSolidity: 0.2,
            lightSpread: 0.7,
          ),
        ),
        appearance: LiquidGlassAppearance(
          color: palette.primaryColor.withValues(alpha: 0.16),
          saturation: 1.25,
          blur: const LiquidGlassBlur(sigmaX: 3.5, sigmaY: 3.5),
          shadow: LiquidGlassShadow(
            blur: 18,
            opacity: 0.45,
            color: palette.primaryColor,
          ),
        ),
        refraction: const LiquidGlassRefraction(
          magnification: 1.04,
          chromaticAberration: 0.0035,
          refractionType: OpticalRefraction(
            refraction: 1.55,
            refractionWidth: 24,
            depth: 0.85,
          ),
        ),
      );

      buttonCore = LiquidGlassLens(
        style: glassStyle,
        visibility: true,
        useImpellerBackdrop: true,
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      );
    } else if (style == AudiobookPlayButtonStyle.roundedSquare) {
      borderRadius = BorderRadius.circular(16);
      buttonCore = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: palette.primaryColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      );
    } else if (style == AudiobookPlayButtonStyle.accentPill) {
      borderRadius = BorderRadius.circular(24);
      buttonCore = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: palette.primaryColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            Text(
              _isPlaying ? 'PAUSE' : 'PLAY',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
            ),
          ],
        ),
      );
    } else {
      borderRadius = BorderRadius.circular(29);
      buttonCore = Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.primaryColor,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      );
    }

    return AudiobookInteractivePhysicsButton(
      effect: hoverEffect,
      glowColor: palette.primaryColor,
      borderRadius: borderRadius,
      onTap: _togglePlayPause,
      child: buttonCore,
    );
  }

  // ── Premade Sliding Glass Chapters Drawer ──
  Widget _buildPremadeChaptersDrawer(AppThemePalette palette) {
    final filteredChapters = widget.chapters.where((c) {
      if (_chapterSearchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_chapterSearchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: () => setState(() => _showChaptersDrawer = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // Catch taps inside drawer
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E111A).withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_list_bulleted_rounded, color: palette.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Audiobook Chapters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.chapters.length} CHAPTERS',
                                style: TextStyle(color: palette.primaryColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                              onPressed: () => setState(() => _showChaptersDrawer = false),
                            ),
                          ],
                        ),
                      ),

                      // Chapter Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141824),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: TextField(
                            onChanged: (val) => setState(() => _chapterSearchQuery = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Filter chapters by name...',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: palette.primaryColor, size: 16),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),

                      // Chapters List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredChapters.length,
                          itemBuilder: (context, index) {
                            final chapter = filteredChapters[index];
                            final originalIndex = widget.chapters.indexOf(chapter);
                            final isSelected = originalIndex == _currentChapterIndex;

                            return _ChapterListItemTile(
                              chapter: chapter,
                              index: originalIndex,
                              isSelected: isSelected,
                              isPlaying: isSelected && _isPlaying,
                              palette: palette,
                              onTap: () {
                                setState(() => _showChaptersDrawer = false);
                                _initChapter(originalIndex);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final AppThemePalette palette;
  final String? tooltip;
  final VoidCallback? onTap;

  const _PlayerIconButton({
    required this.icon,
    required this.palette,
    this.size = 24,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final btn = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(
        icon,
        size: size,
        color: enabled ? Colors.white : Colors.white24,
      ),
    );

    return Tooltip(
      message: tooltip ?? '',
      child: AudiobookInteractivePhysicsButton(
        effect: AudiobookSettings.customHoverEffect.value,
        glowColor: palette.primaryColor,
        borderRadius: BorderRadius.circular(size + 10),
        enabled: enabled,
        onTap: onTap,
        child: btn,
      ),
    );
  }
}

class _VolumeButton extends StatefulWidget {
  final double volume;
  final AppThemePalette palette;
  final ValueChanged<double> onVolumeChanged;

  const _VolumeButton({
    required this.volume,
    required this.palette,
    required this.onVolumeChanged,
  });

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  bool _showSlider = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayerIconButton(
          icon: widget.volume == 0
              ? Icons.volume_off_rounded
              : (widget.volume > 0.5 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
          size: 24,
          palette: widget.palette,
          onTap: () {
            setState(() => _showSlider = !_showSlider);
          },
        ),
        if (_showSlider)
          SizedBox(
            width: 86,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: widget.palette.primaryColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: widget.volume,
                min: 0.0,
                max: 1.0,
                onChanged: widget.onVolumeChanged,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChapterListItemTile extends StatefulWidget {
  final AudiobookChapter chapter;
  final int index;
  final bool isSelected;
  final bool isPlaying;
  final AppThemePalette palette;
  final VoidCallback onTap;

  const _ChapterListItemTile({
    required this.chapter,
    required this.index,
    required this.isSelected,
    required this.isPlaying,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_ChapterListItemTile> createState() => _ChapterListItemTileState();
}

class _ChapterListItemTileState extends State<_ChapterListItemTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.98 : (_isHovered ? 1.015 : 1.0);
    final palette = widget.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? palette.primaryColor.withValues(alpha: 0.22)
                    : (_isHovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected
                      ? palette.primaryColor.withValues(alpha: 0.6)
                      : (_isHovered ? Colors.white.withValues(alpha: 0.12) : Colors.transparent),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isSelected
                        ? (widget.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_circle_filled_rounded)
                        : Icons.play_circle_outline_rounded,
                    color: widget.isSelected ? palette.primaryColor : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.chapter.title,
                      style: TextStyle(
                        color: widget.isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
