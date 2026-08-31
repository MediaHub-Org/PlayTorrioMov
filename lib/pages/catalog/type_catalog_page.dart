import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../services/addon/addon_manager.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/page_search_button.dart';
import '../../widgets/movie/movie_card.dart';

enum _CatalogSort { titleAsc, titleDesc, yearNewest, yearOldest }

/// A simple catalog page that shows all content of a given type
/// (e.g. "movie" or "series") aggregated from the installed addons.
///
/// Used by the Media hub's "Movies" and "Series" sidebar sections.
class TypeCatalogPage extends StatefulWidget {
  final String type; // 'movie' | 'series'
  final String title;

  const TypeCatalogPage({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<TypeCatalogPage> createState() => _TypeCatalogPageState();
}

class _TypeCatalogPageState extends State<TypeCatalogPage> {
  final _manager = AddonManager.instance;

  /// The addon catalogs as fetched, each becoming one browse row. The flat
  /// [_items] list below is derived from these and is only used by the
  /// filtered grid, which has no rows to speak of.
  List<MovieSection> _sections = [];
  List<Movie> _items = [];
  bool _loading = true;
  String? _error;
  _CatalogSort _sort = _CatalogSort.titleAsc;
  int? _decadeFilter;

  List<String> _availableGenres = [];
  String? _genreFilter;
  List<Movie> _genreItems = [];
  bool _loadingGenre = false;

  static int? _decadeOf(Movie m) {
    final match = RegExp(r'\d{4}').firstMatch(m.year ?? '');
    if (match == null) return null;
    return (int.parse(match.group(0)!) ~/ 10) * 10;
  }

  List<Movie> get _visibleItems {
    final base = _genreFilter == null ? _items : _genreItems;
    var items = _decadeFilter == null
        ? base
        : base.where((m) => _decadeOf(m) == _decadeFilter).toList();
    items = List.of(items);
    switch (_sort) {
      case _CatalogSort.titleAsc:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _CatalogSort.titleDesc:
        items.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case _CatalogSort.yearNewest:
        items.sort((a, b) => (_decadeOf(b) ?? -1).compareTo(_decadeOf(a) ?? -1));
      case _CatalogSort.yearOldest:
        items.sort((a, b) => (_decadeOf(a) ?? 99999).compareTo(_decadeOf(b) ?? 99999));
    }
    return items;
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
            year: movie.year,
            type: widget.type,
            addonBaseUrl: movie.addonBaseUrl,
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
      }).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _items = items;
        _availableGenres = filteredGenres;
        _loading = false;
      });
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
            year: movie.year,
            type: widget.type,
            addonBaseUrl: movie.addonBaseUrl,
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
        isLoading: _loading,
        heroItems: _heroItems,
        rows: [
          for (final section in _sections)
            if (section.movies.isNotEmpty)
              BrowseRow<Movie>(
                title: section.title,
                items: section.movies,
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

  /// Title, search, and the genre/decade/sort filters. Shared by both views so
  /// the controls do not move when switching between rows and the grid.
  Widget _buildHeader(BuildContext context) {
    final decades = _items.map(_decadeOf).whereType<int>().toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const PageSearchButton(),
            ],
          ),
          if (decades.isNotEmpty || _availableGenres.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                FilterDropdown<int?>(
                  label: _decadeFilter == null ? 'All decades' : '${_decadeFilter}s',
                  icon: Icons.calendar_today_rounded,
                  items: [
                    const PopupMenuItem(value: null, child: Text('All decades')),
                    for (final d in decades)
                      PopupMenuItem(value: d, child: Text('${d}s')),
                  ],
                  onSelected: (v) => setState(() => _decadeFilter = v),
                ),
                FilterDropdown<_CatalogSort>(
                  label: switch (_sort) {
                    _CatalogSort.titleAsc => 'Title A–Z',
                    _CatalogSort.titleDesc => 'Title Z–A',
                    _CatalogSort.yearNewest => 'Newest',
                    _CatalogSort.yearOldest => 'Oldest',
                  },
                  icon: Icons.sort_rounded,
                  items: const [
                    PopupMenuItem(value: _CatalogSort.titleAsc, child: Text('Title A–Z')),
                    PopupMenuItem(value: _CatalogSort.titleDesc, child: Text('Title Z–A')),
                    PopupMenuItem(value: _CatalogSort.yearNewest, child: Text('Newest')),
                    PopupMenuItem(value: _CatalogSort.yearOldest, child: Text('Oldest')),
                  ],
                  onSelected: (v) => setState(() => _sort = v!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroSlide(BuildContext context, Movie movie) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (movie.poster != null && movie.poster!.isNotEmpty)
          Image.network(movie.poster!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF12151F))),
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
                if ((movie.year ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    movie.year!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
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
                : 6;
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
