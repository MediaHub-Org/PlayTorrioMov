import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/movie_section.dart';
import '../../services/metadata/metadata_service.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/page_search_button.dart';
import '../../widgets/common/pill_tab_row.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../../widgets/movie/movie_card.dart';
import '../../widgets/movie/upcoming_calendar_row.dart';
import '../details/details_page.dart';
import 'latest_releases.dart';

enum _CatalogSort { yearNewest, yearOldest }

/// A simple catalog page that shows all content of a given type
/// (e.g. "movie" or "series") aggregated from the installed addons.
///
/// Used by the Media hub's "Movies" and "Series" sidebar sections.
class TypeCatalogPage extends StatefulWidget {
  final String type; // 'movie' | 'series'
  final String title;
  final ValueChanged<String> onTypeChanged;

  const TypeCatalogPage({
    super.key,
    required this.type,
    required this.title,
    required this.onTypeChanged,
  });

  @override
  State<TypeCatalogPage> createState() => _TypeCatalogPageState();
}

class _TypeCatalogPageState extends State<TypeCatalogPage> {
  final _manager = AddonManager.instance;

  static const _watchTabs = [
    SubTab(id: 'movie', label: 'Movies', icon: Icons.movie_rounded),
    SubTab(id: 'series', label: 'Series', icon: Icons.live_tv_rounded),
  ];

  /// The addon catalogs as fetched, each becoming one browse row. The flat
  /// [_items] list below is derived from these and is only used by the
  /// filtered grid, which has no rows to speak of.
  List<MovieSection> _sections = [];
  List<Movie> _items = [];
  bool _loading = true;
  String? _error;
  _CatalogSort _sort = _CatalogSort.yearNewest;
  int? _decadeFilter;

  List<String> _availableGenres = [];
  String? _genreFilter;
  List<Movie> _genreItems = [];
  bool _loadingGenre = false;

  /// Per-hero-item enrichment (genre/synopsis) keyed by movie id — the
  /// catalog list itself only carries poster/background/year/imdbRating, not
  /// genres or a synopsis, so the hero fetches those separately once it
  /// knows which ~6 items it's showing. Missing/failed entries just mean
  /// that slide stays at today's minimal title+year overlay.
  Map<String, MovieDetail> _heroDetails = {};

  static int? _decadeOf(Movie m) {
    final year = _yearOf(m);
    return year == null ? null : (year ~/ 10) * 10;
  }

  static int? _yearOf(Movie m) {
    final match = RegExp(r'\d{4}').firstMatch(m.year ?? '');
    return match == null ? null : int.parse(match.group(0)!);
  }

  List<Movie> _sorted(List<Movie> items) {
    final sorted = List.of(items);
    switch (_sort) {
      case _CatalogSort.yearNewest:
        sorted.sort((a, b) => (_yearOf(b) ?? -1).compareTo(_yearOf(a) ?? -1));
      case _CatalogSort.yearOldest:
        sorted.sort(
          (a, b) => (_yearOf(a) ?? 99999).compareTo(_yearOf(b) ?? 99999),
        );
    }
    return sorted;
  }

  List<Movie> get _visibleItems {
    final base = _genreFilter == null ? _items : _genreItems;
    final items = _decadeFilter == null
        ? base
        : base.where((m) => _decadeOf(m) == _decadeFilter).toList();
    return _sorted(items);
  }

  /// A genre or decade choice cannot be answered by rows of curated catalogs,
  /// so picking one switches the page to a single filtered grid.
  bool get _isFiltered => _genreFilter != null || _decadeFilter != null;

  /// The hero shows the head of the first catalog, which is the addon's own
  /// lead catalog -- "Popular", "Top", whatever it chose to put first.
  List<Movie> get _heroItems {
    for (final section in _sections) {
      if (section.movies.isNotEmpty) return section.movies.take(6).toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sections = await _manager.fetchByType(widget.type);
      final seen = <String>{};
      final items = <Movie>[];
      for (final section in sections) {
        for (final movie in section.movies) {
          // Ensure the movie's type matches the section so series are treated
          // as series (some addons omit the type in the JSON).
          final typed = Movie(
            id: movie.id,
            name: movie.name,
            poster: movie.poster,
            background: movie.background,
            year: movie.year,
            type: widget.type,
            addonBaseUrl: movie.addonBaseUrl,
            imdbRating: movie.imdbRating,
          );
          final key = '${typed.type}:${typed.id}';
          if (seen.add(key)) items.add(typed);
        }
      }
      final genres = <String>{};
      for (final addon in _manager.activeAddons) {
        for (final catalog in addon.manifest.catalogs) {
          if (catalog.type != widget.type) continue;
          genres.addAll(catalog.genres);
        }
      }
      final filteredGenres = genres.where((g) {
        final trimmed = g.trim();
        if (trimmed.isEmpty) return false;
        if (RegExp(r'^\d{4}$').hasMatch(trimmed)) return false;
        return true;
      }).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _items = items;
        _availableGenres = filteredGenres;
        _loading = false;
      });
      _fetchHeroDetails(_heroItems);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectGenreFilter(String? genre) async {
    if (genre == null) {
      setState(() {
        _genreFilter = null;
        _genreItems = [];
      });
      return;
    }
    setState(() {
      _genreFilter = genre;
      _loadingGenre = true;
    });
    try {
      final sections = await _manager.fetchByGenre(genre);
      final seen = <String>{};
      final items = <Movie>[];
      for (final section in sections) {
        if (section.contentType != widget.type) continue;
        for (final movie in section.movies) {
          final typed = Movie(
            id: movie.id,
            name: movie.name,
            poster: movie.poster,
            background: movie.background,
            year: movie.year,
            type: widget.type,
            addonBaseUrl: movie.addonBaseUrl,
            imdbRating: movie.imdbRating,
          );
          final key = '${typed.type}:${typed.id}';
          if (seen.add(key)) items.add(typed);
        }
      }
      if (!mounted || _genreFilter != genre) return;
      setState(() {
        _genreItems = items;
        _loadingGenre = false;
      });
    } catch (e) {
      if (!mounted || _genreFilter != genre) return;
      setState(() => _loadingGenre = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorView(error: _error, onRetry: _load);
    }

    // Browsing and filtering answer different questions. With no filter the
    // page is the addon catalogs as rows; once a genre or decade is chosen
    // those rows stop being the right shape and it becomes one grid.
    if (!_isFiltered) {
      return BrowseScaffold<Movie>(
        header: _buildHeader(context),
        overlayHeader: true,
        belowHero: ContinueWatchingSlider(typeFilter: widget.type),
        afterRows: widget.type == 'series' ? const UpcomingCalendarRow() : null,
        isLoading: _loading,
        heroItems: _heroItems,
        rows: [
          for (final section in _sections)
            if (section.movies.isNotEmpty)
              BrowseRow<Movie>(
                title: section.title,
                items: _sorted(section.movies),
              ),
          if (_items.isNotEmpty)
            BrowseRow<Movie>(
              title: 'Latest Releases',
              items: latestReleases(_items),
            ),
        ],
        heroBuilder: _buildHeroSlide,
        itemBuilder: (context, movie) => MovieCard(movie: movie),
        onRefresh: _load,
        emptyState: const Center(
          child: Text(
            'No content found. Install more addons in Settings.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return _buildFilteredGrid(context);
  }

  /// Search plus the genre/decade/sort filters, one row -- no separate title,
  /// since the section pill/bottom-bar tab already says "Movies" or "Series".
  /// Shared by both views so the controls do not move when switching between
  /// rows and the grid.
  Widget _buildHeader(BuildContext context) {
    final decades = _items.map(_decadeOf).whereType<int>().toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          PillTabRow(
            tabs: _watchTabs,
            activeId: widget.type,
            onSelected: widget.onTypeChanged,
          ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_availableGenres.isNotEmpty) ...[
                FilterDropdown<String?>(
                  label: _genreFilter ?? 'All genres',
                  icon: Icons.category_rounded,
                  items: [
                    const PopupMenuItem(value: null, child: Text('All genres')),
                    for (final g in _availableGenres)
                      PopupMenuItem(value: g, child: Text(g)),
                  ],
                  onSelected: _selectGenreFilter,
                ),
                if (_loadingGenre)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF7C5CFF),
                    ),
                  ),
              ],
              if (decades.isNotEmpty)
                FilterDropdown<int?>(
                  label: _decadeFilter == null
                      ? 'All decades'
                      : '${_decadeFilter}s',
                  icon: Icons.calendar_today_rounded,
                  items: [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All decades'),
                    ),
                    for (final d in decades)
                      PopupMenuItem(value: d, child: Text('${d}s')),
                  ],
                  onSelected: (v) => setState(() => _decadeFilter = v),
                ),
              FilterDropdown<_CatalogSort>(
                label: switch (_sort) {
                  _CatalogSort.yearNewest => 'Newest',
                  _CatalogSort.yearOldest => 'Oldest',
                },
                icon: Icons.sort_rounded,
                items: const [
                  PopupMenuItem(
                    value: _CatalogSort.yearNewest,
                    child: Text('Newest'),
                  ),
                  PopupMenuItem(
                    value: _CatalogSort.yearOldest,
                    child: Text('Oldest'),
                  ),
                ],
                onSelected: (v) => setState(() => _sort = v!),
              ),
              const PageSearchButton(),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHeroDetails(List<Movie> heroItems) async {
    final results = await Future.wait(
      heroItems.map((m) async {
        try {
          final detail = await MetadataService.fetchMeta(
            baseUrl: m.addonBaseUrl,
            type: m.type,
            imdbId: m.id,
          );
          return MapEntry(m.id, detail);
        } catch (_) {
          return MapEntry(m.id, null);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _heroDetails = {
        for (final entry in results)
          if (entry.value != null) entry.key: entry.value!,
      };
    });
  }

  Widget _buildHeroSlide(BuildContext context, Movie movie) {
    final detail = _heroDetails[movie.id];
    // Upstream's own Home hero (home_page.dart:1000) uses exactly this --
    // detail?.background ?? movie.poster -- the per-item enriched
    // MetadataService fetch's background, not the raw catalog list's own
    // `movie.background`. The catalog list's field is the one that turned
    // out unreliable (some addons put an unrelated portrait image there
    // instead of a real backdrop); the full per-title meta fetch is the
    // addon's higher-quality response and is what upstream trusts.
    final heroImage = detail?.background ?? movie.poster;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    void openDetails({bool autoPlay = false}) => Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: movie, autoPlay: autoPlay),
        tapPosition: null,
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (heroImage != null && heroImage.isNotEmpty)
          CachedNetworkImage(
            imageUrl: heroImage,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.15),
            filterQuality: FilterQuality.medium,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF12151F)),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF12151F)),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xEE080A0F), Color(0x66080A0F), Color(0x00080A0F)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if ((movie.imdbRating ?? '').isNotEmpty) ...[
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
                              movie.imdbRating!,
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
                    if ((movie.year ?? '').isNotEmpty)
                      Text(
                        movie.year!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    movie.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (detail != null &&
                    (detail.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      detail.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (detail != null && detail.genres.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: detail.genres.take(4).map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                SizedBox(height: isCompact ? 18 : 22),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => openDetails(autoPlay: true),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        widget.type == 'series' ? 'Watch Now' : 'Play Movie',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppThemeService.currentPalette.value.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 16 : 24,
                          vertical: isCompact ? 10 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 10,
                        shadowColor: AppThemeService
                            .currentPalette
                            .value
                            .primaryColor
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => openDetails(),
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: isCompact ? 17 : 19,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                      label: Text(
                        'Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 13 : 14.5,
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 14 : 20,
                          vertical: isCompact ? 10 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
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
      ],
    );
  }

  Widget _buildFilteredGrid(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600
        ? 3
        : width < 900
        ? 4
        : width < 1200
        ? 5
        : width < 1600
        ? 6
        : 7;
    final visible = _visibleItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        if (visible.isEmpty && !_loadingGenre)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                _items.isEmpty
                    ? 'No content found. Install more addons in Settings.'
                    : _genreFilter != null
                    ? 'No titles found for $_genreFilter.'
                    : 'No titles in the ${_decadeFilter}s.',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => MovieCard(movie: visible[index]),
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }
}
