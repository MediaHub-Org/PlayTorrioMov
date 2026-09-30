import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../services/app_spacing.dart';
import '../../models/movie/movie_section.dart';
import '../../models/stream/stream_model.dart';
import '../../models/anime/anime_media.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/anime/anilist_service.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../utils/search_scope.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../widgets/common/hover_button.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/anime/anime_slider_section.dart';
import '../../widgets/movie/movie_slider_section.dart';
import '../anime/anime_details_page.dart';
import '../anime/anime_search_page.dart';
import '../../widgets/search/magnet_files_view.dart';
import '../player/player_screen.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  Timer? _debounce;
  bool _isLoading = false;
  List<MovieSection> _results = [];
  List<AnimeMedia> _animeResults = [];
  String _lastQuery = '';

  /// Bumped on every search so a slow reply from an earlier one cannot land
  /// on top of a newer result set. Comparing queries is not enough: changing
  /// a chip re-searches the same text with a different filter.
  int _searchSeq = 0;

  /// Which content types to search. Seeded from [SearchScope] so the section
  /// the user came from is pre-selected — but as a chip they can clear, not
  /// as a hidden mode. The same button used to mean different things
  /// depending on where it was pressed, which is the thing this fixes.
  late SearchFilter _typeFilter = SearchFilter.fromScope(
    SearchScope.contentType,
  );

  /// Inline AniList narrowing, so the common case never leaves this page.
  /// Genre answers most anime searches; season, format, status and sort
  /// stay one tap away on the Anime Filters page. (Sort is not offered
  /// here on purpose: the service ranks text matches first whenever a
  /// query is present, so a sort pill beside a search field would promise
  /// an order it cannot give.) Changing the genre re-runs the query in
  /// place -- the _searchSeq guard already covers a chip change racing a
  /// keystroke.
  String? _animeGenre;

  bool _isMagnetMode = false;
  String _magnetQuery = '';

  /// The genres worth a pill here. The app's Anime section lists thirteen;
  /// the search page carries the same thirteen rather than the filter
  /// page's nineteen, because those six extra need the adult gate the full
  /// page owns and this row must not open.
  static const _animeGenres = [
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

  static bool _isMagnetLink(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('magnet:')) return true;
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(trimmed)) return true;
    if (RegExp(r'^[a-zA-Z2-7]{32}$').hasMatch(trimmed)) return true;
    return false;
  }

  static bool _isStreamLink(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    return true;
  }

  void _playDirectStream(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    String title = 'Direct Stream';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty) {
        title = Uri.decodeComponent(last);
      }
    }

    pushFullscreenPage(
      PlayerScreen(
        source: StreamSource(
          name: 'Direct Stream',
          title: title,
          url: trimmed,
          addonName: 'Direct Stream',
        ),
        title: title,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results.clear();
        _animeResults.clear();
        _isLoading = false;
        _lastQuery = '';
        _isMagnetMode = false;
        _magnetQuery = '';
      });
      return;
    }

    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
        _animeResults.clear();
      });
      return;
    } else if (_isMagnetMode) {
      setState(() {
        _isMagnetMode = false;
        _magnetQuery = '';
      });
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (trimmed != _lastQuery) {
        _performSearch(trimmed);
      }
    });
  }

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
        _animeResults.clear();
      });
      return;
    }

    final seq = ++_searchSeq;
    setState(() {
      _isLoading = true;
      _lastQuery = trimmed;
      _isMagnetMode = false;
    });

    // Both catalogs are asked at once. They are separate APIs, so running
    // them in sequence would make every "All" search as slow as the slower
    // of the two; and each swallows its own failure, so AniList being down
    // does not blank out addon results that arrived fine.
    final addonFuture = _typeFilter.searchesAddons
        ? AddonManager.instance
              .searchAll(trimmed, contentType: _typeFilter.addonContentType)
              .catchError((Object _) => <MovieSection>[])
        : Future<List<MovieSection>>.value(const []);
    final animeFuture = _typeFilter.searchesAnime
        ? AnilistService.instance
              .searchAnime(trimmed, genre: _animeGenre)
              .catchError((Object _) => <AnimeMedia>[])
        : Future<List<AnimeMedia>>.value(const []);

    final addonResults = await addonFuture;
    final animeResults = await animeFuture;
    if (!mounted) return;
    // A newer query (or a chip change) started while these were in flight --
    // its own results are the ones to show.
    if (seq != _searchSeq) return;

    setState(() {
      _results = addonResults;
      _animeResults = animeResults;
      _isLoading = false;
    });
  }

  void _onTypeChanged(SearchFilter value) {
    if (value == _typeFilter) return;
    setState(() {
      _typeFilter = value;
      // Results from the old filter would otherwise sit there looking like
      // an answer to the new one until the request came back.
      _results = [];
      _animeResults = [];
    });
    if (_lastQuery.isNotEmpty) _performSearch(_lastQuery);
  }

  /// Anime rows lead when the Anime chip is active and trail otherwise, so
  /// whichever catalog the user asked for is the one at the top.
  List<Widget> _resultSections() {
    final animeSection = _animeResults.isEmpty
        ? null
        : AnimeSliderSection(
            title: context.l10n.navAnime,
            subtitle: context.l10n.searchFromAniList,
            animeList: _animeResults,
            onAnimeTap: (anime) =>
                pushPage(context, AnimeDetailsPage(anime: anime)),
            onSeeAll: _openAnimeFilters,
          );
    return [
      if (_typeFilter == SearchFilter.anime && animeSection != null) animeSection,
      for (final section in _results) MovieSliderSection(section: section),
      if (_typeFilter != SearchFilter.anime && animeSection != null) animeSection,
    ];
  }

  /// The AniList-native filters (genre, season, format, status, sort) live
  /// on their own page and stay there -- reaching them from here carries the
  /// query across so nothing has to be retyped.
  void _openAnimeFilters() {
    pushPage(
      context,
      AnimeSearchPage(initialQuery: _lastQuery.isEmpty ? null : _lastQuery),
    );
  }

  Widget _buildTypeChips() {
    return SizedBox(
      height: AppSpacing.textScaledHeight(context, 44),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageInset(context),
          vertical: context.rem(AppRem.snug),
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          for (final filter in SearchFilter.values) ...[
            _buildChoiceChip(filter),
            SizedBox(width: context.rem(AppRem.snug)),
          ],
          if (_typeFilter == SearchFilter.anime)
            FilterDropdown<String?>(
              label: _animeGenre ?? context.l10n.animeAllGenres,
              icon: Icons.category_rounded,
              items: [
                PopupMenuItem(
                  value: '',
                  child: Text(context.l10n.animeAllGenres),
                ),
                for (final g in _animeGenres)
                  PopupMenuItem(value: g, child: Text(g)),
              ],
              // Null never arrives from a menu tap (it reads as a
              // dismissal), so reset carries the empty sentinel like the
              // other filter dropdowns.
              onSelected: (v) {
                final genre = (v == null || v.isEmpty) ? null : v;
                if (genre == _animeGenre) return;
                setState(() => _animeGenre = genre);
                if (_lastQuery.isNotEmpty) _performSearch(_lastQuery);
              },
            ),
          if (_typeFilter == SearchFilter.anime)
            HoverButton(
              scaleAmount: 1.05,
              showFocusRing: true,
              onTap: _openAnimeFilters,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rem(0.625),
                  vertical: context.rem(AppRem.snug),
                ),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                  border: Border.all(
                    color: AppColors.inkAlpha(0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: context.rem(0.8125),
                      color: AppColors.inkMuted,
                    ),
                    SizedBox(width: context.rem(AppRem.xs)),
                    Text(
                      context.l10n.searchAnimeFilters,
                      style: TextStyle(
                        fontSize: AppType.tinyPlus,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(SearchFilter filter) {
    final isSelected = _typeFilter == filter;
    return HoverButton(
      scaleAmount: 1.05,
      showFocusRing: true,
      onTap: () => _onTypeChanged(filter),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(AppRem.snug)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.raised,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
        ),
        child: Text(
          filter.label(context.l10n),
          style: TextStyle(
            fontSize: AppType.tinyPlus,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.ink : AppColors.inkAlpha(0.60),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: EdgeInsets.only(
                top: AppSpacing.floatingTopInset(context),
                bottom: context.rem(AppRem.sm),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.canvas.withValues(alpha: 0.90),
                    AppColors.canvas.withValues(alpha: 0.60),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.inkAlpha(0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: AppSpacing.pageInset(context)),
                  const GlassBackButton(),
                  SizedBox(width: context.rem(0.625)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.md)),
                      child: Container(
                        height: context.rem(2.625),
                        decoration: BoxDecoration(
                          color: AppColors.inkAlpha(0.06),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                          border: Border.all(
                            color: AppColors.inkAlpha(0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: AppType.bodyLg,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            hintText: context.l10n.searchPromptOrPaste(
                              _typeFilter.scopeLabel(context.l10n),
                            ),
                            hintStyle: TextStyle(
                              color: AppColors.inkAlpha(0.35),
                              fontSize: AppType.body,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: context.rem(AppRem.md),
                              vertical: context.rem(AppRem.ms),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: context.l10n.commonClose,
                                    icon: Icon(Icons.close_rounded, size: context.rem(AppRem.iconSm)),
                                    color: AppColors.inkAlpha(0.60),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : Icon(
                                    Icons.search_rounded,
                                    size: context.rem(AppRem.icon),
                                    color: AppColors.inkSubtle,
                                  ),
                          ),
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
      body: Column(
        children: [
          // The blurred bar overlays the body (extendBodyBehindAppBar), so
          // the band is reserved here rather than as scroll padding -- that
          // keeps the chips fixed under it instead of scrolling away with
          // the results.
          SizedBox(height: topPadding + kToolbarHeight + context.rem(0.625)),
          if (!_isMagnetMode) _buildTypeChips(),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isMagnetMode && _magnetQuery.isNotEmpty) {
      return MagnetFilesView(key: ValueKey(_magnetQuery), magnet: _magnetQuery);
    }
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final sections = _resultSections();
    if (sections.isNotEmpty) {
      return FirstFocusScope(
        ready: true,
        child: ListView.builder(
          clipBehavior: Clip.none,
          padding: EdgeInsets.only(
            top: context.rem(AppRem.sm),
            bottom: context.rem(2.5) + MediaQuery.paddingOf(context).bottom,
          ),
          physics: const BouncingScrollPhysics(),
          itemCount: sections.length,
          itemBuilder: (context, index) => sections[index],
        ),
      );
    }

    if (_lastQuery.isNotEmpty) {
      return _buildPlaceholder(
        Icons.search_off_rounded,
        64,
        0.2,
        context.l10n.commonNoResultsFor(_lastQuery),
      );
    }
    return _buildPlaceholder(
      Icons.manage_search_rounded,
      72,
      0.15,
      context.l10n.searchPrompt(_typeFilter.scopeLabel(context.l10n)),
    );
  }

  Widget _buildPlaceholder(
    IconData icon,
    double size,
    double iconAlpha,
    String label,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: AppColors.ink.withValues(alpha: iconAlpha)),
            SizedBox(height: context.rem(AppRem.md)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkAlpha(0.5),
                fontSize: AppType.bodyLg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
