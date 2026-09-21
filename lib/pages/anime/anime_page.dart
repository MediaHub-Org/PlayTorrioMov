import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../widgets/player/language_flag.dart';

import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/anime_arabic/anime_arabic_service.dart';
import '../../services/app_spacing.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/anime/anime_card.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/genre_tag_row.dart';
import '../../widgets/common/page_search_button.dart';
import '../../widgets/common/pill_filter_header_bar.dart';
import '../../widgets/home/continue_watching_slider.dart';
import 'anime_details_page.dart';
import 'anime_stream_sheet.dart';
import '../search/search_page.dart';
import 'anime_search_page.dart';
import '../anime_arabic/anime_arabic_details_page.dart';
import '../anime_arabic/anime_arabic_stream_sheet.dart';
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

class AnimePage extends StatefulWidget {
  const AnimePage({super.key});

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends State<AnimePage> {
  final AnilistService _anilistService = AnilistService.instance;
  final AnimeLibraryService _libraryService = AnimeLibraryService.instance;
  final AnimeArabicService _arabicService = AnimeArabicService.instance;

  bool _isArabicMode = false;
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

  // Arabic Anime data
  HomeFeed? _arabicFeed;
  final Map<int, ArabicAnimeCard> _arabicCards = {};

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

    if (_isArabicMode) {
      try {
        final feed = await _arabicService.getHome();
        _arabicCards.clear();
        void registerCards(List<ArabicAnimeCard> list) {
          for (final c in list) {
            _arabicCards[c.slug.hashCode.abs()] = c;
          }
        }

        registerCards(feed.spotlight);
        registerCards(feed.recentEpisodes);
        registerCards(feed.trending);
        registerCards(feed.popularMovies);
        registerCards(feed.topSeasonal);
        registerCards(feed.seasonal);
        registerCards(feed.legendary);
        registerCards(feed.upcoming);

        if (mounted) {
          setState(() {
            _arabicFeed = feed;
            _loading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading Arabic Anime data: $e');
        if (mounted) {
          setState(() {
            _error =
                context.l10n.animeArabicLoadFailed;
            _loading = false;
          });
        }
      }
      return;
    }

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
  /// fetched from AniList; picking "All Genres" (null) reverts to curated
  /// rows. Purely additive over the homepage -- doesn't touch _trending/etc.
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

  void _onModeChanged(bool arabic) {
    if (_isArabicMode == arabic) return;
    setState(() {
      _isArabicMode = arabic;
    });
    _loadAnimeData();
  }

  void _playEpisode(AnimeMedia anime, int episodeNumber) {
    if (_isArabicMode || _arabicCards.containsKey(anime.id)) {
      final card =
          _arabicCards[anime.id] ??
          ArabicAnimeCard(
            slug: anime.titleEnglish.toLowerCase().replaceAll(' ', '-'),
            title: anime.displayTitle,
            cover: anime.coverUrl,
          );
      _arabicService.getDetails(card.slug).then((details) {
        if (!mounted) return;
        final ep = details.episodes.firstWhere(
          (e) => e.number == episodeNumber,
          orElse: () => details.episodes.isNotEmpty
              ? details.episodes.first
              : ArabicEpisode(
                  number: episodeNumber,
                  title: 'الحلقة $episodeNumber',
                  encodedHref: '',
                  watchPath: '/e/${card.slug}-$episodeNumber#tok',
                ),
        );
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AnimeArabicStreamSheet(
            details: details,
            episode: ep,
            autoPlay: false,
          ),
        );
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimeStreamSheet(
        anime: anime,
        episodeNumber: episodeNumber,
        autoPlay: false,
      ),
    );
  }

  /// The genre/language/search pill row. Built once per [build] and either
  /// nested inside the hero carousel (see its call sites) or placed inline
  /// above other content via [_withHeader] -- never a page-level floating
  /// overlay, so it always scrolls away with whatever it sits above.
  Widget _buildPillHeader() {
    return PillFilterHeaderBar(
      transparent: true,
      pills: [
        FilterDropdown<String?>(
          label: _genreFilter ?? context.l10n.animeAllGenres,
          icon: Icons.filter_list_rounded,
          items: [
            PopupMenuItem(value: null, child: Text(context.l10n.animeAllGenres)),
            for (final g in _kAnimeGenres)
              PopupMenuItem(value: g, child: Text(g)),
          ],
          onSelected: _selectGenre,
        ),
        FilterDropdown<bool>(
          label: _isArabicMode ? context.l10n.animeLangArabic : context.l10n.animeLangEnglish,
          icon: Icons.language_rounded,
          items: [
            PopupMenuItem(
              value: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LanguageFlag('English', height: 14),
                  const SizedBox(width: 10),
                  Text(context.l10n.animeLangEnglish),
                ],
              ),
            ),
            PopupMenuItem(
              value: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LanguageFlag('Arabic', height: 14),
                  const SizedBox(width: 10),
                  Text(context.l10n.animeLangArabic),
                ],
              ),
            ),
          ],
          onSelected: (arabic) => _onModeChanged(arabic ?? false),
        ),
        PageSearchButton(onTap: _navigateToSearch),
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
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildGenreGrid() {
    if (_genreResults.isEmpty) {
      return Center(
        child: Text(
          'No $_genreFilter anime found.',
          style: TextStyle(color: AppColors.inkSubtle, fontSize: 16),
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
    return GridView.builder(
      // No floating header to clear anymore -- _withHeader (see build())
      // already reserves real space for the pill row above this grid.
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 16, AppSpacing.lg, 120),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: _genreResults.length,
      itemBuilder: (context, index) => AnimeCard(
        anime: _genreResults[index],
        onTap: () => _openDetails(_genreResults[index]),
      ),
    );
  }

  void _openDetails(AnimeMedia anime, [int? preferredEpisode]) {
    if (_isArabicMode || _arabicCards.containsKey(anime.id)) {
      final card =
          _arabicCards[anime.id] ??
          ArabicAnimeCard(
            slug: anime.titleEnglish.toLowerCase().replaceAll(' ', '-'),
            title: anime.displayTitle,
            cover: anime.coverUrl,
          );
      final epNum =
          preferredEpisode ??
          (anime.totalEpisodes > 0 ? anime.totalEpisodes : null);
      pushPage(
        context,
        AnimeArabicDetailsPage(
          anime: card,
          initialEpisodeNumber: epNum,
        ),
      );
      return;
    }

    pushPage(context, AnimeDetailsPage(anime: anime));
  }

  /// AniList anime is searchable from the unified search page -- arriving
  /// from here pre-selects its Anime chip via [SearchScope], so the button
  /// means the same thing it does on Movies and Series. Arabic mode keeps
  /// its own page: the unified search has no source for that catalog.
  void _navigateToSearch() {
    pushPage(
      context,
      _isArabicMode
          ? const AnimeSearchPage(initialArabicMode: true)
          : const SearchPage(),
    );
  }

  /// The hero carousel's items -- the same "newest first" slides both modes
  /// showed before this migrated onto [BrowseScaffold], which now owns the
  /// carousel chrome (arrows, dots, auto-rotation) that used to live in
  /// `_AnimeHeroCarousel`.
  List<AnimeMedia> get _heroItems {
    if (_isArabicMode) {
      final feed = _arabicFeed;
      if (feed == null) return const [];
      final source = feed.spotlight.isNotEmpty ? feed.spotlight : feed.trending;
      return source.take(6).map((c) => c.toAnimeMedia()).toList();
    }
    return _trending.take(6).toList();
  }

  /// The curated rows below the hero, in the same order the page always
  /// showed them. [BrowseScaffold] already skips any row whose items are
  /// empty, so these don't need to be individually guarded the way the
  /// Arabic rows used to be.
  List<BrowseRow<AnimeMedia>> get _rows {
    if (_isArabicMode) {
      final feed = _arabicFeed;
      if (feed == null) return const [];
      AnimeMedia toMedia(ArabicAnimeCard c) => c.toAnimeMedia();
      return [
        BrowseRow(
          title: '⚡ آخر الحلقات المعروضة',
          subtitle: 'أحدث الحلقات المضافة المترجمة للعربية',
          items: feed.recentEpisodes.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '🔥 الأكثر شهرة وتداولاً',
          subtitle: 'الأنميات الأكثر مشاهدة حالياً',
          items: feed.trending.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '🎬 الأفلام الأكثر شعبية',
          subtitle: 'أفلام الأنمي المميزة',
          items: feed.popularMovies.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '👑 أفضل الأنميات',
          subtitle: 'أنميات ذات تقييمات استثنائية',
          items: feed.topSeasonal.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '🌟 أنميات موسمية',
          subtitle: 'عروض الموسم الحالي',
          items: feed.seasonal.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '⚔️ أنميات أسطورية',
          subtitle: 'أعمال خالدة يجب ألا تفوتك',
          items: feed.legendary.map(toMedia).toList(),
        ),
        BrowseRow(
          title: '🚀 المنتظرة قريباً',
          subtitle: 'أنميات قادمة قريباً',
          items: feed.upcoming.map(toMedia).toList(),
        ),
      ];
    }
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

    // A genre choice cannot be answered by rows of curated catalogs, so
    // picking one switches the page to a single filtered grid -- same split
    // TypeCatalogPage (Movies/Series) uses between BrowseScaffold and its own
    // filtered grid.
    final content = _genreFilter != null
        ? _withHeader(
            pillHeader,
            _genreLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _buildGenreGrid(),
          )
        : BrowseScaffold<AnimeMedia>(
            contentLabel: 'anime',
            header: pillHeader,
            belowHero: ContinueWatchingSlider(
              typeFilter: _isArabicMode ? 'arabic_anime' : 'general_anime',
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
                style: TextStyle(color: AppColors.inkSubtle, fontSize: 16),
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
                    top: -120,
                    right: -120,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 100,
                    left: -100,
                    child: Container(
                      width: 450,
                      height: 450,
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
          left: isCompact ? 20 : 48,
          right: isCompact ? 20 : 48,
          bottom: isCompact ? 36 : 56,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : 680.0,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 17,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                anime.formattedScore,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (anime.seasonYear > 0)
                        Text(
                          '${anime.seasonYear}',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (anime.totalEpisodes > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: AppColors.onAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          '${anime.totalEpisodes} Episodes',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (anime.studioName.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: AppColors.onAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          anime.studioName,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.onAccent.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    anime.displayTitle,
                    style: TextStyle(
                      fontSize: isCompact ? 30 : 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: AppColors.onAccent,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (anime.description.isNotEmpty) ...[
                    SizedBox(height: isCompact ? 12 : 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? double.infinity : 580,
                      ),
                      child: Text(
                        anime.description,
                        maxLines: isCompact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 14.5 : 15.5,
                          color: AppColors.onAccent.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Genre chips
                  if (anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GenreTagRow(genres: anime.genres.take(4).toList()),
                  ],

                  // Action buttons (Matching Home Page)
                  SizedBox(height: isCompact ? 22 : 26),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onWatchNow,
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: Text(
                          context.l10n.animeWatchEp1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppThemeService.currentPalette.value.primaryColor,
                          foregroundColor: AppColors.onAccent,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 18 : 28,
                            vertical: isCompact ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 12,
                          shadowColor: AppThemeService
                              .currentPalette
                              .value
                              .primaryColor
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 12),
                      OutlinedButton.icon(
                        onPressed: onDetailsTap,
                        icon: Icon(
                          Icons.info_outline_rounded,
                          size: isCompact ? 18 : 21,
                          color: AppColors.onAccent.withValues(alpha: 0.80),
                        ),
                        label: Text(
                          context.l10n.commonDetails,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 14 : 15.5,
                            color: AppColors.onAccent.withValues(alpha: 0.80),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 24,
                            vertical: isCompact ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: AppColors.onAccent.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                        ),
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
