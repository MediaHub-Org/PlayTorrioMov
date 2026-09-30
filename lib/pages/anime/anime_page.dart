import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/titles/title_display.dart';
import '../../l10n/l10n.dart';

import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/app_units.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/anime/anime_card.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/genre_tag_row.dart';
import '../../widgets/common/hero_action_button.dart';
import '../../widgets/common/pill_filter_header_bar.dart';
import '../../widgets/home/continue_watching_slider.dart';
import 'anime_details_page.dart';
import 'anime_stream_sheet.dart';
import '../../services/theme/app_colors.dart';

const _kAnimeGenres = [
  'Action',
  'Adventure',
  'Comedy',
  'Drama',
  'Fantasy',
  'Horror',
  'Mystery',
  'Romance',
  'Sci-Fi',
  'Slice of Life',
  'Sports',
  'Supernatural',
  'Thriller',
];

// The hero title's sizes, which have no AppType step.
const double _kHeroTitleCompact = 30;
const double _kHeroTitleWide = 44;

class AnimePage extends StatefulWidget {
  const AnimePage({super.key});

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends State<AnimePage> {
  final AnilistService _anilistService = AnilistService.instance;
  final AnimeLibraryService _libraryService = AnimeLibraryService.instance;

  bool _loading = true;
  String? _error;

  // General Anime data
  List<AnimeMedia> _trending = [];
  List<AnimeMedia> _popularSeason = [];
  List<AnimeMedia> _topRated = [];
  List<AnimeMedia> _upcoming = [];
  List<AnimeMedia> _actionAnime = [];
  List<AnimeMedia> _romanceAnime = [];
  List<AnimeMedia> _fantasyAnime = [];
  List<AnimeMedia> _sciFiAnime = [];

  String? _genreFilter;
  List<AnimeMedia> _genreResults = [];
  bool _genreLoading = false;
  int? _decadeFilter;

  /// Decades across every loaded section, newest first. AniList dates shows
  /// with a season year; a 0 means the feed did not say, and those pool
  /// under no decade rather than a wrong one.
  List<int> get _decades {
    final decades = <int>{};
    for (final list in [
      _trending,
      _popularSeason,
      _topRated,
      _upcoming,
      _actionAnime,
      _romanceAnime,
      _fantasyAnime,
      _sciFiAnime,
      _genreResults,
    ]) {
      for (final anime in list) {
        if (anime.seasonYear > 0) {
          decades.add(anime.seasonYear ~/ 10 * 10);
        }
      }
    }
    return decades.toList()..sort((a, b) => b.compareTo(a));
  }

  /// The pooled sections as one deduplicated list, for the decade filter.
  /// A genre choice is answered server-side by AniList instead, so the pool
  /// only feeds the decade view.
  List<AnimeMedia> get _pooledSections {
    final pool = <int, AnimeMedia>{};
    for (final list in [
      _trending,
      _popularSeason,
      _topRated,
      _upcoming,
      _actionAnime,
      _romanceAnime,
      _fantasyAnime,
      _sciFiAnime,
    ]) {
      for (final anime in list) {
        pool.putIfAbsent(anime.id, () => anime);
      }
    }
    return pool.values.toList();
  }

  /// What the filtered grid shows: the genre answer narrowed by decade, or
  /// the pooled sections narrowed by decade when no genre is chosen.
  List<AnimeMedia> get _filteredItems {
    final base = _genreFilter != null ? _genreResults : _pooledSections;
    final decade = _decadeFilter;
    if (decade == null) return base;
    return base
        .where((a) => a.seasonYear > 0 && a.seasonYear ~/ 10 * 10 == decade)
        .toList();
  }

  bool get _isFiltered => _genreFilter != null || _decadeFilter != null;

  @override
  void initState() {
    super.initState();
    _libraryService.addListener(_onLibraryChanged);
    _libraryService.init();
    _loadAnimeData();
  }

  @override
  void dispose() {
    _libraryService.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAnimeData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Each section fetches independently: one bad/rate-limited/timed-out
    // AniList call shouldn't blank the whole page when the other 7 succeed.
    Future<List<AnimeMedia>> section(
      String label,
      Future<List<AnimeMedia>> future,
    ) {
      return future.catchError((e) {
        debugPrint('Error loading Anime section "$label": $e');
        return <AnimeMedia>[];
      });
    }

    final results = await Future.wait([
      section('trending', _anilistService.fetchTrendingAnime(perPage: 18)),
      section('season', _anilistService.fetchPopularThisSeason(perPage: 18)),
      section('topRated', _anilistService.fetchTopRated(perPage: 18)),
      section('upcoming', _anilistService.fetchUpcomingNextSeason(perPage: 18)),
      section('action', _anilistService.fetchByGenre('Action', perPage: 18)),
      section('romance', _anilistService.fetchByGenre('Romance', perPage: 18)),
      section('fantasy', _anilistService.fetchByGenre('Fantasy', perPage: 18)),
      section('sciFi', _anilistService.fetchByGenre('Sci-Fi', perPage: 18)),
    ]);

    if (!mounted) return;
    final allEmpty = results.every((r) => r.isEmpty);
    setState(() {
      _trending = results[0];
      _popularSeason = results[1];
      _topRated = results[2];
      _upcoming = results[3];
      _actionAnime = results[4];
      _romanceAnime = results[5];
      _fantasyAnime = results[6];
      _sciFiAnime = results[7];
      _error = allEmpty
          ? 'Failed to load Anime catalog. Check your internet connection.'
          : null;
      _loading = false;
    });
  }

  /// Selecting a genre swaps the curated rows for a single filtered grid
  /// fetched from AniList; picking "All Genres" reverts to curated rows.
  /// Purely additive over the homepage -- doesn't touch _trending/etc.
  Future<void> _selectGenre(String? genre) async {
    setState(() {
      _genreFilter = genre;
      _genreLoading = genre != null;
    });
    if (genre == null) return;
    try {
      final results = await _anilistService.fetchByGenre(genre, perPage: 30);
      if (!mounted || _genreFilter != genre) return;
      setState(() {
        _genreResults = results;
        _genreLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading Anime genre "$genre": $e');
      if (!mounted || _genreFilter != genre) return;
      setState(() {
        _genreResults = [];
        _genreLoading = false;
      });
    }
  }

  void _playEpisode(AnimeMedia anime, int episodeNumber) {
    AnimeStreamSheet.show(
      context,
      anime: anime,
      episodeNumber: episodeNumber,
      autoPlay: false,
    );
  }

  /// The genre/decade pill row. Built once per [build] and either
  /// nested inside the hero carousel (see its call sites) or placed inline
  /// above other content via [_withHeader] -- never a page-level floating
  /// overlay, so it always scrolls away with whatever it sits above.
  ///
  /// The "All" reset options carry `''` (genres) and `-1` (decades) rather
  /// than null: a tap on a null-valued popup item never reaches `onSelected`
  /// -- the framework reads a null route result as a dismissal -- so "All
  /// Genres" reset nothing until the sentinels gave it a value that arrives.
  Widget _buildPillHeader() {
    return PillFilterHeaderBar(
      transparent: true,
      pills: [
        FilterDropdown<String?>(
          label: _genreFilter ?? context.l10n.animeAllGenres,
          icon: Icons.filter_list_rounded,
          items: [
            PopupMenuItem(value: '', child: Text(context.l10n.animeAllGenres)),
            for (final g in _kAnimeGenres)
              PopupMenuItem(value: g, child: Text(g)),
          ],
          onSelected: (v) =>
              _selectGenre(v == null || v.isEmpty ? null : v),
        ),
        if (_decades.isNotEmpty)
          FilterDropdown<int?>(
            label: _decadeFilter == null
                ? context.l10n.catalogAllDecades
                : '${_decadeFilter}s',
            icon: Icons.calendar_today_rounded,
            items: [
              PopupMenuItem(
                value: -1,
                child: Text(context.l10n.catalogAllDecades),
              ),
              for (final d in _decades)
                PopupMenuItem(value: d, child: Text('${d}s')),
            ],
            onSelected: (v) => setState(
              () => _decadeFilter = (v == null || v < 0) ? null : v,
            ),
          ),
      ],
    );
  }

  /// Places [header] in a fixed band above [child], which is what makes it
  /// stay put while the page scrolls: it is outside the scroll viewport
  /// rather than pinned over it, so no content ever slides underneath it.
  /// Used by every branch, hero or not, so the filters do not move as the
  /// page switches between its loading, error, grid and hero states.
  /// [PillFilterHeaderBar] applies its own safe-area inset.
  Widget _withHeader(Widget header, Widget child) {
    return Column(
      children: [
        header,
        SizedBox(height: context.rem(AppRem.sm)),
        Expanded(child: child),
      ],
    );
  }

  /// The filtered grid: the genre answer narrowed by decade, or the pooled
  /// sections narrowed by decade when no genre is chosen. Same split
  /// TypeCatalogPage uses between curated rows and one grid.
  Widget _buildFilteredGrid() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _genreFilter != null
              ? context.l10n.animeNoGenreResults(_genreFilter ?? '')
              : context.l10n.catalogNoTitlesInDecade(_decadeFilter ?? 0),
          style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600
        ? 3
        : width < 900
        ? 4
        : width < 1200
        ? 5
        : 6;
    return FirstFocusScope(
      // The items.isEmpty branch above already returned.
      ready: true,
      child: GridView.builder(
      // No floating header to clear anymore -- _withHeader (see build())
      // already reserves real space for the pill row above this grid.
      padding: EdgeInsets.fromLTRB(context.rem(AppRem.lg), context.rem(AppRem.md), context.rem(AppRem.lg), context.rem(7.5)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: context.rem(1.25),
        crossAxisSpacing: context.rem(AppRem.md),
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => AnimeCard(
        anime: items[index],
        onTap: () => _openDetails(items[index]),
      ),
      ),
    );
  }

  void _openDetails(AnimeMedia anime) {
    pushPage(context, AnimeDetailsPage(anime: anime));
  }

  /// The hero carousel's items -- the same "newest first" slides both modes
  /// showed before this migrated onto [BrowseScaffold], which now owns the
  /// carousel chrome (arrows, dots, auto-rotation) that used to live in
  /// `_AnimeHeroCarousel`.
  List<AnimeMedia> get _heroItems {
    return _trending.take(6).toList();
  }

  /// The curated rows below the hero, in the same order the page always
  /// showed them. [BrowseScaffold] already skips any row whose items are
  /// empty, so these don't need individual guards.
  ///
  /// The classics are carved out of the all-time top rated: old enough to
  /// have shaped what came after (a decade or more), and scored high
  /// enough to still be worth watching. Deriving them locally costs no new
  /// fetch -- the top-rated answer is already in memory.
  List<AnimeMedia> get _classics {
    final cutoff = DateTime.now().year - 10;
    final old = _topRated
        .where((a) => a.seasonYear > 0 && a.seasonYear <= cutoff)
        .toList()
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));
    if (old.length < 3) return const [];
    return old.take(12).toList();
  }

  List<BrowseRow<AnimeMedia>> get _rows {
    return [
      BrowseRow(
        title: '🔥 ${context.l10n.animeTrendingTitle}',
        subtitle: context.l10n.animeTrendingSub,
        items: _trending,
      ),
      BrowseRow(
        title: '🌟 ${context.l10n.animeSeasonTitle(AnilistService.currentSeason())}',
        subtitle: context.l10n.animeSeasonSub,
        items: _popularSeason,
      ),
      BrowseRow(
        title: '⭐ ${context.l10n.animeTopTitle}',
        subtitle: context.l10n.animeTopSub,
        items: _topRated,
      ),
      BrowseRow(
        title: '🏛️ ${context.l10n.animeClassicsTitle}',
        subtitle: context.l10n.animeClassicsSub,
        items: _classics,
      ),
      BrowseRow(
        title: '🚀 ${context.l10n.animeUpcomingTitle}',
        subtitle: context.l10n.animeUpcomingSub,
        items: _upcoming,
      ),
      BrowseRow(
        title: '⚔️ ${context.l10n.animeActionTitle}',
        subtitle: context.l10n.animeActionSub,
        items: _actionAnime,
      ),
      BrowseRow(
        title: '💖 ${context.l10n.animeRomanceTitle}',
        subtitle: context.l10n.animeRomanceSub,
        items: _romanceAnime,
      ),
      BrowseRow(
        title: '🔮 ${context.l10n.animeFantasyTitle}',
        subtitle: context.l10n.animeFantasySub,
        items: _fantasyAnime,
      ),
      BrowseRow(
        title: '🤖 ${context.l10n.animeSciFiTitle}',
        subtitle: context.l10n.animeSciFiSub,
        items: _sciFiAnime,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // Built once and placed above the content by _withHeader in every
    // branch -- the hero carousel used to swallow it into its own Stack,
    // which put the filters in a different place, and scrolled them away,
    // depending on whether the page happened to have a hero yet.
    final pillHeader = _buildPillHeader();

    // A genre or decade choice cannot be answered by rows of curated
    // catalogs, so picking one switches the page to a single filtered grid
    // -- same split TypeCatalogPage (Movies/Series) uses between
    // BrowseScaffold and its own filtered grid.
    final content = _isFiltered
        ? _withHeader(
            pillHeader,
            _genreLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _buildFilteredGrid(),
          )
        : BrowseScaffold<AnimeMedia>(
            contentLabel: context.l10n.navAnime,
            header: pillHeader,
            belowHero: ContinueWatchingSlider(
              typeFilter: 'general_anime',
              title: context.l10n.animeContinueWatching,
            ),
            belowHeroExtent: ContinueWatchingSlider.bandHeight,
            isLoading: _loading,
            error: _error,
            onRetry: _loadAnimeData,
            heroItems: _heroItems,
            rows: _rows,
            heroBuilder: (context, anime) => _AnimeHeroSlide(
              anime: anime,
              screenWidth: MediaQuery.sizeOf(context).width,
              onWatchNow: () => _playEpisode(anime, 1),
              onDetailsTap: () => _openDetails(anime),
            ),
            itemBuilder: (context, anime) =>
                AnimeCard(anime: anime, onTap: () => _openDetails(anime)),
            onRefresh: _loadAnimeData,
            emptyState: Center(
              child: Text(
                context.l10n.animeLoadFailed,
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        color: AppColors.canvas,
        child: Stack(
          children: [
            RepaintBoundary(
              child: Stack(
                children: [
                  // Ambient background glows matching Home
                  Positioned(
                    top: -context.rem(7.5),
                    right: -context.rem(7.5),
                    child: Container(
                      width: context.rem(31.25),
                      height: context.rem(31.25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: context.rem(6.25),
                    left: -context.rem(6.25),
                    child: Container(
                      width: context.rem(28.125),
                      height: context.rem(28.125),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00D2EF).withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimeHeroSlide extends StatelessWidget {
  final AnimeMedia anime;
  final double screenWidth;
  final VoidCallback onWatchNow;
  final VoidCallback onDetailsTap;

  const _AnimeHeroSlide({
    required this.anime,
    required this.screenWidth,
    required this.onWatchNow,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final isCompact = screenWidth < 600;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        CachedNetworkImage(
          imageUrl: anime.backdropUrl,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
          filterQuality: FilterQuality.medium,
          placeholder: (_, __) => ColoredBox(color: AppColors.raised),
          errorWidget: (_, __, ___) =>
              ColoredBox(color: AppColors.raised),
        ),

        // Left horizontal wash for cinematic readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.38, 0.85],
                colors: [
                  AppColors.canvas.withValues(alpha: 0.95),
                  AppColors.canvas.withValues(alpha: 0.70),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top Gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.canvas.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom Gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.30, 0.75],
                colors: [
                  AppColors.canvas,
                  AppColors.canvas.withValues(alpha: 0.80),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content Overlay
        Positioned(
          left: context.rem(isCompact ? 1.25 : 3),
          right: context.rem(isCompact ? 1.25 : 3),
          bottom: context.rem(isCompact ? 2.25 : 3.5),
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : context.rem(42.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rating + Year + Episodes row
                  Row(
                    children: [
                      if (anime.averageScore > 0) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rem(0.6875),
                            vertical: context.rem(AppRem.snug),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(context.rem(0.5625)),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: context.rem(1.0625),
                                color: const Color(0xFFFFD700),
                              ),
                              SizedBox(width: context.rem(AppRem.xs)),
                              Text(
                                anime.formattedScore,
                                style: const TextStyle(
                                  fontSize: AppType.bodyMd,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: context.rem(0.625)),
                      ],
                      if (anime.seasonYear > 0)
                        Text(
                          '${anime.seasonYear}',
                          style: TextStyle(
                            fontSize: AppType.bodyMd,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (anime.totalEpisodes > 0) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm)),
                          child: Icon(
                            Icons.circle,
                            size: context.rem(0.25),
                            color: AppColors.onAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          context.l10n.playerEpisodeCount(anime.totalEpisodes),
                          style: TextStyle(
                            fontSize: AppType.bodyMd,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (anime.studioName.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm)),
                          child: Icon(
                            Icons.circle,
                            size: context.rem(0.25),
                            color: AppColors.onAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          anime.studioName,
                          style: TextStyle(
                            fontSize: AppType.bodyMd,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: context.rem(AppRem.md)),

                  // Title
                  Text(
                    animeDisplayTitle(anime),
                    style: TextStyle(
                      fontSize: isCompact ? _kHeroTitleCompact : _kHeroTitleWide,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05, // ratio: a line height, not a size
                      color: AppColors.onAccent,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (anime.description.isNotEmpty) ...[
                    SizedBox(height: context.rem(isCompact ? AppRem.ms : AppRem.md)),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? double.infinity : context.rem(36.25),
                      ),
                      child: Text(
                        anime.description,
                        maxLines: isCompact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? AppType.bodyPlus : AppType.bodyMdPlus,
                          color: AppColors.onAccent.withValues(alpha: 0.65),
                          height: 1.5, // ratio: a line height, not a size
                        ),
                      ),
                    ),
                  ],

                  // Genre chips
                  if (anime.genres.isNotEmpty) ...[
                    SizedBox(height: context.rem(AppRem.md)),
                    GenreTagRow(genres: anime.genres.take(4).toList()),
                  ],

                  // Action buttons (Matching Home Page)
                  SizedBox(height: context.rem(isCompact ? 1.375 : 1.625)),
                  Row(
                    children: [
                      HeroActionButton(
                        primary: true,
                        compact: isCompact,
                        onTap: onWatchNow,
                        icon: Icons.play_arrow_rounded,
                        label: context.l10n.animeWatchEp1,
                      ),
                      SizedBox(width: context.rem(AppRem.ms)),
                      HeroActionButton(
                        primary: false,
                        compact: isCompact,
                        onTap: onDetailsTap,
                        icon: Icons.info_outline_rounded,
                        label: context.l10n.commonDetails,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
