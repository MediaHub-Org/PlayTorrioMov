import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../services/app_spacing.dart';
import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/adaptive_sheet.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/anime/anime_slider_section.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/hover_button.dart';
import 'anime_details_page.dart';

import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

class AnimeSearchPage extends StatefulWidget {
  /// Pre-fills the field and searches straight away. Set when the unified
  /// search hands a query over here for its AniList filters, so the user
  /// does not have to type the same thing a second time.
  final String? initialQuery;

  const AnimeSearchPage({
    super.key,
    this.initialQuery,
  });

  @override
  State<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends State<AnimeSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  bool _allowAdult = false;
  List<AnimeMedia> _allResults = [];

  // Filter selections
  String? _genre;
  int? _year;
  String? _season;
  String? _format;
  String? _status;
  String _sort = 'TRENDING_DESC';

  // Discovery sliders when search is empty and no filters
  List<AnimeMedia> _trendingList = [];
  List<AnimeMedia> _popularSeasonList = [];
  List<AnimeMedia> _topRatedList = [];
  bool _loadingInitial = true;

  static const _genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy',
    'Hentai', 'Horror', 'Mahou Shoujo', 'Mecha', 'Music', 'Mystery',
    'Psychological', 'Romance', 'Sci-Fi', 'Slice of Life',
    'Sports', 'Supernatural', 'Thriller',
  ];

  static const _seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
  static const _formats = ['TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL', 'MUSIC'];
  static const _statuses = ['RELEASING', 'FINISHED', 'NOT_YET_RELEASED', 'CANCELLED', 'HIATUS'];
  /// AniList's sort keys, in the order the picker lists them. The labels are
  /// looked up by key ([_sortLabel]) so they can follow the app's language.
  static const _sorts = [
    'TRENDING_DESC',
    'POPULARITY_DESC',
    'SCORE_DESC',
    'FAVOURITES_DESC',
    'START_DATE_DESC',
    'START_DATE',
    'TITLE_ROMAJI',
  ];

  String _sortLabel(String key) {
    final l10n = context.l10n;
    return switch (key) {
      'POPULARITY_DESC' => l10n.animeSortPopular,
      'SCORE_DESC' => l10n.animeSortTopRated,
      'FAVOURITES_DESC' => l10n.animeSortFavorited,
      'START_DATE_DESC' => l10n.catalogNewest,
      'START_DATE' => l10n.catalogOldest,
      'TITLE_ROMAJI' => l10n.librarySortTitle,
      _ => l10n.animeSortTrending,
    };
  }

  String _seasonLabel(String key) {
    final l10n = context.l10n;
    return switch (key) {
      'WINTER' => l10n.animeSeasonWinter,
      'SPRING' => l10n.animeSeasonSpring,
      'SUMMER' => l10n.animeSeasonSummer,
      'FALL' => l10n.animeSeasonFall,
      _ => _capitalize(key),
    };
  }

  String _statusLabel(String key) {
    final l10n = context.l10n;
    return switch (key) {
      'RELEASING' => l10n.animeStatusReleasing,
      'FINISHED' => l10n.animeStatusFinished,
      'NOT_YET_RELEASED' => l10n.animeStatusNotYet,
      'CANCELLED' => l10n.animeStatusCancelled,
      'HIATUS' => l10n.animeStatusHiatus,
      _ => _capitalize(key.replaceAll('_', ' ')),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadInitialSliders();
    final handover = widget.initialQuery?.trim() ?? '';
    if (handover.isNotEmpty) _searchController.text = handover;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // After the first frame, so the search's own setState lands on a
      // mounted, built page rather than mid-initState.
      if (handover.isNotEmpty) _performSearch(handover);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _genre != null ||
      _year != null ||
      _season != null ||
      _format != null ||
      _status != null ||
      _sort != 'TRENDING_DESC';

  void _loadInitialSliders() async {
    setState(() => _loadingInitial = true);
    try {
      final results = await Future.wait([
        AnilistService.instance.fetchTrendingAnime(page: 1, perPage: 20),
        AnilistService.instance.fetchPopularThisSeason(page: 1, perPage: 20),
        AnilistService.instance.fetchTopRated(page: 1, perPage: 20),
      ]);

      if (mounted) {
        setState(() {
          _trendingList = results[0];
          _popularSeasonList = results[1];
          _topRatedList = results[2];
          _loadingInitial = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty && !_hasActiveFilters) {
      setState(() {
        _allResults.clear();
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(trimmed);
    });
  }

  void _performSearch([String? query]) async {
    final q = (query ?? _searchController.text).trim();
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await AnilistService.instance.searchAnime(
        q,
        genre: _genre,
        year: _year,
        season: _season,
        format: _format,
        status: _status,
        sort: _sort,
        isAdult: _allowAdult,
        perPage: 35,
      );
      if (!mounted) return;

      setState(() {
        _allResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _allResults = [];
      });
    }
  }

  void _toggleAdult(bool val) {
    setState(() {
      _allowAdult = val;
    });
    _performSearch();
  }

  void _resetFilters() {
    setState(() {
      _genre = null;
      _year = null;
      _season = null;
      _format = null;
      _status = null;
      _sort = 'TRENDING_DESC';
    });
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch();
    } else {
      setState(() {
        _allResults.clear();
      });
    }
  }

  Future<void> _pickFromList<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
    required T? current,
    required void Function(T?) onSelected,
  }) async {
    final picked = await showAdaptiveSheet<_PickResult<T>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.rem(AppRem.lg))),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              // Top drag indicator
              Container(
                margin: EdgeInsets.only(top: context.rem(AppRem.ms), bottom: context.rem(AppRem.sm)),
                width: context.rem(2.75),
                height: context.rem(AppRem.xs),
                decoration: BoxDecoration(
                  color: AppColors.inkAlpha(0.25),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.xxs)),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(context.rem(1.375), context.rem(AppRem.snug), context.rem(AppRem.md), context.rem(AppRem.ms)),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: AppType.subhead,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (current != null)
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(_PickResult<T>(null, true)),
                        child: Text(
                          context.l10n.animeClear,
                          style: TextStyle(
                            color: AppThemeService.currentPalette.value.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: AppType.body,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(color: AppColors.inkAlpha(0.10), height: 1), // px: a hairline, not a layout size

              // Options list
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final v = items[i];
                    final selected = v == current;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(_PickResult<T>(v, false)),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(1.375), vertical: context.rem(0.875)),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.12)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.inkAlpha(0.04),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label(v),
                                  style: TextStyle(
                                    color: selected ? AppThemeService.currentPalette.value.primaryColor : AppColors.ink,
                                    fontSize: AppType.bodyMd,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_rounded,
                                  color: AppThemeService.currentPalette.value.primaryColor,
                                  size: context.rem(AppRem.icon),
                                ),
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
        );
      },
    );

    if (picked != null) {
      if (picked.cleared) {
        setState(() {
          onSelected(null);
        });
        _performSearch();
      } else if (picked.value != null) {
        setState(() {
          onSelected(picked.value);
        });
        _performSearch();
      }
    }
  }

  void _pickYear() {
    final now = DateTime.now().year;
    final years = List.generate(40, (i) => now + 1 - i);
    _pickFromList<int>(
      title: context.l10n.librarySortYear,
      items: years,
      label: (y) => '$y',
      current: _year,
      onSelected: (v) => _year = v,
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

  Widget _buildFilterDropdownButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
      child: Material(
        color: active
            ? primaryColor.withValues(alpha: 0.22)
            : AppColors.inkAlpha(0.06),
        borderRadius: BorderRadius.circular(context.rem(1.25)),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rem(1.25)),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.sm)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.rem(1.25)),
              border: Border.all(
                color: active
                    ? primaryColor.withValues(alpha: 0.65)
                    : AppColors.inkAlpha(0.10),
                width: 1.1, // px: a hairline, not a layout size
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: context.rem(0.875), color: AppColors.inkMuted),
                  SizedBox(width: context.rem(AppRem.snug)),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: active ? AppColors.ink : AppColors.inkMuted,
                    fontSize: AppType.captionPlus,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                SizedBox(width: context.rem(AppRem.xs)),
                Icon(
                  Icons.expand_more_rounded,
                  size: context.rem(0.9375),
                  color: active ? primaryColor : AppColors.inkDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(AnimeMedia anime) {
    pushPage(context, AnimeDetailsPage(anime: anime));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final isSearching = _searchController.text.trim().isNotEmpty || _hasActiveFilters;

    // Split search results into format sliders
    final tvSeries = _allResults
        .where((a) => a.format.toUpperCase() == 'TV' || a.format.toUpperCase() == 'TV_SHORT')
        .toList();
    final movies = _allResults
        .where((a) => a.format.toUpperCase() == 'MOVIE')
        .toList();
    final ovasAndOthers = _allResults
        .where((a) =>
            a.format.toUpperCase() != 'TV' &&
            a.format.toUpperCase() != 'TV_SHORT' &&
            a.format.toUpperCase() != 'MOVIE')
        .toList();

    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 62),
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
                        AppColors.canvas.withValues(alpha: 0.94),
                        AppColors.canvas.withValues(alpha: 0.70),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.inkAlpha(0.06),
                      ),
                    ),
                  ),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Back Button + Search Bar + 18+ Toggle
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageInset(context),
                    ),
                    child: Row(
                      children: [
                        const GlassBackButton(),
                        SizedBox(width: context.rem(0.625)),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
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
                                  fontSize: AppType.bodyMd,
                                  fontWeight: FontWeight.w500,
                                ),
                                textInputAction: TextInputAction.search,
                                onChanged: _onSearchChanged,
                                onSubmitted: _performSearch,
                                decoration: InputDecoration(
                                  hintText: context.l10n.animeSearchHint,
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


                        // 18+ Adult Toggle Pill
                        Padding(
                            padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
                            child: HoverButton(
                              scaleAmount: 1.05,
                              showFocusRing: true,
                              focusRingBorderRadius: context.rem(AppRem.radiusPill) + context.rem(AppRem.xxs),
                              onTap: () => _toggleAdult(!_allowAdult),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(0.4375)),
                                decoration: BoxDecoration(
                                  color: _allowAdult
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.20)
                                      : AppColors.inkAlpha(0.06),
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                                  border: Border.all(
                                    color: _allowAdult
                                        ? const Color(0xFFEF4444)
                                        : AppColors.inkAlpha(0.12),
                                    width: 1.2, // px: a hairline, not a layout size
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _allowAdult
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      size: context.rem(AppRem.iconXs),
                                      color: _allowAdult ? const Color(0xFFEF4444) : AppColors.inkSubtle,
                                    ),
                                    SizedBox(width: context.rem(0.3125)),
                                    Text(
                                      '18+',
                                      style: TextStyle(
                                        color: _allowAdult ? const Color(0xFFEF4444) : AppColors.inkMuted,
                                        fontSize: AppType.caption,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.rem(AppRem.sm)),

                  // Row 2: Custom Dropdown Menu Buttons
                  SizedBox(
                    height: AppSpacing.textScaledHeight(context, 38),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md)),
                      children: [
                        // Sort Dropdown
                        _buildFilterDropdownButton(
                          label: context.l10n.animeSortLabel(_sortLabel(_sort)),
                          active: _sort != 'TRENDING_DESC',
                          onTap: () => _pickFromList<String>(
                            title: context.l10n.librarySortBy,
                            items: _sorts,
                            label: _sortLabel,
                            current: _sort,
                            onSelected: (v) => _sort = v ?? 'TRENDING_DESC',
                          ),
                        ),

                        // Genre Dropdown
                        _buildFilterDropdownButton(
                          label: _genre ?? context.l10n.animeGenre,
                          active: _genre != null,
                          onTap: () => _pickFromList<String>(
                            title: context.l10n.animeGenre,
                            items: _genres,
                            label: (g) => g,
                            current: _genre,
                            onSelected: (v) => _genre = v,
                          ),
                        ),

                        // Year Dropdown
                        _buildFilterDropdownButton(
                          label: _year != null ? '$_year' : context.l10n.animeYear,
                          active: _year != null,
                          onTap: _pickYear,
                        ),

                        // Season Dropdown
                        _buildFilterDropdownButton(
                          label: _season != null ? _seasonLabel(_season!) : context.l10n.animeSeason,
                          active: _season != null,
                          onTap: () => _pickFromList<String>(
                            title: context.l10n.animeSeason,
                            items: _seasons,
                            label: _seasonLabel,
                            current: _season,
                            onSelected: (v) => _season = v,
                          ),
                        ),

                        // Format Dropdown
                        _buildFilterDropdownButton(
                          label: _format ?? context.l10n.animeFormat,
                          active: _format != null,
                          onTap: () => _pickFromList<String>(
                            title: context.l10n.animeFormat,
                            items: _formats,
                            label: (f) => f,
                            current: _format,
                            onSelected: (v) => _format = v,
                          ),
                        ),

                        // Status Dropdown
                        _buildFilterDropdownButton(
                          label: _status != null ? _statusLabel(_status!) : context.l10n.animeStatus,
                          active: _status != null,
                          onTap: () => _pickFromList<String>(
                            title: context.l10n.animeStatus,
                            items: _statuses,
                            label: _statusLabel,
                            current: _status,
                            onSelected: (v) => _status = v,
                          ),
                        ),

                        // Reset Button
                        if (_hasActiveFilters)
                          Padding(
                            padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
                            child: Material(
                              color: AppColors.inkAlpha(0.05),
                              borderRadius: BorderRadius.circular(context.rem(1.25)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(context.rem(1.25)),
                                onTap: _resetFilters,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(AppRem.sm)),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(context.rem(1.25)),
                                    border: Border.all(color: AppColors.inkFaint),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close_rounded, size: context.rem(0.875), color: AppColors.inkMuted),
                                      SizedBox(width: context.rem(AppRem.xs)),
                                      Text(
                                        context.l10n.animeReset,
                                        style: TextStyle(
                                          color: AppColors.inkMuted,
                                          fontSize: AppType.caption,
                                          fontWeight: FontWeight.bold,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: Stack(
          children: [
            // Content Area
            if (_isLoading || (_loadingInitial && _allResults.isEmpty && _trendingList.isEmpty))
              Center(
                child: CircularProgressIndicator(color: palette.primaryColor),
              )
            else if (isSearching && _allResults.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: context.rem(4),
                      color: AppColors.inkAlpha(0.2),
                    ),
                    SizedBox(height: context.rem(AppRem.md)),
                    Text(
                      context.l10n.animeNoMatch,
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: AppType.bodyLg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.rem(AppRem.sm)),
                    Text(
                      context.l10n.animeNoMatchHint,
                      style: TextStyle(
                        color: AppColors.inkAlpha(0.4),
                        fontSize: AppType.small,
                      ),
                    ),
                  ],
                ),
              )
            else if (_allResults.isNotEmpty)
              FirstFocusScope(
                ready: true,
                child: ListView(
                clipBehavior: Clip.none,
                padding: EdgeInsets.only(
                  top: topPadding + kToolbarHeight + context.rem(5),
                  bottom: context.rem(2.5),
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (tvSeries.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animeTvSeries,
                      subtitle: context.l10n.animeResultsCount(tvSeries.length),
                      animeList: tvSeries,
                      onAnimeTap: _openDetails,
                    ),
                  if (movies.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animeMovies,
                      subtitle: context.l10n.animeResultsCount(movies.length),
                      animeList: movies,
                      onAnimeTap: _openDetails,
                    ),
                  if (ovasAndOthers.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animeOvas,
                      subtitle: context.l10n.animeResultsCount(ovasAndOthers.length),
                      animeList: ovasAndOthers,
                      onAnimeTap: _openDetails,
                    ),
                ],
                ),
              )
            else
              // Discovery Sliders when not searching
              FirstFocusScope(
                ready: true,
                child: ListView(
                clipBehavior: Clip.none,
                padding: EdgeInsets.only(
                  top: topPadding + kToolbarHeight + context.rem(5),
                  bottom: context.rem(2.5),
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (_trendingList.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animeTrendingTitle,
                      animeList: _trendingList,
                      onAnimeTap: _openDetails,
                    ),
                  if (_popularSeasonList.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animePopularSeason,
                      animeList: _popularSeasonList,
                      onAnimeTap: _openDetails,
                    ),
                  if (_topRatedList.isNotEmpty)
                    AnimeSliderSection(
                      title: context.l10n.animeTopRatedAllTime,
                      animeList: _topRatedList,
                      onAnimeTap: _openDetails,
                    ),
                ],
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

class _PickResult<T> {
  final T? value;
  final bool cleared;
  _PickResult(this.value, this.cleared);
}
