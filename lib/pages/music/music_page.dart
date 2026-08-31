import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/music/music_track.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/music/music_download_service.dart';
import '../../widgets/music/music_track_download_button.dart';
import '../../services/music/music_library_service.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/common/section_sub_tabs.dart';
import '../../widgets/common/performance_liquid_lens.dart';
import '../../widgets/common/slider_arrow.dart';
import '../../widgets/common/section_top_bar.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../../main.dart' show navigatorKey;
import '../podcast/podcast_details_page.dart';
import '../podcast/podcasts_page.dart';
import '../../services/podcast/podcast_library_service.dart';
import '../../services/music/music_player_controller.dart';
import '../../services/music/music_service.dart';
import '../../services/music/music_settings.dart';
import '../../widgets/music/music_interactive_physics_button.dart';
import '../../widgets/music/music_waveform_seekbar.dart';
import '../../widgets/common/like_button.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MusicService _musicService = MusicService.instance;
  final MusicPlayerController _playerController = MusicPlayerController.instance;
  final MusicLibraryService _libraryService = MusicLibraryService.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _activeTab = 'Music'; // 'Music', 'Search', 'Radio', 'Podcasts', 'Library'
  String _savedType = 'songs'; // Library > Saved sub-tab
  // True only when the current search was reached by tapping a Radio
  // station card, so the resulting tracks play with isRadio: true (see
  // MusicPlayerController.playTrack) instead of a deliberate track pick.
  bool _searchIsFromRadio = false;

  Map<String, List<MusicTrack>> _sections = {};
  String? _errorMessage;
  List<MusicArtist> _trendingArtists = [];
  List<MusicAlbum> _newReleases = [];
  List<MusicPlaylist> _curatedPlaylists = [];
  List<MusicGenre> _genres = [];

  MusicGenre? _selectedBrowseGenre;
  List<MusicArtist> _genreArtists = [];
  bool _loadingGenreArtists = false;
  MusicTrack? _heroTrack;

  MusicSearchData _searchData = MusicSearchData.empty;

  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  String _selectedFilter = 'All';
  Timer? _debounceTimer;

  bool _showQueueDrawer = false;
  bool _showLyricsDrawer = false;
  bool _showShortcutsModal = false;
  bool _showDownloadsModal = false;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _playerController.addListener(_onStateChanged);
    _libraryService.addListener(_onStateChanged);
    PodcastLibraryService.instance.addListener(_onStateChanged);
    HubController.instance.addListener(_onHubChanged);
    MusicDownloadService.instance.addListener(_onStateChanged);
    MusicSettings.changeNotifier.addListener(_onStateChanged);
    AppThemeService.currentPalette.addListener(_onStateChanged);
    _libraryService.init();
    PodcastLibraryService.instance.init();
    MusicDownloadService.instance.init();
    // Sync the initial tab from the controller (in case a chip is already active).
    _activeTab = HubController.instance.musicTab;
    // Let the universal play bar open the full player when tapped.
    _playerController.setExpandCallback(_openFullscreenPlayer);
    // Let tapping the artist in the play bar open the artist's view.
    _playerController.setOpenArtistCallback(() {
      final artistId = _playerController.currentTrack?.artistId ?? '';
      if (artistId.isNotEmpty) _openArtistModal(artistId);
    });
    _loadMusicData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _toastTimer?.cancel();
    _playerController.removeListener(_onStateChanged);
    _libraryService.removeListener(_onStateChanged);
    PodcastLibraryService.instance.removeListener(_onStateChanged);
    HubController.instance.removeListener(_onHubChanged);
    MusicDownloadService.instance.removeListener(_onStateChanged);
    MusicSettings.changeNotifier.removeListener(_onStateChanged);
    AppThemeService.currentPalette.removeListener(_onStateChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// Syncs the active tab from the shared [HubController] when a section chip
  /// is tapped (the left sidebar was removed, so the SectionTopBar drives it).
  void _onHubChanged() {
    if (!mounted) return;
    final tab = HubController.instance.musicTab;
    if (tab == _activeTab) return;
    setState(() {
      _activeTab = tab;
      _hasSearched = false;
      _isSearching = false;
      _searchData = MusicSearchData.empty;
      _activeQuery = '';
      _searchController.clear();
    });
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _loadMusicData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sectionsFuture = _musicService.fetchFeaturedSections();
      final artistsFuture = _musicService.fetchTrendingArtists();
      final releasesFuture = _musicService.fetchNewReleases();
      final playlistsFuture = _musicService.fetchCuratedPlaylists();
      final genresFuture = _musicService.fetchGenres();

      final results = await Future.wait([
        sectionsFuture,
        artistsFuture,
        releasesFuture,
        playlistsFuture,
        genresFuture,
      ]);

      final sections = results[0] as Map<String, List<MusicTrack>>;
      final artists = results[1] as List<MusicArtist>;
      final releases = results[2] as List<MusicAlbum>;
      final playlists = results[3] as List<MusicPlaylist>;
      final genres = results[4] as List<MusicGenre>;

      MusicTrack? hero;
      if (sections.isNotEmpty && sections.values.first.isNotEmpty) {
        hero = sections.values.first.first;
      }

      if (mounted) {
        setState(() {
          _sections = sections;
          _trendingArtists = artists;
          _newReleases = releases;
          _curatedPlaylists = playlists;
          _genres = genres;
          _heroTrack = hero;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading music data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _searchData = MusicSearchData.empty;
        _activeQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _activeQuery = trimmed;
        if (_activeTab != 'Search') _activeTab = 'Search';
      });

      final results = await _musicService.searchFull(trimmed);

      if (mounted) {
        setState(() {
          _searchData = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  void _onGenreTap(String query, {bool isRadio = false}) {
    _searchIsFromRadio = isRadio;
    _searchController.text = query;
    _onSearchChanged(query);
  }

  Future<void> _openArtistModal(String artistId) async {
    _showToast('Loading artist details...');
    final details = await _musicService.fetchArtistDetails(artistId);
    if (details != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MusicArtistDetailPage(
            details: details,
            playerController: _playerController,
            onPlayTrack: (t, queue) =>
                _playerController.playTrack(t, playlistQueue: queue),
            onAddToPlaylist: _showAddToPlaylistMenu,
            onOpenAlbum: _openAlbumModal,
          ),
        ),
      );
    }
  }

  Future<void> _openAlbumModal(String albumId) async {
    _showToast('Loading album...');
    final details = await _musicService.fetchAlbumDetails(albumId);
    if (details != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MusicAlbumDetailPage(
            details: details,
            playerController: _playerController,
            onPlayTrack: (t, queue) =>
                _playerController.playTrack(t, playlistQueue: queue),
            onAddToPlaylist: _showAddToPlaylistMenu,
          ),
        ),
      );
    }
  }

  Future<void> _openCuratedPlaylistModal(String playlistId) async {
    _showToast('Loading playlist...');
    final details = await _musicService.fetchPlaylistDetails(playlistId);
    if (details != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MusicCuratedPlaylistDetailPage(
            details: details,
            playerController: _playerController,
            onPlayTrack: (t, queue) =>
                _playerController.playTrack(t, playlistQueue: queue),
            onAddToPlaylist: _showAddToPlaylistMenu,
          ),
        ),
      );
    }
  }

  void _openUserPlaylistDetail(UserPlaylist pl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MusicUserPlaylistDetailPage(
          playlistId: pl.id,
          libraryService: _libraryService,
          playerController: _playerController,
          onPlayTrack: (t, queue) =>
              _playerController.playTrack(t, playlistQueue: queue),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_searchFocusNode.hasFocus) return;

    final key = event.logicalKey;
    // Music transport shortcuts (Space/K, J, L, M) are handled globally by
    // GlobalShortcuts so they work app-wide. Only page-specific UI toggles
    // remain here.
    if (key == LogicalKeyboardKey.keyQ) {
      setState(() => _showQueueDrawer = !_showQueueDrawer);
    } else if (key == LogicalKeyboardKey.keyF) {
      _openFullscreenPlayer();
    } else if (key == LogicalKeyboardKey.slash ||
        (HardwareKeyboard.instance.isShiftPressed &&
            key == LogicalKeyboardKey.slash)) {
      setState(() => _showShortcutsModal = !_showShortcutsModal);
    } else if (key == LogicalKeyboardKey.escape) {
      if (_showQueueDrawer) {
        setState(() => _showQueueDrawer = false);
      } else if (_showLyricsDrawer) {
        setState(() => _showLyricsDrawer = false);
      } else if (_showShortcutsModal) {
        setState(() => _showShortcutsModal = false);
      } else if (_showDownloadsModal) {
        setState(() => _showDownloadsModal = false);
      } else {
        Navigator.maybePop(context);
      }
    }
  }

  void _showCreatePlaylistDialog({MusicTrack? initialTrack}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              Icons.playlist_add_rounded,
              color: Color(0xFF7C5CFF),
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'New Playlist',
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
            if (initialTrack != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: initialTrack.coverUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initialTrack.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          initialTrack.artist,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter playlist title...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1B1E2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C5CFF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final pl = await _libraryService.createPlaylist(name);
                if (initialTrack != null) {
                  await _libraryService.addTrackToPlaylist(pl.id, initialTrack);
                  _showToast('Added "${initialTrack.title}" to "$name"');
                } else {
                  _showToast('Created playlist "$name"');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Create',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the now-playing player as a **fullscreen** route on the root
  /// navigator (escaping the header/sidebar), matching how video, audiobook,
  /// and manga playback open fullscreen.
  void _openFullscreenPlayer() {
    if (!_playerController.hasTrack) return;
    pushFullscreen(
      MaterialPageRoute(
        builder: (_) => _MusicExpandedPlayer(
          playerController: _playerController,
          isSaved: _libraryService.isTrackLiked(
            _playerController.currentTrack?.id ?? '',
          ),
          onToggleSave: () {
            if (_playerController.currentTrack != null) {
              _libraryService.toggleLikeTrack(_playerController.currentTrack!);
            }
          },
          onCollapse: () => navigatorKey.currentState?.pop(),
          onQueueTap: () {},
          onAddToPlaylist: () {
            if (_playerController.currentTrack != null) {
              _showAddToPlaylistMenu(_playerController.currentTrack!);
            }
          },
        ),
      ),
    );
  }

  void _showAddToPlaylistMenu(MusicTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final playlists = _libraryService.userPlaylists;
        return PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              color: Color(0xFF9E9EA8),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),

                // Quick Offline Download Action
                Builder(
                  builder: (context) {
                    final isDownloaded = MusicDownloadService.instance.isDownloaded(track.id);
                    final isQueued = MusicDownloadService.instance.isQueued(track.id);

                    return InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (isDownloaded) {
                          await MusicDownloadService.instance.deleteDownloadedTrack(track.id);
                          _showToast('Removed "${track.title}" from downloads');
                        } else if (!isQueued) {
                          MusicDownloadService.instance.queueTrack(track);
                          _showToast('Added "${track.title}" to download queue');
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? const Color(0xFF00B0FF).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDownloaded
                                ? const Color(0xFF00B0FF).withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDownloaded
                                  ? Icons.download_done_rounded
                                  : (isQueued ? Icons.hourglass_top_rounded : Icons.download_rounded),
                              color: isDownloaded ? const Color(0xFF00E5FF) : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDownloaded
                                    ? 'Downloaded Offline (Tap to Remove)'
                                    : (isQueued ? 'Downloading / Queued...' : 'Download Track Offline'),
                                style: TextStyle(
                                  color: isDownloaded ? const Color(0xFF00E5FF) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (isDownloaded)
                              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Save to Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(initialTrack: track);
                      },
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF7C5CFF),
                        size: 18,
                      ),
                      label: const Text(
                        'New Playlist',
                        style: TextStyle(
                          color: Color(0xFF7C5CFF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.playlist_add_rounded,
                            color: Colors.white38,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No custom playlists yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C5CFF),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCreatePlaylistDialog(initialTrack: track);
                            },
                            child: const Text(
                              'Create First Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        final inPlaylist = pl.tracks.any((t) => t.id == track.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: const Color(0xFF1B1E2B),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFF7C5CFF),
                            ),
                          ),
                          title: Text(
                            pl.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${pl.tracks.length} tracks',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            inPlaylist
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            color: inPlaylist
                                ? const Color(0xFF00D294)
                                : Colors.white60,
                          ),
                          onTap: () async {
                            if (inPlaylist) {
                              await _libraryService.removeTrackFromPlaylist(
                                pl.id,
                                track.id,
                              );
                              _showToast('Removed from "${pl.title}"');
                            } else {
                              await _libraryService.addTrackToPlaylist(
                                pl.id,
                                track,
                              );
                              _showToast('Added to "${pl.title}"');
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        body: Stack(
          children: [
            // Main App Shell Layout
            Column(
              children: [
                // Main Page Content Area
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          const SectionTopBar(),
                          // Search lives inline as its own tab (a real text
                          // field, not a separate pushed page like other
                          // hubs use PageSearchButton for), so it's reached
                          // via this icon rather than a section chip.
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              tooltip: 'Search',
                              icon: Icon(
                                Icons.search_rounded,
                                color: Colors.white.withValues(alpha: 0.75),
                                size: 20,
                              ),
                              onPressed: () =>
                                  HubController.instance.setMusicTab('Search'),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildTabContent(isDesktop),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Queue Drawer
            if (_showQueueDrawer)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _MusicQueueDrawer(
                  onClose: () => setState(() => _showQueueDrawer = false),
                ),
              ),

            // Synced Lyrics Drawer
            if (_showLyricsDrawer && _playerController.hasTrack)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _MusicLyricsDrawer(
                  track: _playerController.currentTrack!,
                  playerController: _playerController,
                  onClose: () => setState(() => _showLyricsDrawer = false),
                ),
              ),

            // Modals: Shortcuts
            if (_showShortcutsModal)
              Positioned.fill(
                child: _MusicShortcutsModal(
                  onClose: () => setState(() => _showShortcutsModal = false),
                ),
              ),

            // Modals: Downloaded Offline Tracks
            if (_showDownloadsModal)
              Positioned.fill(
                child: _MusicDownloadedTracksModal(
                  onClose: () => setState(() => _showDownloadsModal = false),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                ),
              ),

            // Temporary Notification Toast
            if (_toastMessage != null)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C5CFF).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _toastMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),

            // Persistent Hub Navigation Dock
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
      );
    }

    if (_errorMessage != null && _sections.isEmpty) {
      return ErrorView(
        error: _errorMessage,
        onRetry: _loadMusicData,
        title: 'Could not load music',
      );
    }

    if (_selectedBrowseGenre != null) {
      return _buildGenreArtistsView(_selectedBrowseGenre!);
    }

    if (_activeTab == 'Search' || _hasSearched || _searchController.text.isNotEmpty) {
      SearchScope.set('music', label: 'Music');
      return _buildSearchView();
    }

    if (_activeTab == 'Radio') return _buildRadioView();
    if (_activeTab == 'Podcasts') {
      SearchScope.set(null, label: 'Podcasts');
      return const PodcastsPage();
    }
    if (_activeTab == 'Library') {
      SearchScope.set(null, label: 'Library');
      return _buildLibraryView();
    }

    final bottomPad = isDesktop ? 120.0 : 110.0;

    return RefreshIndicator(
      color: const Color(0xFF7C5CFF),
      backgroundColor: const Color(0xFF151822),
      onRefresh: _loadMusicData,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 75, bottom: bottomPad),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          if (MusicSettings.enableSpotlight.value && _heroTrack != null)
            _MusicHeroBillboard(
              track: _heroTrack!,
              onPlayTap: () => _playerController.playTrack(
                _heroTrack!,
                playlistQueue: _sections.values.isNotEmpty ? _sections.values.first : null,
              ),
              onSaveTap: () {
                _libraryService.toggleLikeTrack(_heroTrack!);
                _showToast(
                  _libraryService.isTrackLiked(_heroTrack!.id)
                      ? 'Saved to Library'
                      : 'Removed from Library',
                );
              },
              onAddToPlaylistTap: () => _showAddToPlaylistMenu(_heroTrack!),
              isSaved: _libraryService.isTrackLiked(_heroTrack!.id),
            ),
          const SizedBox(height: 24),
          if (_trendingArtists.isNotEmpty)
            _MusicTrendingArtists(
              artists: _trendingArtists,
              onArtistTap: (artist) {
                if (artist.id.isNotEmpty) {
                  _openArtistModal(artist.id);
                } else {
                  _onGenreTap(artist.name);
                }
              },
            ),
          if (_newReleases.isNotEmpty)
            _MusicAlbumsRow(
              title: '💿 New Album Releases',
              albums: _newReleases,
              onAlbumTap: (album) => _openAlbumModal(album.id),
            ),
          if (_genres.isNotEmpty) _buildGenresRow(),
          if (_curatedPlaylists.isNotEmpty)
            _MusicPlaylistsRow(
              title: '🎧 Curated Charts & Mixes',
              playlists: _curatedPlaylists,
              onPlaylistTap: (pl) => _openCuratedPlaylistModal(pl.id),
            ),
          for (final entry in _sections.entries)
            _MusicCategorySlider(
              title: entry.key,
              tracks: entry.value,
              onAddToPlaylist: _showAddToPlaylistMenu,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    final sizing = _MusicCardSizing.fromWidth(MediaQuery.sizeOf(context).width);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            _searchIsFromRadio = false;
            _onSearchChanged(value);
          },
          decoration: InputDecoration(
            hintText: 'Search music...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF12151E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterTab('All'),
              const SizedBox(width: 8),
              _filterTab('Tracks (${_searchData.tracks.length})'),
              const SizedBox(width: 8),
              _filterTab('Artists (${_searchData.artists.length})'),
              const SizedBox(width: 8),
              _filterTab('Albums (${_searchData.albums.length})'),
              const SizedBox(width: 8),
              _filterTab('Playlists (${_searchData.playlists.length})'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            ),
          )
        else if (_searchData.tracks.isEmpty &&
            _searchData.artists.isEmpty &&
            _searchData.albums.isEmpty &&
            _searchData.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    color: Colors.white38,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_activeQuery"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Tracks')) &&
              _searchData.tracks.isNotEmpty) ...[
            const Text(
              'Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchData.tracks.length.clamp(0, 15),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = _searchData.tracks[index];
                return _MusicTrackRow(
                  track: track,
                  isPlaying: _playerController.currentTrack?.id == track.id &&
                      _playerController.isPlaying,
                  isCurrent: _playerController.currentTrack?.id == track.id,
                  onTap: () => _playerController.playTrack(
                    track,
                    playlistQueue: _searchData.tracks,
                    isRadio: _searchIsFromRadio,
                  ),
                  onMoreTap: () => _showAddToPlaylistMenu(track),
                  showDownload: !_searchIsFromRadio,
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Artists')) &&
              _searchData.artists.isNotEmpty) ...[
            const Text(
              'Artists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _searchData.artists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final artist = _searchData.artists[index];
                  return _MusicHoverable(
                    scaleFactor: 1.06,
                    child: GestureDetector(
                      onTap: () => _openArtistModal(artist.id),
                      child: Column(
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: artist.pictureUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 90,
                            child: Text(
                              artist.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Albums')) &&
              _searchData.albums.isNotEmpty) ...[
            const Text(
              'Albums',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (MediaQuery.sizeOf(context).width / sizing.cardWidth)
                    .floor()
                    .clamp(2, 6),
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
              ),
              itemCount: _searchData.albums.length.clamp(0, 12),
              itemBuilder: (context, index) {
                final album = _searchData.albums[index];
                return _MusicAlbumCard(
                  album: album,
                  onTap: () => _openAlbumModal(album.id),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Playlists')) &&
              _searchData.playlists.isNotEmpty) ...[
            const Text(
              'Playlists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (MediaQuery.sizeOf(context).width / sizing.cardWidth)
                    .floor()
                    .clamp(2, 6),
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
              ),
              itemCount: _searchData.playlists.length.clamp(0, 12),
              itemBuilder: (context, index) {
                final pl = _searchData.playlists[index];
                return _MusicPlaylistCard(
                  playlist: pl,
                  onTap: () => _openCuratedPlaylistModal(pl.id),
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _filterTab(String label) {
    final isSelected = _selectedFilter == label ||
        (_selectedFilter == 'All' && label == 'All') ||
        (label.startsWith(_selectedFilter) && _selectedFilter != 'All');

    return _MusicHoverable(
      scaleFactor: 1.05,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (label.startsWith('Tracks')) {
              _selectedFilter = 'Tracks';
            } else if (label.startsWith('Artists')) {
              _selectedFilter = 'Artists';
            } else if (label.startsWith('Albums')) {
              _selectedFilter = 'Albums';
            } else if (label.startsWith('Playlists')) {
              _selectedFilter = 'Playlists';
            } else {
              _selectedFilter = 'All';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF7C5CFF)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C5CFF)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectGenre(MusicGenre genre) async {
    setState(() {
      _selectedBrowseGenre = genre;
      _loadingGenreArtists = true;
      _genreArtists = [];
    });
    final artists = await _musicService.fetchGenreArtists(genre.id);
    if (!mounted || _selectedBrowseGenre?.id != genre.id) return;
    setState(() {
      _genreArtists = artists;
      _loadingGenreArtists = false;
    });
  }

  void _backToGenres() {
    setState(() {
      _selectedBrowseGenre = null;
      _genreArtists = [];
    });
  }

  Widget _buildGenresRow() {
    return _MusicHorizontalScrollSection(
      title: '🎵 Genres',
      height: 130,
      itemCount: _genres.length,
      itemBuilder: (context, index) {
        final g = _genres[index];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _MusicHoverable(
            scaleFactor: 1.04,
            child: GestureDetector(
              onTap: () => _selectGenre(g),
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.menu,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 170,
                    height: 130,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: g.pictureUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: const Color(0xFF7C5CFF)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.75),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              g.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
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
      },
    );
  }

  Widget _buildGenreArtistsView(MusicGenre genre) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: _backToGenres,
            ),
            const SizedBox(width: 4),
            Text(
              genre.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingGenreArtists)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            ),
          )
        else if (_genreArtists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No artists found for this genre.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _genreArtists.length,
            itemBuilder: (context, index) {
              final artist = _genreArtists[index];
              return _MusicHoverable(
                scaleFactor: 1.06,
                child: GestureDetector(
                  onTap: () => _openArtistModal(artist.id),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: artist.pictureUrl,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRadioView() {
    final radioGenres = [
      {'name': 'Pop Radio', 'color': const Color(0xFF7C5CFF), 'query': 'Pop Radio Hits'},
      {'name': 'Rap & Hip-Hop', 'color': const Color(0xFF7850FF), 'query': 'Hip Hop Radio'},
      {'name': 'Rock Mix', 'color': const Color(0xFFF99C00), 'query': 'Rock Radio'},
      {'name': 'Dance & Electro', 'color': const Color(0xFF00D294), 'query': 'Electro Radio'},
      {'name': 'R&B Station', 'color': const Color(0xFFE12AFB), 'query': 'R&B Radio'},
      {'name': 'Lofi & Ambient', 'color': const Color(0xFF00D2EF), 'query': 'Lofi Radio'},
      {'name': 'Heavy Metal Station', 'color': const Color(0xFFFB2C36), 'query': 'Metal Radio'},
      {'name': 'Jazz Club', 'color': const Color(0xFF625FFF), 'query': 'Jazz Radio'},
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Radio Stations & Live Streams',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Continuous music channels tuned to your mood.',
          style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 14),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: radioGenres.length,
          itemBuilder: (context, index) {
            final station = radioGenres[index];
            final color = station['color'] as Color;
            return _MusicHoverable(
              scaleFactor: 1.04,
              child: GestureDetector(
                onTap: () => _onGenreTap(station['query'] as String, isRadio: true),
                child: PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: color.withValues(alpha: 0.20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.radio_rounded, color: color, size: 28),
                        Text(
                          station['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLibraryView() {
    final liked = _libraryService.likedTracks;
    final playlists = _libraryService.userPlaylists;
    final recent = _libraryService.recentTracks;

    return LibraryTabs(
      title: 'Library',
      titleIcon: Icons.library_music_rounded,
      trailing: _MusicHoverable(
        scaleFactor: 1.05,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C5CFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => _showCreatePlaylistDialog(),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          label: const Text(
            'New Playlist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      tabs: [
        for (final section in LibrarySection.values)
          LibraryTab(
            label: section.label,
            icon: section.icon,
            builder: (_) => switch (section) {
              LibrarySection.saved => _buildSavedTab(liked, playlists),
              LibrarySection.inProgress => _buildQueueTab(),
              LibrarySection.history => _buildRecentTab(recent),
              LibrarySection.downloads => _MusicDownloadedTracksModal(
                  embedded: true,
                  onClose: () {},
                  onPlayTrack: (t, queue) =>
                      _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                ),
            },
          ),
      ],
    );
  }

  /// Songs, podcasts and playlists behind one sub-tab, so the Listen hub's
  /// Library is the same four tabs as every other hub's rather than five with
  /// its own names.
  Widget _buildSavedTab(
    List<MusicTrack> liked,
    List<UserPlaylist> playlists,
  ) {
    return SectionSubTabs(
      activeId: _savedType,
      onSelected: (id) => setState(() => _savedType = id),
      tabs: const [
        SubTab(id: 'songs', label: 'Songs', icon: Icons.favorite_rounded),
        SubTab(id: 'podcasts', label: 'Podcasts', icon: Icons.podcasts_rounded),
        SubTab(
          id: 'playlists',
          label: 'Playlists',
          icon: Icons.queue_music_rounded,
        ),
      ],
      child: switch (_savedType) {
        'podcasts' => _buildLikedPodcastsTab(),
        'playlists' => _buildPlaylistsTab(playlists),
        _ => _buildLikedSongsTab(liked),
      },
    );
  }

  /// Music has no "half-listened track" to resume, so Continue shows the
  /// queue you are currently working through -- the closest real equivalent,
  /// and something the Library previously offered no way to see at all.
  Widget _buildQueueTab() {
    final queue = _playerController.playlist;
    if (queue.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'Nothing queued',
        subtitle: 'Play an album or playlist and the rest of the queue shows '
            'up here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = queue[index];
        return _MusicTrackRow(
          track: track,
          isPlaying: _playerController.currentTrack?.id == track.id &&
              _playerController.isPlaying,
          isCurrent: _playerController.currentTrack?.id == track.id,
          onTap: () =>
              _playerController.playTrack(track, playlistQueue: queue),
          onMoreTap: () => _showAddToPlaylistMenu(track),
        );
      },
    );
  }

  Widget _buildLikedPodcastsTab() {
    final liked = PodcastLibraryService.instance.liked;
    if (liked.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.podcasts_rounded,
        title: 'No liked podcasts',
        subtitle: 'Tap the heart on a podcast to save it here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        final podcast = liked[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: podcast)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: podcast.artworkUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: podcast.artworkUrl, fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          color: Colors.white10,
                          child: const Icon(Icons.podcasts_rounded, color: Colors.white24, size: 40),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                podcast.name,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLikedSongsTab(List<MusicTrack> liked) {
    if (liked.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.favorite_rounded,
        title: 'No liked songs',
        subtitle: 'Tap the heart on a song to save it here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: liked.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = liked[index];
        return _MusicTrackRow(
          track: track,
          isPlaying: _playerController.currentTrack?.id == track.id &&
              _playerController.isPlaying,
          isCurrent: _playerController.currentTrack?.id == track.id,
          onTap: () => _playerController.playTrack(track, playlistQueue: liked),
          onMoreTap: () => _showAddToPlaylistMenu(track),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(List<UserPlaylist> playlists) {
    if (playlists.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.queue_music_rounded,
        title: 'No playlists yet',
        subtitle: 'Create a playlist to organize your music.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return _MusicHoverable(
          scaleFactor: 1.04,
          child: GestureDetector(
            onTap: () => _openUserPlaylistDetail(pl),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF13151F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: Color(0xFF7C5CFF),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pl.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${pl.tracks.length} tracks',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
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

  Widget _buildRecentTab(List<MusicTrack> recent) {
    if (recent.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.history_rounded,
        title: 'No recently played',
        subtitle: 'Songs you play will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: recent.length.clamp(0, 50),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = recent[index];
        return _MusicTrackRow(
          track: track,
          isPlaying: _playerController.currentTrack?.id == track.id &&
              _playerController.isPlaying,
          isCurrent: _playerController.currentTrack?.id == track.id,
          onTap: () => _playerController.playTrack(track, playlistQueue: recent),
          onMoreTap: () => _showAddToPlaylistMenu(track),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FPS-Friendly Hover Container
// ─────────────────────────────────────────────────────────────────────────────

class _MusicHoverable extends StatefulWidget {
  final Widget child;
  final double scaleFactor;

  const _MusicHoverable({
    required this.child,
    this.scaleFactor = 1.04,
  });

  @override
  State<_MusicHoverable> createState() => _MusicHoverableState();
}

class _MusicHoverableState extends State<_MusicHoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Horizontal Slider with Desktop Navigation Arrows
// ─────────────────────────────────────────────────────────────────────────────

class _MusicHorizontalScrollSection extends StatefulWidget {
  final String? title;
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _MusicHorizontalScrollSection({
    this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_MusicHorizontalScrollSection> createState() => _MusicHorizontalScrollSectionState();
}

class _MusicHorizontalScrollSectionState extends State<_MusicHorizontalScrollSection> {
  late final ScrollController _controller;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollButtons);
    _controller.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_controller.hasClients) return;
    final canLeft = _controller.position.pixels > 5;
    final canRight = _controller.position.pixels < _controller.position.maxScrollExtent - 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double multiplier) {
    if (!_controller.hasClients) return;
    final viewportWidth = _controller.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.75 * multiplier;
    final target = (_controller.position.pixels + scrollAmount)
        .clamp(0.0, _controller.position.maxScrollExtent);

    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              widget.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: widget.itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: widget.itemBuilder,
                ),

                // Desktop Left & Right Floating Arrows
                if (isDesktop) ...[
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _canScrollLeft && _isHovered ? 8 : -60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SliderArrow(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => _scroll(-1),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    right: _canScrollRight && _isHovered ? 8 : -60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SliderArrow(
                        icon: Icons.arrow_forward_ios_rounded,
                        onTap: () => _scroll(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicHeroBillboard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onPlayTap;
  final VoidCallback onSaveTap;
  final VoidCallback onAddToPlaylistTap;
  final bool isSaved;

  const _MusicHeroBillboard({
    required this.track,
    required this.onPlayTap,
    required this.onSaveTap,
    required this.onAddToPlaylistTap,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      height: isMobile ? 190 : 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.94),
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 18.0 : 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TOP CHART HIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    track.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 14 : 20),
                  Row(
                    children: [
                      _MusicHoverable(
                        scaleFactor: 1.06,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 10 : 12,
                            ),
                          ),
                          onPressed: onPlayTap,
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          label: const Text(
                            'Play Now',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LikeButton(
                        isLiked: isSaved,
                        onTap: onSaveTap,
                        style: LikeButtonStyle.icon,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      _MusicHoverable(
                        scaleFactor: 1.1,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                          ),
                          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                          onPressed: onAddToPlaylistTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicTrendingArtists extends StatelessWidget {
  final List<MusicArtist> artists;
  final Function(MusicArtist) onArtistTap;

  const _MusicTrendingArtists({
    required this.artists,
    required this.onArtistTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: '🌟 Trending Artists',
      height: 130,
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return _MusicHoverable(
          scaleFactor: 1.06,
          child: GestureDetector(
            onTap: () => onArtistTap(artist),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: artist.pictureUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 85,
                  child: Text(
                    artist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MusicAlbumsRow extends StatelessWidget {
  final String title;
  final List<MusicAlbum> albums;
  final Function(MusicAlbum) onAlbumTap;

  const _MusicAlbumsRow({
    required this.title,
    required this.albums,
    required this.onAlbumTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 200,
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _MusicAlbumCard(album: album, onTap: () => onAlbumTap(album));
      },
    );
  }
}

class _MusicPlaylistsRow extends StatelessWidget {
  final String title;
  final List<MusicPlaylist> playlists;
  final Function(MusicPlaylist) onPlaylistTap;

  const _MusicPlaylistsRow({
    required this.title,
    required this.playlists,
    required this.onPlaylistTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 200,
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return _MusicPlaylistCard(playlist: pl, onTap: () => onPlaylistTap(pl));
      },
    );
  }
}

class _MusicCategorySlider extends StatelessWidget {
  final String title;
  final List<MusicTrack> tracks;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicCategorySlider({
    required this.title,
    required this.tracks,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 215,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _MusicTrackCard(
          track: track,
          onTap: () => MusicPlayerController.instance.playTrack(
            track,
            playlistQueue: tracks,
          ),
          onMoreTap: () => onAddToPlaylist(track),
        );
      },
    );
  }
}

class _MusicTrackCard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _MusicTrackCard({
    required this.track,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHoverable(
      scaleFactor: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 145,
                      height: 145,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C5CFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicAlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _MusicAlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHoverable(
      scaleFactor: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: album.coverUrl,
                  width: 145,
                  height: 145,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                album.artistName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicPlaylistCard extends StatelessWidget {
  final MusicPlaylist playlist;
  final VoidCallback onTap;

  const _MusicPlaylistCard({
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHoverable(
      scaleFactor: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: playlist.coverUrl,
                  width: 145,
                  height: 145,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${playlist.trackCount} tracks',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicTrackRow extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;
  final bool showDownload;

  const _MusicTrackRow({
    required this.track,
    required this.isPlaying,
    required this.isCurrent,
    required this.onTap,
    required this.onMoreTap,
    this.showDownload = true,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHoverable(
      scaleFactor: 1.01,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: isCurrent
            ? const Color(0xFF7C5CFF).withValues(alpha: 0.15)
            : const Color(0xFF13151F),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            if (isCurrent)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFF7C5CFF),
                  size: 28,
                ),
              ),
          ],
        ),
        title: Text(
          track.title,
          style: TextStyle(
            color: isCurrent ? const Color(0xFF7C5CFF) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDownload) ...[
              MusicTrackDownloadButton(track: track),
              const SizedBox(width: 4),
            ],
            Text(
              track.formattedDuration,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
              onPressed: onMoreTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MusicCardSizing {
  final double cardWidth;
  final double totalHeight;

  const _MusicCardSizing(this.cardWidth, this.totalHeight);

  factory _MusicCardSizing.fromWidth(double width) {
    if (width >= 1200) return const _MusicCardSizing(170, 240);
    if (width >= 800) return const _MusicCardSizing(150, 215);
    if (width >= 450) return const _MusicCardSizing(140, 200);
    return const _MusicCardSizing(125, 185);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawers & Modals
// ─────────────────────────────────────────────────────────────────────────────

class _MusicLyricsDrawer extends StatelessWidget {
  final MusicTrack track;
  final MusicPlayerController playerController;
  final VoidCallback onClose;

  const _MusicLyricsDrawer({
    required this.track,
    required this.playerController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lyrics = playerController.currentLyrics;
    final activeIndex = playerController.activeLyricIndex;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: isMobile ? MediaQuery.sizeOf(context).width : 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.96),
          borderRadius: isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: Color(0xFF7C5CFF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Synced Lyrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (playerController.isLoadingLyrics)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
                ),
              )
            else if (!lyrics.isSynced && lyrics.plainLyrics.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No lyrics found for this track.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else if (lyrics.isSynced)
              Expanded(
                child: ListView.builder(
                  itemCount: lyrics.syncedLines.length,
                  itemBuilder: (context, index) {
                    final line = lyrics.syncedLines[index];
                    final isActive = index == activeIndex;
                    return GestureDetector(
                      onTap: () => playerController.seekTo(line.timestamp),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          line.text,
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFF7C5CFF)
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: isActive ? 18 : 15,
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    lyrics.plainLyrics,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicQueueDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const _MusicQueueDrawer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerController.instance;
    final queue = controller.playlist;
    final currentIndex = controller.currentIndex;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: isMobile ? MediaQuery.sizeOf(context).width : 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.96),
          borderRadius: isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.queue_music_rounded,
                  color: Color(0xFF7C5CFF),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Queue (${queue.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (queue.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearQueue,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (queue.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = index == currentIndex;
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isCurrent
                          ? const Color(0xFF7C5CFF).withValues(alpha: 0.2)
                          : const Color(0xFF13151F),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF7C5CFF) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                        onPressed: () => controller.removeFromQueue(index),
                      ),
                      onTap: () => controller.playTrack(track, playlistQueue: queue),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared full-screen dimmed-backdrop + glass panel shell used by every
/// music detail modal (artist/album/curated playlist/user playlist) --
/// identical across all four, only the content inside differs.
/// The full-screen shell shared by Artist/Album/Playlist detail pages, kept
/// in one place so they read as real screens (like every other detail view
/// in the app) instead of a fixed-size overlay popup.
class _MusicModalShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _MusicModalShell({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121C),
      body: SafeArea(
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class _MusicArtistDetailPage extends StatelessWidget {
  final MusicArtistDetails details;
  final MusicPlayerController playerController;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;
  final Function(String) onOpenAlbum;

  const _MusicArtistDetailPage({
    required this.details,
    required this.playerController,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final artist = details.artist;

    return _MusicModalShell(
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: artist.pictureUrl,
                  fit: BoxFit.cover,
                ),
              ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xFF0F121C),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 16,
                      child: Row(
                        children: [
                          Text(
                            artist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (details.topTracks.isNotEmpty)
                            ListenableBuilder(
                              listenable: playerController,
                              builder: (context, _) {
                                final isPlayingAll =
                                    playerController.isPlaying &&
                                        details.topTracks.any((t) =>
                                            t.id == playerController.currentTrack?.id);
                                return ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C5CFF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () => onPlayTrack(details.topTracks.first, details.topTracks),
                                  icon: Icon(
                                    isPlayingAll
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isPlayingAll ? 'Pause All' : 'Play All',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    children: [
                      if (details.topTracks.isNotEmpty) ...[
                        const Text(
                          'Top Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListenableBuilder(
                          listenable: playerController,
                          builder: (context, _) {
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: details.topTracks.length.clamp(0, 10),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final track = details.topTracks[index];
                                final isCurrent =
                                    playerController.currentTrack?.id == track.id;
                                return _MusicTrackRow(
                                  track: track,
                                  isPlaying: isCurrent && playerController.isPlaying,
                                  isCurrent: isCurrent,
                                  onTap: () => onPlayTrack(track, details.topTracks),
                                  onMoreTap: () => onAddToPlaylist(track),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (details.albums.isNotEmpty) ...[
                        const Text(
                          'Albums & Discography',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: details.albums.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final album = details.albums[index];
                              return _MusicAlbumCard(album: album, onTap: () => onOpenAlbum(album.id));
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MusicAlbumDetailPage extends StatelessWidget {
  final MusicAlbumDetails details;
  final MusicPlayerController playerController;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicAlbumDetailPage({
    required this.details,
    required this.playerController,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final album = details.album;
    final tracks = details.tracks;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return _MusicModalShell(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: album.coverUrl,
                        width: isMobile ? 80 : 120,
                        height: isMobile ? 80 : 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            album.artistName,
                            style: const TextStyle(
                              color: Color(0xFF7C5CFF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tracks.length} tracks • ${album.releaseDate}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ListenableBuilder(
                                  listenable: playerController,
                                  builder: (context, _) {
                                    final isAlbumPlaying =
                                        playerController.isPlaying &&
                                            tracks.any((t) =>
                                                t.id == playerController.currentTrack?.id);
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C5CFF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () => onPlayTrack(tracks.first, tracks),
                                      icon: TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 200),
                                        tween: Tween<double>(
                                          begin: 0,
                                          end: isAlbumPlaying ? 1 : 0,
                                        ),
                                        builder: (context, value, _) => AnimatedIcon(
                                          icon: AnimatedIcons.play_pause,
                                          progress: AlwaysStoppedAnimation(value),
                                          color: Colors.white,
                                        ),
                                      ),
                                      label: Text(
                                        isAlbumPlaying ? 'Pause Album' : 'Play Album',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: album.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${album.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download Album'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: playerController,
                    builder: (context, _) {
                      return ListView.separated(
                        itemCount: tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final isCurrent =
                              playerController.currentTrack?.id == track.id;
                          return _MusicTrackRow(
                            track: track,
                            isPlaying: isCurrent && playerController.isPlaying,
                            isCurrent: isCurrent,
                            onTap: () => onPlayTrack(track, tracks),
                            onMoreTap: () => onAddToPlaylist(track),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _MusicCuratedPlaylistDetailPage extends StatelessWidget {
  final MusicPlaylistDetails details;
  final MusicPlayerController playerController;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicCuratedPlaylistDetailPage({
    required this.details,
    required this.playerController,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final playlist = details.playlist;
    final tracks = details.tracks;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return _MusicModalShell(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverUrl,
                        width: isMobile ? 80 : 120,
                        height: isMobile ? 80 : 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Curated by ${playlist.creatorName} • ${tracks.length} tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ListenableBuilder(
                                  listenable: playerController,
                                  builder: (context, _) {
                                    final isPlaylistPlaying =
                                        playerController.isPlaying &&
                                            tracks.any((t) =>
                                                t.id == playerController.currentTrack?.id);
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C5CFF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () => onPlayTrack(tracks.first, tracks),
                                      icon: Icon(
                                        isPlaylistPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        isPlaylistPlaying
                                            ? 'Pause Playlist'
                                            : 'Play Playlist',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: playlist.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${playlist.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download Playlist'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: playerController,
                    builder: (context, _) {
                      return ListView.separated(
                        itemCount: tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final isCurrent =
                              playerController.currentTrack?.id == track.id;
                          return _MusicTrackRow(
                            track: track,
                            isPlaying: isCurrent && playerController.isPlaying,
                            isCurrent: isCurrent,
                            onTap: () => onPlayTrack(track, tracks),
                            onMoreTap: () => onAddToPlaylist(track),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _MusicUserPlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  final MusicLibraryService libraryService;
  final MusicPlayerController playerController;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;

  const _MusicUserPlaylistDetailPage({
    required this.playlistId,
    required this.libraryService,
    required this.playerController,
    required this.onPlayTrack,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    // Rebuilds off the library service so removing a track (or the playlist
    // itself, from elsewhere) is reflected live instead of the page holding
    // a stale snapshot.
    return ListenableBuilder(
      listenable: libraryService,
      builder: (context, _) {
        final playlist = libraryService.userPlaylists
            .where((p) => p.id == playlistId)
            .firstOrNull;
        if (playlist == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
          return const _MusicModalShell(child: SizedBox.shrink());
        }
        final tracks = playlist.tracks;

        return _MusicModalShell(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: isMobile ? 70 : 100,
                      height: isMobile ? 70 : 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: const Color(0xFF7C5CFF),
                        size: isMobile ? 36 : 48,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Custom Playlist • ${tracks.length} tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ListenableBuilder(
                                  listenable: playerController,
                                  builder: (context, _) {
                                    final isPlaylistPlaying =
                                        playerController.isPlaying &&
                                            tracks.any((t) =>
                                                t.id == playerController.currentTrack?.id);
                                    return ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C5CFF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () => onPlayTrack(tracks.first, tracks),
                                      icon: Icon(
                                        isPlaylistPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        isPlaylistPlaying
                                            ? 'Pause Playlist'
                                            : 'Play Playlist',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: playlist.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${playlist.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download All'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No tracks in this playlist yet',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListenableBuilder(
                          listenable: playerController,
                          builder: (context, _) {
                            return ListView.separated(
                          itemCount: tracks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            final isCurrent =
                                playerController.currentTrack?.id == track.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: isCurrent
                                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.15)
                                  : const Color(0xFF13151F),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: track.coverUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(
                                track.title,
                                style: TextStyle(
                                  color: isCurrent
                                      ? const Color(0xFF7C5CFF)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                track.artist,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                                onPressed: () => libraryService.removeTrackFromPlaylist(
                                  playlistId,
                                  track.id,
                                ),
                              ),
                              onTap: () => onPlayTrack(track, tracks),
                            );
                          },
                        );
                          },
                        ),
                ),
              ],
            ),
        );
      },
    );
  }
}

class _AudioSourceSelectorButton extends StatelessWidget {
  const _AudioSourceSelectorButton();

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController.instance;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isFlac = player.audioSource == MusicAudioSource.flac;

        return _MusicHoverable(
          scaleFactor: 1.05,
          child: InkWell(
            onTap: () => _showAudioSourceDialog(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isFlac
                    ? const Color(0xFF00D2EF).withValues(alpha: 0.12)
                    : const Color(0xFFFF3366).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFlac
                      ? const Color(0xFF00D2EF).withValues(alpha: 0.4)
                      : const Color(0xFFFF3366).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFlac ? Icons.diamond_rounded : Icons.play_circle_fill_rounded,
                    color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF3366),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFlac ? 'FLAC' : 'YouTube',
                    style: TextStyle(
                      color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF6688),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF6688),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showAudioSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final player = MusicPlayerController.instance;

        return ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final isFlac = player.audioSource == MusicAudioSource.flac;

            return PerformanceLiquidLens(
              style: PerformanceGlassStyles.sheet,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F111D).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF7C5CFF), size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio Source & Quality',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose your preferred music extraction engine',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sourceOptionCard(
                      title: 'FLAC Lossless (Qobuz Hi-Res)',
                      subtitle: 'Studio master quality up to 24-bit/192kHz with zero compression',
                      icon: Icons.diamond_rounded,
                      iconColor: const Color(0xFF00D2EF),
                      isSelected: isFlac,
                      badge: 'LOSSLESS',
                      badgeColor: const Color(0xFF00D2EF),
                      onTap: () {
                        player.setAudioSource(MusicAudioSource.flac);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 12),
                    _sourceOptionCard(
                      title: 'YouTube Audio',
                      subtitle: 'High-speed audio extraction with intelligent track & duration matching',
                      icon: Icons.play_circle_fill_rounded,
                      iconColor: const Color(0xFFFF3366),
                      isSelected: !isFlac,
                      badge: 'FAST',
                      badgeColor: const Color(0xFFFF3366),
                      onTap: () {
                        player.setAudioSource(MusicAudioSource.youtube);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _sourceOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return _MusicHoverable(
      scaleFactor: 1.02,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? iconColor.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: iconColor, size: 22)
              else
                const Icon(Icons.radio_button_unchecked_rounded, color: Colors.white30, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicExpandedPlayer extends StatefulWidget {
  final MusicPlayerController playerController;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onCollapse;
  final VoidCallback onQueueTap;
  final VoidCallback onAddToPlaylist;

  const _MusicExpandedPlayer({
    required this.playerController,
    required this.isSaved,
    required this.onToggleSave,
    required this.onCollapse,
    required this.onQueueTap,
    required this.onAddToPlaylist,
  });

  @override
  State<_MusicExpandedPlayer> createState() => _MusicExpandedPlayerState();
}

class _MusicExpandedPlayerState extends State<_MusicExpandedPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.playerController.isPlaying) {
      _discAnimController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MusicExpandedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerController.isPlaying && !_discAnimController.isAnimating) {
      _discAnimController.repeat();
    } else if (!widget.playerController.isPlaying && _discAnimController.isAnimating) {
      _discAnimController.stop();
    }
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.playerController.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final palette = AppThemeService.currentPalette.value;
    final preset = MusicSettings.selectedFullscreenPreset.value;
    final seekStyle = MusicSettings.customSeekbarStyle.value;
    final artStyle = MusicSettings.customArtworkStyle.value;
    final order = MusicSettings.componentOrderFullscreen.value;

    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 800;
    final artSize = isDesktop
        ? 230.0
        : math.min(screenSize.width * 0.75, screenSize.height * 0.38);

    final playerBody = Column(
      children: [
        // Top Navigation & Actions Bar
        Row(
          children: [
            _MusicHoverable(
              scaleFactor: 1.1,
              child: IconButton(
                icon: Icon(
                  isDesktop ? Icons.close_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: isDesktop ? 24 : 32,
                ),
                onPressed: widget.onCollapse,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _AudioSourceSelectorButton._showAudioSourceDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.playerController.isCurrentTrackLossless
                      ? const Color(0xFF00D2EF).withValues(alpha: 0.15)
                      : const Color(0xFFFF3366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.playerController.isCurrentTrackLossless
                        ? const Color(0xFF00D2EF).withValues(alpha: 0.4)
                        : const Color(0xFFFF3366).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.playerController.isCurrentTrackLossless
                          ? Icons.diamond_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 13,
                      color: widget.playerController.isCurrentTrackLossless
                          ? const Color(0xFF00D2EF)
                          : const Color(0xFFFF6688),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.playerController.currentQualityLabel.toUpperCase(),
                      style: TextStyle(
                        color: widget.playerController.isCurrentTrackLossless
                            ? const Color(0xFF00D2EF)
                            : const Color(0xFFFF6688),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: widget.playerController.isCurrentTrackLossless
                          ? const Color(0xFF00D2EF)
                          : const Color(0xFFFF6688),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!widget.playerController.isCurrentTrackFromRadio)
              _MusicHoverable(
                scaleFactor: 1.1,
                child: MusicTrackDownloadButton(
                  track: track,
                  iconSize: 22,
                  idleColor: Colors.white,
                ),
              ),
            _MusicHoverable(
              scaleFactor: 1.1,
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onPressed: widget.onAddToPlaylist,
              ),
            ),
          ],
        ),
        if (!isDesktop) const Spacer() else const SizedBox(height: 12),

        // Preset-based or Custom Arranged Body
        if (preset == MusicFullscreenPreset.customStudio)
          ...order.map((key) => _buildCustomComponent(key, track, palette, seekStyle, artStyle, artSize))
        else
          ..._buildPresetBody(preset, track, palette, seekStyle, artSize),

        if (!isDesktop) const Spacer() else const SizedBox(height: 12),
      ],
    );

    if (isDesktop) {
      // Material ancestor: this player is pushed via MaterialPageRoute, which
      // does NOT itself provide one (that's a common misconception -- it
      // only supplies transition/Navigator behavior). Without it, every
      // InkWell inside (e.g. the quality-badge selector below) throws "No
      // Material widget found" the moment it renders.
      return Material(
        type: MaterialType.transparency,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // Dismissible Scrim with blur
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onCollapse,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          // Floating Modal Card
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: math.min(740, screenSize.height * 0.88),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0D14),
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
                      // Ambient blurred cover backdrop
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.25,
                          child: CachedNetworkImage(
                            imageUrl: track.coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                          child: Container(
                            color: const Color(0xFF0B0D14).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                        child: playerBody,
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

    // Rebuild on playback/position changes so the progress slider and times
    // stay live inside the expanded player.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
      animation: widget.playerController,
      builder: (context, _) {
        return Container(
      color: const Color(0xFF07090F),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient blurred cover backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: const Color(0xFF07090F).withValues(alpha: 0.85),
              ),
            ),
          ),

          // Main Expanded Player Column
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
              child: playerBody,
            ),
          ),
        ],
      ),
        );
      },
      ),
    );
  }

  List<Widget> _buildPresetBody(
    MusicFullscreenPreset preset,
    MusicTrack track,
    AppThemePalette palette,
    MusicSeekbarStyle seekStyle,
    double artSize,
  ) {
    return [
      // Artwork Section
      if (preset == MusicFullscreenPreset.vinylStudio)
        _buildVinylDiscArtwork(track, artSize, palette)
      else if (preset == MusicFullscreenPreset.cyberWaveform)
        _buildCyberWaveArtwork(track, artSize, palette)
      else if (preset == MusicFullscreenPreset.liquidGlassNeo)
        _buildLiquidGlassArtwork(track, artSize, palette)
      else
        _buildCinematicArtwork(track, artSize),

      const SizedBox(height: 24),

      // Track & Artist Title Row with Like Button
      _buildTitleRow(track),

      const SizedBox(height: 16),

      // Scrubber Canvas
      MusicWaveformSeekbar(
        position: widget.playerController.position,
        duration: widget.playerController.duration,
        isPlaying: widget.playerController.isPlaying,
        style: preset == MusicFullscreenPreset.cyberWaveform
            ? MusicSeekbarStyle.waveformEqualizer
            : (preset == MusicFullscreenPreset.liquidGlassNeo
                ? MusicSeekbarStyle.liquidGlassSlider
                : seekStyle),
        onSeek: (pos) => widget.playerController.seekTo(pos),
      ),

      const SizedBox(height: 16),

      // Main Controls
      _buildPlaybackControlsRow(palette),
    ];
  }

  Widget _buildCustomComponent(
    String key,
    MusicTrack track,
    AppThemePalette palette,
    MusicSeekbarStyle seekStyle,
    MusicArtworkStyle artStyle,
    double artSize,
  ) {
    switch (key) {
      case 'artwork':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCustomArtworkByStyle(track, artSize, palette, artStyle),
        );
      case 'title':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTitleRow(track),
        );
      case 'qualityBadge':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00D2EF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00D2EF).withValues(alpha: 0.4)),
            ),
            child: Text(
              '${widget.playerController.currentQualityLabel.toUpperCase()} • HI-RES LOSSLESS AUDIO',
              style: const TextStyle(color: Color(0xFF00D2EF), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
          ),
        );
      case 'seekbar':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MusicWaveformSeekbar(
            position: widget.playerController.position,
            duration: widget.playerController.duration,
            isPlaying: widget.playerController.isPlaying,
            style: seekStyle,
            onSeek: (pos) => widget.playerController.seekTo(pos),
          ),
        );
      case 'mainControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlaybackControlsRow(palette),
        );
      case 'secondaryControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.format_quote_rounded, color: Colors.white70, size: 22),
                onPressed: widget.onCollapse,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 22),
                onPressed: widget.onQueueTap,
              ),
            ],
          ),
        );
      case 'extraActions':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onQueueTap,
                icon: Icon(Icons.queue_music_rounded, color: palette.primaryColor, size: 16),
                label: const Text('Playing Queue', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTitleRow(MusicTrack track) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: const TextStyle(color: Colors.white60, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Not a LikeButton: the fullscreen player runs its like through the
        // studio's configurable hover physics, which LikeButton would drop.
        // It follows the same rules -- kLikedColor, filled when liked, no
        // fill behind it -- via the shared constant, so the colour cannot
        // drift even though the widget differs.
        MusicInteractivePhysicsButton(
          effect: MusicSettings.customHoverEffect.value,
          glowColor: kLikedColor,
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onToggleSave,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Semantics(
              button: true,
              toggled: widget.isSaved,
              label: widget.isSaved ? 'Remove from liked' : 'Add to liked',
              child: Icon(
                widget.isSaved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: widget.isSaved ? kLikedColor : Colors.white70,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControlsRow(AppThemePalette palette) {
    final hoverEffect = MusicSettings.customHoverEffect.value;
    final playBtnStyle = MusicSettings.customPlayButtonStyle.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MusicVolumeControl(
          volume: widget.playerController.volume,
          onVolumeChanged: widget.playerController.setVolume,
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.playPrevious,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(32),
          onTap: widget.playerController.togglePlayPause,
          child: widget.playerController.isLoading
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: palette.primaryColor, strokeWidth: 3),
                )
              : _buildExpandedPlayButtonIcon(playBtnStyle, palette),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.playNext,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.toggleRepeat,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              widget.playerController.repeatMode == MusicRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: widget.playerController.repeatMode != MusicRepeatMode.off ? palette.primaryColor : Colors.white38,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedPlayButtonIcon(MusicPlayButtonStyle style, AppThemePalette palette) {
    final isPlaying = widget.playerController.isPlaying;
    final icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;

    if (style == MusicPlayButtonStyle.liquidGlassNeo) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: palette.primaryColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      );
    }

    if (style == MusicPlayButtonStyle.neonSquare) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
          boxShadow: [
            BoxShadow(color: palette.primaryColor.withValues(alpha: 0.6), blurRadius: 20),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      );
    }

    // Default: Circle Glow
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
        boxShadow: [
          BoxShadow(color: palette.primaryColor.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 2),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  Widget _buildVinylDiscArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return AnimatedBuilder(
      animation: _discAnimController,
      builder: (context, child) => Transform.rotate(
        angle: widget.playerController.isPlaying ? _discAnimController.value * 2 * math.pi : 0,
        child: child,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10131E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 4),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.4),
              blurRadius: 36,
            ),
          ],
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: CachedNetworkImage(
              imageUrl: track.coverUrl,
              width: size * 0.44,
              height: size * 0.44,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCyberWaveArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.45),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CachedNetworkImage(
          imageUrl: track.coverUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLiquidGlassArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.35),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CachedNetworkImage(
            imageUrl: track.coverUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildCinematicArtwork(MusicTrack track, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CachedNetworkImage(
        imageUrl: track.coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildCustomArtworkByStyle(MusicTrack track, double size, AppThemePalette palette, MusicArtworkStyle style) {
    if (style == MusicArtworkStyle.vinylSpinningDisc) {
      return _buildVinylDiscArtwork(track, size, palette);
    }
    if (style == MusicArtworkStyle.floatingCard3D) {
      return _buildLiquidGlassArtwork(track, size, palette);
    }
    if (style == MusicArtworkStyle.glowSphere) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 36,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: CachedNetworkImage(
            imageUrl: track.coverUrl,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return _buildCinematicArtwork(track, size);
  }
}

class _MusicVolumeControl extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const _MusicVolumeControl({
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  State<_MusicVolumeControl> createState() => _MusicVolumeControlState();
}

class _MusicVolumeControlState extends State<_MusicVolumeControl> {
  bool _showSlider = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            widget.volume == 0
                ? Icons.volume_off_rounded
                : (widget.volume > 0.5 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
            color: Colors.white38,
          ),
          onPressed: () => setState(() => _showSlider = !_showSlider),
        ),
        if (_showSlider)
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: Color(0xFF7C5CFF),
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

class _MusicShortcutsModal extends StatelessWidget {
  final VoidCallback onClose;

  const _MusicShortcutsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      {'key': 'Space / K', 'desc': 'Toggle Play / Pause'},
      {'key': 'J', 'desc': 'Seek -5 seconds backward'},
      {'key': 'L', 'desc': 'Seek +5 seconds forward'},
      {'key': 'M', 'desc': 'Toggle Mute / Unmute'},
      {'key': 'Q', 'desc': 'Toggle Queue Drawer'},
      {'key': 'F', 'desc': 'Toggle Fullscreen Now Playing'},
      {'key': '? / Shift + /', 'desc': 'Show Shortcuts'},
    ];

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.keyboard_rounded, color: Color(0xFF7C5CFF), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final s in shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1E2B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            s['key']!,
                            style: const TextStyle(
                              color: Color(0xFF7C5CFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          s['desc']!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
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

class _MusicDownloadedTracksModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;
  final bool embedded;

  const _MusicDownloadedTracksModal({
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
    this.embedded = false,
  });

  @override
  State<_MusicDownloadedTracksModal> createState() => _MusicDownloadedTracksModalState();
}

class _MusicDownloadedTracksModalState extends State<_MusicDownloadedTracksModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = MusicDownloadService.instance;
    final allDownloaded = downloadService.downloadedTracks;
    final queue = downloadService.queue;
    final totalBytes = downloadService.totalDownloadedSizeBytes;
    final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    final filtered = _searchQuery.isEmpty
        ? allDownloaded
        : allDownloaded.where((t) =>
            t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.album.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: isMobile ? 48 : 56,
                      height: isMobile ? 48 : 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0083B0), Color(0xFF00B4DB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.offline_pin_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downloaded Songs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 19 : 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${allDownloaded.length} offline tracks • $sizeMb MB storage',
                            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.embedded)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: widget.onClose,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Active Download Queue Card
                if (queue.isNotEmpty) ...[
                  _buildQueueBanner(queue, downloadService),
                  const SizedBox(height: 12),
                ],

                // Action Bar: Play All, Shuffle, Search
                Row(
                  children: [
                    if (filtered.isNotEmpty) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4DB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          final tracks = filtered.map((d) => d.toMusicTrack()).toList();
                          widget.onPlayTrack(tracks.first, tracks);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          final tracks = filtered.map((d) => d.toMusicTrack()).toList()..shuffle();
                          widget.onPlayTrack(tracks.first, tracks);
                        },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('Shuffle'),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: isMobile ? 140 : 200,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search offline...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00B4DB), size: 16),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 6),

                // Downloaded Tracks List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.cloud_download_rounded,
                                color: Colors.white24,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No downloaded tracks match "$_searchQuery"'
                                    : 'No offline downloads yet.\nTap the download icon on any song, album, or playlist to listen offline.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.4),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final track = item.toMusicTrack();
                            final itemSizeMb = (item.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
                            final isFlac = item.format.toLowerCase() == 'flac';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              tileColor: const Color(0xFF13151F),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.localCoverPath.isNotEmpty && File(item.localCoverPath).existsSync()
                                    ? Image.file(
                                        File(item.localCoverPath),
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildFallbackCover(track),
                                      )
                                    : _buildFallbackCover(track),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.artist} • ${item.album}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isFlac
                                          ? const Color(0xFF7C5CFF).withValues(alpha: 0.25)
                                          : const Color(0xFF00B0FF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isFlac ? 'FLAC' : item.format.toUpperCase(),
                                      style: TextStyle(
                                        color: isFlac ? const Color(0xFFB39DDB) : const Color(0xFF00E5FF),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$itemSizeMb MB',
                                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                                    tooltip: 'Delete from downloads',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          backgroundColor: const Color(0xFF161924),
                                          title: const Text('Delete Downloaded Song', style: TextStyle(color: Colors.white)),
                                          content: Text('Delete "${item.title}" from offline storage?', style: const TextStyle(color: Colors.white70)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c, false),
                                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await downloadService.deleteDownloadedTrack(item.id);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                final allTracks = filtered.map((d) => d.toMusicTrack()).toList();
                                widget.onPlayTrack(track, allTracks);
                              },
                            );
                          },
                        ),
                ),
              ],
            );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: content,
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 760,
            height: isMobile ? size.height * 0.88 : 660,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(22),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCover(MusicTrack track) {
    if (track.coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: track.coverUrl,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 46,
          height: 46,
          color: const Color(0xFF1B1E2B),
          child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
        ),
      );
    }
    return Container(
      width: 46,
      height: 46,
      color: const Color(0xFF1B1E2B),
      child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
    );
  }

  Widget _buildQueueBanner(List<MusicDownloadTask> queue, MusicDownloadService service) {
    final activeTask = queue.firstWhere(
      (t) => t.status == MusicDownloadStatus.downloading || t.status == MusicDownloadStatus.extracting,
      orElse: () => queue.first,
    );
    final isExtracting = activeTask.status == MusicDownloadStatus.extracting;
    final progress = activeTask.progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0083B0).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00B4DB).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: isExtracting ? null : progress,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isExtracting
                      ? 'Extracting stream for "${activeTask.track.title}"...'
                      : 'Downloading "${activeTask.track.title}" (${(progress * 100).toInt()}%)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${queue.length} in queue',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => service.cancelTask(activeTask.track.id),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isExtracting ? null : progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
