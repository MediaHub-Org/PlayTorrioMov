import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_colors.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../models/movie/movie.dart';
import '../../models/movie/link.dart';
import '../../models/movie/video.dart';
import '../../models/movie/movie_detail.dart';

import '../../models/stream/stream_model.dart';
import './player_screen.dart';
import '../../services/app_breakpoints.dart';
import '../../services/sources/source_filter_settings.dart';
import '../../services/stream/stream_service.dart';
import '../../utils/download/download_launcher.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../widgets/common/horizontal_slider_scroll.dart';
import '../../widgets/player/performance_liquid_lens.dart';
import '../../widgets/common/source_badges.dart';
import '../settings/settings_page.dart';
import '../details/details_page.dart';
import '../../utils/navigation/route_transitions.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
class _C {
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF13151C);
  static const surfaceLight = Color(0xFF1A1D26);
  // A getter, not a `static final`: a static final is initialized once on
  // its first read and never again, which would pin the accent to
  // whichever palette was active the first time a player opened.
  static Color get accent => AppColors.accent;
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFAAAAAF);
  static const textTertiary = Color(0xFF66666B);
  static const gold = Color(0xFFFFC107);
}

class _S {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

// ---------------------------------------------------------------------------
// WatchScreen
// ---------------------------------------------------------------------------
class WatchScreen extends StatefulWidget {
  final MovieDetail detail;
  final Video? selectedEpisode;
  final String type;
  final Duration? initialPosition;

  final bool isCollection;

  const WatchScreen({
    super.key,
    required this.detail,
    this.selectedEpisode,
    required this.type,
    this.initialPosition,
    this.isCollection = false,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with SingleTickerProviderStateMixin {
  bool get _isCollection =>
      widget.isCollection ||
      widget.type == 'collections' ||
      widget.type == 'collection' ||
      widget.detail.isCollection;

  // Stream sources
  final List<StreamSource> _sources = [];
  final List<StreamSource> _pendingSources = [];
  Timer? _sourceBatchTimer;
  bool _isLoadingSources = true;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Scroll
  final ScrollController _sourcesScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
    SourceFilterSettings.audioLanguages.addListener(_onSourceFilterChanged);
    SourceFilterSettings.qualities.addListener(_onSourceFilterChanged);
    _loadStreams();
  }

  @override
  void dispose() {
    SourceFilterSettings.audioLanguages.removeListener(_onSourceFilterChanged);
    SourceFilterSettings.qualities.removeListener(_onSourceFilterChanged);
    _sourceBatchTimer?.cancel();
    _animController.dispose();
    _sourcesScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStreams() async {
    final streamId = widget.selectedEpisode?.id ?? widget.detail.id;

    // 1. Immediately inject any embedded streams from the video (e.g. Torbox/Debrid direct streams)
    if (widget.selectedEpisode != null && widget.selectedEpisode!.streams.isNotEmpty) {
      _pendingSources.addAll(widget.selectedEpisode!.streams);
      _flushPendingSources();
    }

    final isColl = _isCollection;
    final effectiveType = isColl ? 'movie' : widget.type;
    final effectiveTitle = (isColl && widget.selectedEpisode != null)
        ? widget.selectedEpisode!.title
        : widget.detail.name;
    final epReleased = widget.selectedEpisode?.released;
    final effectiveYear = (isColl && epReleased != null && epReleased.length >= 4)
        ? int.tryParse(epReleased.substring(0, 4))
        : int.tryParse(widget.detail.year ?? '');
    final effectiveSeason = isColl ? null : widget.selectedEpisode?.season;
    final effectiveEpisode = isColl ? null : widget.selectedEpisode?.episode;

    try {
      await for (final source in StreamService.fetchStreams(
        type: effectiveType,
        id: streamId,
        title: effectiveTitle,
        year: effectiveYear,
        season: effectiveSeason,
        episode: effectiveEpisode,
      )) {
        if (!mounted) return;
        _pendingSources.add(source);
        _sourceBatchTimer ??= Timer(
          const Duration(milliseconds: 60),
          _flushPendingSources,
        );
      }
    } catch (e) {
      // Not a per-scraper failure -- fetchStreams already swallows those and
      // keeps going. Reaching here means the aggregate stream itself died, so
      // the list below stops at whatever had arrived. Silently, it looked
      // identical to a title genuinely having no sources.
      debugPrint('[WatchScreen] Source search failed: $e');
    }

    _flushPendingSources();
    if (mounted && _isLoadingSources) {
      setState(() => _isLoadingSources = false);
    }
  }

  void _flushPendingSources() {
    _sourceBatchTimer?.cancel();
    _sourceBatchTimer = null;
    if (!mounted || _pendingSources.isEmpty) return;

    final batch = List<StreamSource>.of(_pendingSources);
    _pendingSources.clear();
    setState(() {
      _sources.addAll(batch);
      _isLoadingSources = false;
    });
  }

  /// Called by the player's auto-next dialog. Pops the player and re-opens the
  /// watch screen for the next episode (season/episode +1).
  void _playNextEpisode() {
    final ep = widget.selectedEpisode;
    if (ep == null) return;

    final nextEpisode = Video(
      id: ep.id,
      title: ep.title,
      season: ep.season,
      episode: (ep.episode ?? 0) + 1,
      released: ep.released,
      thumbnail: ep.thumbnail,
      overview: ep.overview,
    );

    // WatchScreen lives on the hub's nested navigator, but the player that's
    // actually visible right now was pushed fullscreen onto the root one
    // (see pushFullscreen in utils/fullscreen_navigator.dart). A plain
    // Navigator.pushReplacement(context, ...) would replace the buried
    // nested-navigator route instead of the visible fullscreen one, so
    // "Play Next" would silently do nothing. Replace on the root instead.
    pushFullscreenReplacement(
      CinematicSlideRoute(
        page: WatchScreen(
          detail: widget.detail,
          selectedEpisode: nextEpisode,
          type: widget.type,
        ),
      ),
    );
  }

  String? _selectedAddonFilter;
  String? _selectedSizeFilter;

  /// The audio-language and quality filters live in [SourceFilterSettings]
  /// rather than here, so the choice made on this screen is the same one the
  /// Sources & Filters settings page shows, and it survives opening the next
  /// episode. The getters keep the call sites reading like the local fields
  /// they replaced.
  List<String> get _selectedAudioFilters =>
      SourceFilterSettings.audioLanguages.value;
  List<String> get _selectedQualityFilters =>
      SourceFilterSettings.qualities.value;

  /// Repaints when either shared filter changes, including a change made on
  /// the settings page while this screen sits underneath it.
  void _onSourceFilterChanged() {
    if (mounted) setState(() {});
  }

  List<StreamSource> get _filteredSources {
    var list = List<StreamSource>.from(_sources);
    if (_selectedAddonFilter != null) {
      list = list.where((s) => s.addonName == _selectedAddonFilter).toList();
    }
    if (_selectedSizeFilter != null) {
      switch (_selectedSizeFilter) {
        case '<1gb':
          list = list.where((s) {
            final sz = s.sizeBytes;
            return sz != null && sz < 1024 * 1024 * 1024;
          }).toList();
          break;
        case '1-5gb':
          list = list.where((s) {
            final sz = s.sizeBytes;
            return sz != null && sz >= 1024 * 1024 * 1024 && sz <= 5.0 * 1024 * 1024 * 1024;
          }).toList();
          break;
        case '5-15gb':
          list = list.where((s) {
            final sz = s.sizeBytes;
            return sz != null && sz > 5.0 * 1024 * 1024 * 1024 && sz <= 15.0 * 1024 * 1024 * 1024;
          }).toList();
          break;
        case '15-30gb':
          list = list.where((s) {
            final sz = s.sizeBytes;
            return sz != null && sz > 15.0 * 1024 * 1024 * 1024 && sz <= 30.0 * 1024 * 1024 * 1024;
          }).toList();
          break;
        case '>30gb':
          list = list.where((s) {
            final sz = s.sizeBytes;
            return sz != null && sz > 30.0 * 1024 * 1024 * 1024;
          }).toList();
          break;
      }
    }

    // Filter by audio language / dub. Any of the selected languages matches,
    // and an empty selection is no filter at all.
    if (_selectedAudioFilters.isNotEmpty) {
      list = list
          .where((s) => s.hasAnyAudioLanguage(
                _selectedAudioFilters,
                mediaTitle: widget.detail.name,
              ))
          .toList();
    }

    // Filter by video quality / resolution
    if (_selectedQualityFilters.isNotEmpty) {
      list = list
          .where((s) => s.hasAnyQuality(_selectedQualityFilters))
          .toList();
    }

    if (_selectedSizeFilter == 'largest') {
      list.sort((a, b) => (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0));
    } else if (_selectedSizeFilter == 'smallest') {
      list.sort((a, b) => (a.sizeBytes ?? double.infinity).compareTo(b.sizeBytes ?? double.infinity));
    } else {
      list.sort((a, b) => b.qualityRank.compareTo(a.qualityRank));
    }
    return list;
  }

  String _getSizeFilterLabel(String? filter) {
    switch (filter) {
      case '<1gb':
        return '< 1 GB';
      case '1-5gb':
        return '1–5 GB';
      case '5-15gb':
        return '5–15 GB';
      case '15-30gb':
        return '15–30 GB';
      case '>30gb':
        return '> 30 GB';
      case 'largest':
        return 'Largest';
      case 'smallest':
        return 'Smallest';
      default:
        return 'All Sizes';
    }
  }

  bool _isDesktop() =>
      AppBreakpoints.of(context) == ScreenTier.desktop;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final bgUrl = widget.detail.background ?? widget.detail.poster;
    final isDesktop = _isDesktop();

    final background = Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: _C.bg)),
        if (bgUrl != null) _buildBackdrop(bgUrl, screenSize, isDesktop),
      ],
    );
    final content = Stack(
      children: [
        SafeArea(
          child: isDesktop
              ? _buildDesktopLayout(screenSize)
              : _buildMobileLayout(screenSize),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: _buildBackButton(),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(children: [background, content]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Backdrop
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBackdrop(String url, Size screenSize, bool isDesktop) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const ColoredBox(color: _C.bg),
          ),
          // Left-to-right dimming: dark on left (text side), lighter on right
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _C.bg.withValues(alpha: isDesktop ? 0.92 : 0.88),
                  _C.bg.withValues(alpha: isDesktop ? 0.70 : 0.60),
                  _C.bg.withValues(alpha: isDesktop ? 0.20 : 0.15),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Bottom vertical gradient for legibility
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _C.bg.withValues(alpha: 0.30),
                  _C.bg.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop: side-by-side 60/40
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(Size screenSize) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 60,
            left: 48,
            right: 0,
            bottom: 24,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: info region
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: _buildInfoRegion(isDesktop: true),
                ),
              ),
              const SizedBox(width: 32),
              // Right: sources panel (extends to right edge)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: _buildSourcesPanel(isDesktop: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile: stacked vertically
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(Size screenSize) {
    final filtered = _filteredSources;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          controller: _mainScrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top padding ──
            const SliverPadding(padding: EdgeInsets.only(top: 60)),

            // ── Info region (single box) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _S.lg),
                child: _buildInfoRegion(isDesktop: false),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: _S.lg)),

            // ── Sources header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _S.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stream_rounded,
                              color: _C.accent,
                              size: 20,
                            ),
                            const SizedBox(width: _S.xs),
                            Text(
                              context.l10n.watchSources,
                              style: const TextStyle(
                                color: _C.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isLoadingSources
                              ? 'Searching sources...'
                              : '${filtered.length} source${filtered.length == 1 ? '' : 's'} found',
                          style: const TextStyle(
                            color: _C.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (_sources.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildFilterPillRail(),
                    ],
                    const SizedBox(height: _S.md),
                  ],
                ),
              ),
            ),

            // ── Sources list (virtualized!) ──
            if (_isLoadingSources && filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _S.lg),
                sliver: SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: _S.xs),
                    child: _buildShimmerCard(),
                  ),
                ),
              )
            else if (!_isLoadingSources && filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _S.lg),
                  child: _buildEmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _S.lg),
                sliver: SliverList.builder(
                  itemCount: filtered.length + (_isLoadingSources ? 2 : 0),
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: _S.xs),
                        child: _buildShimmerCard(),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: _S.xs),
                      child: _SourceCard(
                        source: filtered[index],
                        backdropUrl:
                            widget.detail.background ?? widget.detail.poster,
                        logoUrl: widget.detail.logo,
                        detail: widget.detail,
                        episode: widget.selectedEpisode,
                        onNextEpisode: _playNextEpisode,
                        initialPosition: widget.initialPosition,
                      ),
                    );
                  },
                ),
              ),

            // ── Bottom padding ──
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Info Region
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInfoRegion({required bool isDesktop}) {
    final meta = widget.detail;
    final ep = widget.selectedEpisode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episode info header (if applicable)
        if (ep != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              _isCollection
                  ? 'PART ${ep.episode ?? 1}'
                  : 'S${ep.season ?? '?' }E${ep.episode ?? '?' }',
              style: TextStyle(
                color: _C.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: _S.sm),
        ],

        // Logo or title
        _buildLogoOrTitle(meta, isDesktop),
        const SizedBox(height: _S.sm),

        // Episode title (if applicable, different from series title)
        if (ep != null && ep.title.isNotEmpty && ep.title != meta.name)
          Padding(
            padding: const EdgeInsets.only(bottom: _S.sm),
            child: Text(
              ep.title,
              style: TextStyle(
                fontSize: isDesktop ? 20 : 17,
                fontWeight: FontWeight.w600,
                color: _C.textPrimary.withValues(alpha: 0.85),
              ),
            ),
          ),

        // Meta row
        _buildMetaRow(meta),
        const SizedBox(height: _S.md),

        // Genre pills
        if (meta.genres.isNotEmpty) ...[
          _buildGenrePills(meta.genres),
          const SizedBox(height: _S.lg),
        ],

        // Synopsis
        if (_getSynopsis() != null) ...[
          _buildSynopsis(_getSynopsis()!),
          const SizedBox(height: _S.lg),
        ],

        // Director
        if (meta.director.isNotEmpty) ...[
          _buildLabelChips('DIRECTOR', meta.director),
          const SizedBox(height: _S.md),
        ],

        // Cast
        if (meta.cast.isNotEmpty) ...[
          _buildLabelChips('CAST', meta.cast.take(8).toList()),
          const SizedBox(height: _S.lg),
        ],

        // Action bar
        _buildActionBar(),
        const SizedBox(height: _S.lg),
      ],
    );
  }

  String? _getSynopsis() {
    final ep = widget.selectedEpisode;
    if (ep != null && ep.overview != null && ep.overview!.isNotEmpty) {
      return ep.overview;
    }
    return widget.detail.description;
  }

  Widget _buildLogoOrTitle(MovieDetail meta, bool isDesktop) {
    if (meta.logo != null && meta.logo!.isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 380 : 260,
          maxHeight: isDesktop ? 120 : 80,
        ),
        child: CachedNetworkImage(
          imageUrl: meta.logo!,
          alignment: Alignment.bottomLeft,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _buildTextTitle(meta.name, isDesktop),
        ),
      );
    }
    return _buildTextTitle(meta.name, isDesktop);
  }

  Widget _buildTextTitle(String text, bool isDesktop) {
    return Text(
      text,
      style: TextStyle(
        fontSize: isDesktop ? 36 : 28,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.5,
        color: _C.textPrimary,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(MovieDetail meta) {
    final items = <Widget>[];

    if (meta.year != null && meta.year!.isNotEmpty) {
      items.add(
        Text(
          meta.year!,
          style: const TextStyle(
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (meta.runtime != null && meta.runtime!.isNotEmpty) {
      items.add(
        Text(
          meta.runtime!,
          style: const TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
      );
    }

    if (meta.imdbRating != null && meta.imdbRating!.isNotEmpty) {
      items.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _C.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _C.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: _C.gold, size: 14),
              const SizedBox(width: 3),
              Text(
                meta.imdbRating!,
                style: const TextStyle(
                  color: _C.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spaced = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      spaced.add(items[i]);
      if (i < items.length - 1) {
        spaced.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _S.xs),
            child: Text(
              '·',
              style: TextStyle(color: _C.textTertiary, fontSize: 16),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: spaced,
    );
  }

  Widget _buildGenrePills(List<String> genres) {
    return Wrap(
      spacing: _S.xs,
      runSpacing: _S.xs,
      children: genres
          .map(
            (g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                g,
                style: const TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  bool _synopsisExpanded = false;

  Widget _buildSynopsis(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          secondChild: Text(
            text,
            style: const TextStyle(
              color: _C.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          crossFadeState: _synopsisExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              maxLines: 3,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            if (!painter.didExceedMaxLines) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () =>
                  setState(() => _synopsisExpanded = !_synopsisExpanded),
              child: Text(
                _synopsisExpanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: _C.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLabelChips(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _C.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: _S.xs),
        Wrap(
          spacing: _S.xs,
          runSpacing: _S.xs,
          children: items
              .map(
                (name) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.surfaceLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: _C.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    final links = widget.detail.links.take(4).toList();

    // Fallback if no links provided by addon
    if (links.isEmpty && widget.detail.id.startsWith('tt')) {
      links.add(
        Link(
          name: 'IMDb',
          category: 'imdb',
          url: 'https://www.imdb.com/title/${widget.detail.id}/',
        ),
      );
    }

    if (links.isEmpty) {
      // Generic fallback
      final query = Uri.encodeComponent(
        '${widget.detail.name} ${widget.detail.year ?? ''}',
      );
      links.add(
        Link(
          name: 'Search',
          category: 'web',
          url: 'https://google.com/search?q=$query',
        ),
      );
    }

    return Row(
      children: links.map((link) {
        IconData icon = Icons.link_rounded;
        final nameLower = link.name.toLowerCase();
        final catLower = link.category.toLowerCase();

        if (nameLower.contains('imdb') || catLower.contains('imdb')) {
          icon = Icons.movie_creation_outlined;
        } else if (nameLower.contains('trailer') || catLower.contains('trailer')) {
          icon = Icons.play_circle_outline;
        } else if (nameLower.contains('wiki') || catLower.contains('wiki')) {
          icon = Icons.article_outlined;
        } else if (nameLower.contains('search') || catLower.contains('search')) {
          icon = Icons.search_rounded;
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: link == links.last ? 0 : _S.sm),
            child: _buildActionButton(
              icon,
              link.name,
              onTap: () async {
                HapticFeedback.lightImpact();
                final uri = Uri.parse(link.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _C.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _C.textSecondary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sources Panel
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSourcesPanel({required bool isDesktop}) {
    final filtered = _filteredSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header. The pills used to share this row, which squeezed the title
        // on a narrow panel and put a wrapping cluster right against it; they
        // get their own line now, the same one the phone layout gives them.
        Row(
          children: [
            Icon(Icons.stream_rounded, color: _C.accent, size: 20),
            const SizedBox(width: _S.xs),
            Text(
              context.l10n.watchSources,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (_sources.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildFilterPillRail(),
        ],
        const SizedBox(height: _S.sm),

        // Source count
        Text(
          _isLoadingSources
              ? 'Searching sources...'
              : '${filtered.length} source${filtered.length == 1 ? '' : 's'} found',
          style: const TextStyle(color: _C.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: _S.md),

        // Source list
        if (isDesktop)
          Expanded(child: _buildSourcesList(filtered, isDesktop))
        else
          _buildSourcesList(filtered, isDesktop),
      ],
    );
  }

  Widget _buildSourcesList(List<StreamSource> sources, bool isDesktop) {
    if (_isLoadingSources && sources.isEmpty) {
      return _buildShimmerList();
    }

    if (!_isLoadingSources && sources.isEmpty) {
      // A filter that hid every source is a different situation from a title
      // with no sources at all: one is the user's own setting to change, the
      // other is a fact about the title. Telling them apart is the whole
      // point, because an empty list with no explanation reads as a bug.
      if (_hasActiveSourceFilter && _sources.isNotEmpty) {
        return _buildFilteredEmptyState();
      }
      return _buildEmptyState();
    }

    final list = ListView.separated(
      controller: isDesktop ? _sourcesScrollController : null,
      shrinkWrap: !isDesktop,
      physics: isDesktop
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: sources.length + (_isLoadingSources ? 2 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: _S.xs),
      itemBuilder: (context, index) {
        if (index >= sources.length) {
          return _buildShimmerCard();
        }
        return _SourceCard(
          source: sources[index],
          backdropUrl: widget.detail.background ?? widget.detail.poster,
          logoUrl: widget.detail.logo,
          detail: widget.detail,
          episode: widget.selectedEpisode,
          onNextEpisode: _playNextEpisode,
          initialPosition: widget.initialPosition,
        );
      },
    );

    return list;
  }

  /// The pill that opens one filter's glass menu, shared by every filter
  /// (size, source, quality, audio) so the four read as one control in a row
  /// rather than four lookalikes.
  Widget _buildFilterDropdownButton({
    required void Function(BuildContext buttonContext) onTap,
    required String currentText,
    IconData? icon,
  }) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () => onTap(buttonContext),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: PerformanceLiquidLens(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      currentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// One selectable row inside a filter's glass menu. [selected] highlights
  /// it; [onTap] is expected to already pop the menu.
  Widget _buildFilterMenuItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  /// The glass menu a filter button opens, anchored under [buttonContext] and
  /// scrolling if the row of [items] is taller than the room below it.
  ///
  /// Every filter shares this: the anchor math, the open-above fallback and
  /// the material all used to be copied per filter, and a fourth copy for the
  /// quality filter was the point at which copying stopped being cheaper than
  /// sharing.
  void _showFilterMenu({
    required BuildContext buttonContext,
    required List<Widget> items,
  }) {
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset buttonOffset = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    const double dialogWidth = 230.0;
    final double spaceBelow =
        overlay.size.height - (buttonOffset.dy + button.size.height + 8) - 16;
    final double spaceAbove = buttonOffset.dy - 16;
    final bool openAbove = spaceBelow < 280 && spaceAbove > spaceBelow;

    final double maxMenuHeight =
        (openAbove ? spaceAbove : spaceBelow).clamp(160.0, 420.0);
    final double? topOffset =
        openAbove ? null : (buttonOffset.dy + button.size.height + 8);
    final double? bottomOffset =
        openAbove ? (overlay.size.height - buttonOffset.dy + 8) : null;

    final double rawLeft = buttonOffset.dx;
    final double maxLeft = overlay.size.width - dialogWidth - 12.0;
    final double leftOffset =
        rawLeft.clamp(12.0, maxLeft > 12.0 ? maxLeft : 12.0);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: topOffset,
              bottom: bottomOffset,
              left: leftOffset,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, (openAbove ? 10 : -10) * (1 - value)),
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: PerformanceLiquidLens(
                      child: Container(
                        width: dialogWidth,
                        constraints: BoxConstraints(maxHeight: maxMenuHeight),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x26FFFFFF)),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: items,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A thin divider between groups inside a filter menu.
  Widget _buildFilterMenuDivider() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSizeFilterDropdown() {
    return _buildFilterDropdownButton(
      onTap: (buttonContext) => _showSizeGlassDropdown(buttonContext),
      currentText: _getSizeFilterLabel(_selectedSizeFilter),
      icon: Icons.data_usage_rounded,
    );
  }

  /// The four filter pills, in the one scrollable frame both layouts use.
  ///
  /// The add-on pill is dropped rather than added as an empty box when
  /// there is only one add-on: its dropdown would offer a single choice that
  /// is already the only thing shown.
  Widget _buildFilterPillRail() {
    final hasAddonChoice =
        _sources.map((e) => e.addonName).toSet().length > 1;
    return FilterPillRail(
      children: [
        _buildSizeFilterDropdown(),
        if (hasAddonChoice) _buildAddonFilterDropdown(),
        _buildQualityFilterDropdown(),
        _buildAudioFilterDropdown(),
      ],
    );
  }

  void _showSizeGlassDropdown(BuildContext buttonContext) {
    _showFilterMenu(
      buttonContext: buttonContext,
      items: [
        _buildSizeDropdownItem('All Sizes', null),
        _buildFilterMenuDivider(),
        _buildSizeDropdownItem('< 1 GB', '<1gb'),
        _buildSizeDropdownItem('1 GB – 5 GB', '1-5gb'),
        _buildSizeDropdownItem('5 GB – 15 GB', '5-15gb'),
        _buildSizeDropdownItem('15 GB – 30 GB', '15-30gb'),
        _buildSizeDropdownItem('> 30 GB', '>30gb'),
        _buildFilterMenuDivider(),
        _buildSizeDropdownItem('Largest First', 'largest'),
        _buildSizeDropdownItem('Smallest First', 'smallest'),
      ],
    );
  }

  Widget _buildSizeDropdownItem(String title, String? value) {
    return _buildFilterMenuItem(
      title: title,
      selected: _selectedSizeFilter == value,
      onTap: () {
        setState(() {
          _selectedSizeFilter = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildAddonFilterDropdown() {
    final addons = _sources.map((e) => e.addonName).toSet().toList();
    if (addons.isEmpty) return const SizedBox.shrink();

    return _buildFilterDropdownButton(
      onTap: (buttonContext) => _showAddonGlassDropdown(buttonContext, addons),
      currentText: _selectedAddonFilter ?? 'All Sources',
    );
  }

  void _showAddonGlassDropdown(BuildContext buttonContext, List<String> addons) {
    _showFilterMenu(
      buttonContext: buttonContext,
      items: [
        _buildAddonDropdownItem('All Sources', null),
        _buildFilterMenuDivider(),
        ...addons.map((a) => _buildAddonDropdownItem(a, a)),
      ],
    );
  }

  Widget _buildAddonDropdownItem(String title, String? value) {
    return _buildFilterMenuItem(
      title: title,
      selected: _selectedAddonFilter == value,
      onTap: () {
        setState(() {
          _selectedAddonFilter = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildQualityFilterDropdown() {
    return _buildFilterDropdownButton(
      onTap: (buttonContext) => _showQualityGlassDropdown(buttonContext),
      currentText: _multiFilterLabel(
        context.l10n,
        _selectedQualityFilters,
        qualityFilterLabel,
      ),
      icon: Icons.high_quality_rounded,
    );
  }

  void _showQualityGlassDropdown(BuildContext buttonContext) {
    _showFilterMenu(
      buttonContext: buttonContext,
      items: kQualityFilterKeys
          .map(
            (key) => _buildFilterMenuItem(
              title: qualityFilterLabel(context.l10n, key),
              selected: _selectedQualityFilters.contains(key),
              // The menu stays open: a multi-select that closed on every tap
              // would make picking two qualities a two-open job, and the
              // checkmarks are the only feedback that the first one landed.
              onTap: () => SourceFilterSettings.toggleQuality(key),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAudioFilterDropdown() {
    return _buildFilterDropdownButton(
      onTap: (buttonContext) => _showAudioGlassDropdown(buttonContext),
      currentText: _multiFilterLabel(
        context.l10n,
        _selectedAudioFilters,
        audioFilterLabel,
      ),
      icon: Icons.language_rounded,
    );
  }

  void _showAudioGlassDropdown(BuildContext buttonContext) {
    _showFilterMenu(
      buttonContext: buttonContext,
      items: kAudioFilterKeys.map(_buildAudioDropdownItem).toList(),
    );
  }

  Widget _buildAudioDropdownItem(String value) {
    return _buildFilterMenuItem(
      title: audioFilterLabel(context.l10n, value),
      selected: _selectedAudioFilters.contains(value),
      onTap: () => SourceFilterSettings.toggleAudioLanguage(value),
    );
  }

  /// The label for a multi-select filter button.
  ///
  /// One selection is named outright, because that is the common case and
  /// the name is more useful than a count. More than one becomes a count:
  /// the button is a fixed-width pill in a scrolling row, and three language
  /// names would push the other pills off the edge. None is "Any", which is
  /// the same word the settings page uses for an empty selection.
  String _multiFilterLabel(
    AppLocalizations l10n,
    List<String> selected,
    String Function(AppLocalizations, String) label,
  ) {
    if (selected.isEmpty) return l10n.sourceFilterNoneSelected;
    if (selected.length == 1) return label(l10n, selected.first);
    return l10n.sourceFilterSelectedCount(selected.length);
  }

  Widget _buildEmptyState() {
    return const _EmptySourcesStateWidget();
  }

  /// Whether a filter the user can change is narrowing the list right now.
  /// The add-on filter is excluded: it is a per-title choice made from the
  /// sources actually present, so it cannot itself be the thing that made
  /// the list empty.
  bool get _hasActiveSourceFilter =>
      _selectedAudioFilters.isNotEmpty || _selectedQualityFilters.isNotEmpty;

  /// The empty list you get when a filter, not the title, emptied it. Says
  /// which and offers the way out in one tap, rather than the generic "no
  /// sources found" that would send you looking for add-ons that are fine.
  Widget _buildFilteredEmptyState() {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            color: _C.accent,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.sourceFilterFilteredEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              l10n.sourceFilterFilteredEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(l10n.sourceFilterFilteredEmptyClear),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.textPrimary,
              side: BorderSide(color: _C.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => SourceFilterSettings.clearFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: _S.xs),
          child: _buildShimmerCard(),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return const _ShimmerCard();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Back Button
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBackButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: _C.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source Card
// ─────────────────────────────────────────────────────────────────────────────
class _SourceCard extends StatefulWidget {
  final StreamSource source;
  final String? backdropUrl;
  final String? logoUrl;
  final MovieDetail detail;
  final Video? episode;
  final VoidCallback? onNextEpisode;
  final Duration? initialPosition;

  const _SourceCard({
    required this.source,
    this.backdropUrl,
    this.logoUrl,
    required this.detail,
    this.episode,
    this.onNextEpisode,
    this.initialPosition,
  });

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final badges = <Widget>[];

    // Quality badge
    if (s.quality != null) {
      Color badgeColor;
      switch (s.quality) {
        case '4K':
          badgeColor = const Color(0xFFFF6B6B);
          break;
        case '1080p':
          badgeColor = const Color(0xFF51CF66);
          break;
        case '720p':
          badgeColor = const Color(0xFF339AF0);
          break;
        default:
          badgeColor = _C.textTertiary;
      }
      badges.add(_badge(s.quality!, badgeColor));
    }

    // How it's delivered, and for a torrent its seed count -- the health
    // signal that decides between two otherwise identical 1080p sources.
    badges.addAll(sourceDeliveryBadges(s));

    if (s.isHDR) badges.add(_badge('HDR', const Color(0xFFFFD43B)));
    if (s.codec != null) badges.add(_badge(s.codec!, _C.textTertiary));
    if (s.fileSize != null) badges.add(_badge(s.fileSize!, _C.textTertiary));

    // Audio Language / Dub badge
    final audioBadge = s.getAudioBadge(mediaTitle: widget.detail.name);
    if (audioBadge != null) {
      Color audioBadgeColor;
      if (audioBadge.contains('MULTI')) {
        audioBadgeColor = const Color(0xFFB197FC);
      } else if (audioBadge.contains('HINDI') ||
          audioBadge.contains('TELUGU') ||
          audioBadge.contains('TAMIL') ||
          audioBadge.contains('MALAYALAM') ||
          audioBadge.contains('KANNADA') ||
          audioBadge.contains('PUNJABI')) {
        audioBadgeColor = const Color(0xFFFF922B);
      } else if (audioBadge.contains('GER')) {
        audioBadgeColor = const Color(0xFFFFD43B);
      } else if (audioBadge.contains('FRE')) {
        audioBadgeColor = const Color(0xFF4DABF7);
      } else if (audioBadge.contains('SPA')) {
        audioBadgeColor = const Color(0xFFFAB005);
      } else if (audioBadge.contains('RUS')) {
        audioBadgeColor = const Color(0xFF22B8CF);
      } else if (audioBadge.contains('JPN')) {
        audioBadgeColor = const Color(0xFFFF8787);
      } else if (audioBadge.contains('ITA')) {
        audioBadgeColor = const Color(0xFF69DB7C);
      } else {
        audioBadgeColor = _C.textTertiary;
      }
      badges.add(_badge(audioBadge, audioBadgeColor));
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.lightImpact();

              if (s.externalUrl != null && s.externalUrl!.isNotEmpty) {
                if (s.externalUrl!.startsWith('stremio://')) {
                  // Example: stremio:///detail/movie/tt28479262
                  final uriStr = s.externalUrl!.replaceFirst(
                    'stremio:///',
                    'stremio://',
                  );
                  final uri = Uri.parse(uriStr);
                  final segments = uri.pathSegments;
                  if (uri.host == 'detail' && segments.length >= 2) {
                    final type = segments[0];
                    final id = segments[1];
                    final movie = Movie(
                      id: id,
                      type: type,
                      name: s.name ?? 'Unknown',
                      addonBaseUrl: 'https://v3-cinemeta.strem.io',
                    );
                    pushPage(context, DetailsPage(movie: movie));
                    return;
                  }
                  return;
                } else {
                  // Fallback for http URLs or other schemes
                  launchUrl(
                    Uri.parse(s.externalUrl!),
                    mode: LaunchMode.externalApplication,
                  );
                  return;
                }
              }

              final isColl = widget.detail.isCollection;
              final effectiveTitle = (isColl && widget.episode != null && widget.episode!.title.isNotEmpty)
                  ? widget.episode!.title
                  : s.displayTitle;

              pushFullscreenPage(
                PlayerScreen(
                  source: s,
                  title: effectiveTitle,
                  backdropUrl: widget.backdropUrl,
                  logoUrl: widget.logoUrl,
                  detail: widget.detail,
                  episode: widget.episode,
                  onNextEpisode: widget.onNextEpisode,
                  initialPosition: widget.initialPosition,
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _hovered
                    ? _C.surfaceLight.withValues(alpha: 0.9)
                    : _C.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hovered
                      ? _C.accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: _C.accent.withValues(alpha: 0.08),
                          blurRadius: 16,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Addon icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _C.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.extension_rounded,
                      color: _C.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: _S.sm),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name != null && s.name!.isNotEmpty
                              ? s.name!
                              : s.addonName,
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s.title != null && s.title!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            s.title!,
                            style: const TextStyle(
                              color: _C.textTertiary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (s.description != null &&
                            s.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            s.description!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 4, runSpacing: 4, children: badges),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: _S.xs),
                  // Copy the magnet link, for a torrent source.
                  if (s.isMagnet && s.magnetUrl != null) ...[
                    _CopyMagnetButton(magnetUrl: s.magnetUrl!),
                    const SizedBox(width: 8),
                  ],
                  // Download this source directly, without opening the player.
                  ClipOval(
                    child: Material(
                      color: _hovered
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.06),
                      child: InkWell(
                        onTap: () => startSourceDownload(
                          context,
                          detail: widget.detail,
                          episode: widget.episode,
                          source: s,
                        ),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.download_rounded,
                            color: _C.textTertiary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _S.xs),
                  // Play chevron
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? _C.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: _hovered ? _C.accent : _C.textTertiary,
                      size: 20,
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

  Widget _badge(String text, Color color) => SourceBadge(text, color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Copy Magnet Button
// ─────────────────────────────────────────────────────────────────────────────
class _CopyMagnetButton extends StatefulWidget {
  final String magnetUrl;

  const _CopyMagnetButton({required this.magnetUrl});

  @override
  State<_CopyMagnetButton> createState() => _CopyMagnetButtonState();
}

class _CopyMagnetButtonState extends State<_CopyMagnetButton> {
  bool _copied = false;
  bool _hovered = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.magnetUrl));
    HapticFeedback.lightImpact();

    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Text(
              'Magnet link copied to clipboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1D26),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: _copied ? 'Copied!' : 'Copy Magnet Link',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _copy,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _copied
                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                    : (_hovered
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _copied
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : (_hovered
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08)),
                  width: 1,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.link_rounded,
                  key: ValueKey(_copied),
                  color: _copied
                      ? const Color(0xFF10B981)
                      : (_hovered ? const Color(0xFF00E5FF) : _C.textSecondary),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Card
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              _shimmerBox(40, 40, 10),
              const SizedBox(width: _S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(double.infinity, 12, 4),
                    const SizedBox(height: 8),
                    _shimmerBox(180, 10, 4),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _shimmerBox(40, 16, 4),
                        const SizedBox(width: 4),
                        _shimmerBox(50, 16, 4),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _S.xs),
              _shimmerBox(36, 36, 18),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height, double radius) {
    final shimmerValue = _controller.value;
    final gradientStart = shimmerValue - 0.3;
    final gradientEnd = shimmerValue + 0.3;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _C.surfaceLight.withValues(alpha: 0.5),
            _C.surfaceLight.withValues(alpha: 0.8),
            _C.surfaceLight.withValues(alpha: 0.5),
          ],
          stops: [
            (gradientStart).clamp(0.0, 1.0),
            (shimmerValue).clamp(0.0, 1.0),
            (gradientEnd).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

class _EmptySourcesStateWidget extends StatefulWidget {
  const _EmptySourcesStateWidget();

  @override
  State<_EmptySourcesStateWidget> createState() =>
      _EmptySourcesStateWidgetState();
}

class _EmptySourcesStateWidgetState extends State<_EmptySourcesStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    // Run the entrance once. A perpetual pulse kept this whole state ticking.
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Static card content — identical on every platform.
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xF0141419),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.1),
              border: Border.all(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: Color(0xFF7C5CFC),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No sources found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: const Text(
              'No streams found. Install more addons from Settings or try another title.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9B9BA5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                pushPage(context, const SettingsPage());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFC), Color(0xFF5CFCB6)],
                  ),
                  boxShadow: _isHovering
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF7C5CFC,
                            ).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: AnimatedScale(
                  scale: _isHovering ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.extension_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Install Addons',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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

    // The glass card — blur is static, not animated
    final glassCard = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: cardContent,
    );

    // Only the initial fade/scale is animated (runs once, then stops)
    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: _scaleAnim.value, child: child),
        );
      },
      child: glassCard,
    );
  }
}

/// The row of filter pills under the sources heading, scrollable sideways
/// and framed so that a pill hidden past either edge is visible as content
/// rather than simply gone.
///
/// The row is genuinely wider than a phone, and on a narrow panel wider than
/// the surface it sits on, so it has to scroll. A bare horizontal scroll area
/// hides that: with no scrollbar and no cut-off hint, a pill off the right
/// edge looks identical to one that does not exist, and there is nothing to
/// tell the user to try dragging. So the row is drawn inside a bordered
/// rectangle -- the "there is a region here" cue -- and each edge fades in a
/// chevron exactly while there is more content in that direction, which is
/// the whole trick: the fade *is* the overflow indicator, and it disappears
/// at the ends so the last pill is never ambiguous with a hard cut.
///
/// Public rather than private so a widget test can pump it directly: the
/// platform split (button on desktop, fade alone on touch) is a decision
/// worth locking down, and it cannot be reached through [WatchScreen]
/// without a network-backed source list.
class FilterPillRail extends StatefulWidget {
  final List<Widget> children;

  const FilterPillRail({super.key, required this.children});

  @override
  State<FilterPillRail> createState() => _FilterPillRailState();
}

class _FilterPillRailState extends State<FilterPillRail> {
  final ScrollController _controller = ScrollController();

  /// Whether content continues past the left / right edge. Read on every
  /// scroll frame, but stored as plain bools rather than a notifier: the
  /// rebuild is this one row, and the value only changes at the very ends.
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  /// The fade + chevron width. Wide enough to hold the chevron clear of the
  /// edge pill, narrow enough not to swallow a whole pill behind it.
  static const double _edgeFadeWidth = 40;

  /// The fade alone, on touch platforms. Narrower than [_edgeFadeWidth]
  /// because there is no button to hold clear of the pills -- it only has to
  /// be wide enough to read as a fade rather than a hard cut.
  static const double _edgeFadeWidthMobile = 24;

  /// The chevron's own circle. The first version of this rail drew a bare
  /// 18px `textSecondary` glyph on a 28px fade, and it was reported as "not
  /// very visible, and only on the right" -- a glyph with no edge reads as
  /// decoration, not as something to press. The circle is what makes it a
  /// button: it has a border, it holds the glyph off the pills behind it,
  /// and it is the same size at both ends so the row never looks lopsided.
  static const double _edgeButtonSize = 32;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncOverflow);
    // First frame: the scroll extent only exists once layout has run, so
    // this cannot be read in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
  }

  @override
  void didUpdateWidget(covariant FilterPillRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pill set changes when the sources or their add-ons do, which can
    // push the row in or out of overflow at either end without a scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncOverflow);
    _controller.dispose();
    super.dispose();
  }

  /// Recomputes both edge flags. A row that does not scroll reports no
  /// overflow at either end, so a short row shows no chevrons at all.
  void _syncOverflow() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final back = position.pixels > 0;
    final forward = position.pixels < position.maxScrollExtent - 0.5;
    if (back == _canScrollBack && forward == _canScrollForward) return;
    setState(() {
      _canScrollBack = back;
      _canScrollForward = forward;
    });
  }

  void _nudge(bool forward) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + (forward ? 160.0 : -160.0))
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// A plain vertical wheel over the rail scrolls it sideways.
  ///
  /// A horizontal [Scrollable] reads only `scrollDelta.dx`, so a vertical
  /// wheel over this row was silently swallowed: the user hovered the pills,
  /// scrolled, and nothing moved. Shift+wheel and a trackpad's two-finger
  /// swipe already worked, but neither is discoverable, and the plain wheel
  /// is what a desktop user reaches for first.
  ///
  /// The event is claimed through the pointer-signal resolver rather than
  /// acted on directly. A signal reaches every listener on the hit-test
  /// chain, so acting directly would scroll the rail *and* the page behind
  /// it; the resolver picks exactly one. Registering here wins over the page
  /// because this listener is hit first, and it is skipped when the rail is
  /// already at the end in that direction, so the page takes over instead of
  /// the wheel appearing to stick.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // A horizontal delta means a trackpad swipe or a tilt wheel, which the
    // rail's own Scrollable already handles correctly.
    if (event.scrollDelta.dx.abs() > 0.5) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0 || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    final atStart = position.pixels <= position.minScrollExtent;
    final atEnd = position.pixels >= position.maxScrollExtent;
    if ((dy < 0 && atStart) || (dy > 0 && atEnd)) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      position.pointerScroll(dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The listener wraps the whole rail, not just the scroll view, so the
    // wheel works over the edge buttons too -- they sit on top of the row in
    // the Stack and would otherwise swallow the signal.
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          color: Colors.white.withValues(alpha: 0.02),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              ScrollConfiguration(
                // The desktop scrollbar on a 36px row is taller than the row
                // and clips against the frame; the edge chevrons are this
                // rail's overflow cue instead.
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.children.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        widget.children[i],
                      ],
                    ],
                  ),
                ),
              ),
              // Both ends are drawn whenever the row overflows at all, with
              // the spent end dimmed rather than removed. Showing only the
              // live end made the row look lopsided -- a lone chevron on the
              // right reads as "there is more", but it also reads as the
              // control having moved, and at the far end of the scroll the
              // row appeared to have no control at all.
              //
              // The fade is drawn on every platform; the button inside it is
              // desktop-only, which [_buildEdgeFade] decides. On a phone the
              // row is dragged, and two 40px buttons over a 360px row would
              // cover the first and last pill -- a tap meant for either would
              // land on a button instead. The check is the platform, not the
              // width: a tablet is wide enough to pass any breakpoint and is
              // still a touch device.
              if (_canScrollBack || _canScrollForward) ...[
                _buildEdgeFade(forward: false, enabled: _canScrollBack),
                _buildEdgeFade(forward: true, enabled: _canScrollForward),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// One end's indicator: a gradient into the panel colour, plus a tappable
  /// chevron button on desktop platforms. Tapping nudges the row, so a tap
  /// or a drag both work. [enabled] is false at an end with nothing further
  /// to scroll; the button stays in place, dimmed and inert.
  ///
  /// On a touch platform the gradient is drawn alone. It is the cue that
  /// there is more content past the edge, and it costs no tap target -- the
  /// row is dragged there, and a button over the first and last pill would
  /// swallow taps meant for them.
  Widget _buildEdgeFade({required bool forward, required bool enabled}) {
    final showButton = isDesktopPlatform();
    return Positioned(
      top: 0,
      bottom: 0,
      left: forward ? null : 0,
      right: forward ? 0 : null,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: showButton ? _edgeFadeWidth : _edgeFadeWidthMobile,
            decoration: BoxDecoration(
              // Opaque at the outer edge, transparent toward the pills. The
              // first version had this the other way round, which put the
              // chevron on the transparent end of its own fade -- part of why
              // it read as a smudge rather than a button.
              gradient: LinearGradient(
                begin: forward ? Alignment.centerLeft : Alignment.centerRight,
                end: forward ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  _C.surface.withValues(alpha: 0.0),
                  _C.surface.withValues(alpha: 0.92),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: showButton
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _nudge(forward),
                      child: _buildEdgeButton(forward),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// The circular chevron button itself, shared by both ends.
  Widget _buildEdgeButton(bool forward) {
    return Container(
      width: _edgeButtonSize,
      height: _edgeButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _C.surfaceLight.withValues(alpha: 0.95),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        size: 20,
        color: _C.textPrimary,
      ),
    );
  }
}
