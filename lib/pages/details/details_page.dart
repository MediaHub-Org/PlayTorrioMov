import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/over_artwork.dart';
import '../../l10n/l10n.dart';
import '../../widgets/common/arrow_affordance.dart';
import '../../models/details/credit.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/details/credit_card.dart';
import '../../widgets/details/similar_card.dart';
import '../../widgets/common/reading_direction.dart';

import '../../models/movie/cast_member.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_year.dart';
import '../../models/movie/video.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/metadata/bestsimilar_scraper.dart';
import '../../services/metadata/metadata_service.dart';
import '../../services/tmdb/tmdb_service.dart';
import '../../services/tmdb/tmdb_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/genre_tag_row.dart';
import '../../widgets/common/details_section_header.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/library_actions_row.dart';
import '../discover/discover_page.dart';
import '../player/watch_screen.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
class _Space {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class _Palette {
  // Getters, not constants: these follow the theme now that the backdrop is
  // bounded to the hero and the rest of the page is the page. The accents
  // below stay fixed -- they are this page's brand reds and its rating gold,
  // not surfaces.
  static Color get bg => AppColors.canvas;
  static Color get surface => AppColors.surface;
  static const accent = Color(0xFFE50914);
  static const accentDim = Color(0xFF9A0710);
  static const gold = Color(0xFFFFC107);
}

class DetailsPage extends StatefulWidget {
  final Movie movie;

  /// Optional "More Like This" row. Not every addon/catalog gives you
  /// recommendations for free — pass in whatever list of Movie you already
  /// have (e.g. same-genre catalog results, or a recommendations field if
  /// your addon's meta response includes one). Section just doesn't render
  /// if this is null/empty, so it's safe to leave unset for now.
  final List<Movie>? relatedItems;

  /// Skips straight to playback once details finish loading -- the same
  /// action tapping the play button would trigger, just automatic. For a
  /// "Watch Now" entry point (e.g. a hero carousel) that shouldn't require
  /// a second tap once the page opens.
  final bool autoPlay;

  const DetailsPage({
    super.key,
    required this.movie,
    this.relatedItems,
    this.autoPlay = false,
  });

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage>
    with SingleTickerProviderStateMixin {
  MovieDetail? _detail;
  bool _isLoading = true;

  int? _selectedSeason;
  int? _previousSeason;
  List<Video> _currentSeasonEpisodes = [];

  bool _isSynopsisExpanded = false;

  // Similar content from BestSimilar
  List<BSItem> _similarItems = [];
  bool _isFetchingSimilar = false;

  // TMDB cast enrichment (photos/character names), only when a key is
  // configured and the addon's own cast data has none.
  List<CastMember>? _enrichedCast;

  /// Directing crew from the same TMDB `/credits` call that fills
  /// [_enrichedCast]. Most addons send no crew at all, so without this the
  /// Direction half of the credits row was empty for nearly everything.
  List<CrewMember>? _enrichedCrew;

  /// The TMDB synopsis in the viewer's language, when TMDB has one. The
  /// addon's own text stays the fallback: without a configured key, or when
  /// TMDB sends nothing, there is nothing to prefer.
  String? _tmdbOverview;

  String? _resolvedType;
  String? _resolvedBaseUrl;

  bool get _isCollection {
    final t = _resolvedType ?? _detail?.type ?? widget.movie.type;
    return t == 'collections' ||
        t == 'collection' ||
        widget.movie.isCollection ||
        (_detail != null && _detail!.isCollection);
  }

  bool get _isSeries {
    final t = _resolvedType ?? _detail?.type ?? widget.movie.type;
    return (t == 'series' || t == 'tv' || t == 'anime' || (_detail != null && _detail!.videos.isNotEmpty)) && !_isCollection;
  }

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<int, ScrollController> _episodeControllers = {};

  ScrollController get _episodeScrollController {
    final key = _selectedSeason ?? -1;
    if (!_episodeControllers.containsKey(key)) {
      final c = ScrollController();
      c.addListener(_updateEpisodeScrollButtons);
      _episodeControllers[key] = c;
    }
    return _episodeControllers[key]!;
  }

  final ScrollController _castScrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();
  final ScrollController _relatedScrollController = ScrollController();
  final ScrollController _similarScrollController = ScrollController();

  bool _canScrollEpisodesLeft = false;
  bool _canScrollEpisodesRight = true;
  bool _isHoveringEpisodes = false;

  bool _canScrollCastLeft = false;
  bool _canScrollCastRight = true;
  bool _isHoveringCast = false;

  bool _canScrollRelatedLeft = false;
  bool _canScrollRelatedRight = true;
  bool _isHoveringRelated = false;

  bool _canScrollSeasonsLeft = false;
  bool _canScrollSeasonsRight = true;
  bool _isHoveringSeasons = false;

  bool _canScrollSimilarLeft = false;
  bool _canScrollSimilarRight = true;
  bool _isHoveringSimilar = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _castScrollController.addListener(_updateCastScrollButtons);
    _relatedScrollController.addListener(_updateRelatedScrollButtons);
    _seasonScrollController.addListener(_updateSeasonScrollButtons);
    _similarScrollController.addListener(_updateSimilarScrollButtons);

    _fetchDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _episodeControllers.values) {
      c.dispose();
    }
    _castScrollController.dispose();
    _seasonScrollController.dispose();
    _relatedScrollController.dispose();
    _similarScrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePlayAction(Video? ep) async {
    if (_detail == null) return;

    pushPage(
      context,
      WatchScreen(
        detail: _detail!,
        type: _resolvedType ?? _detail!.type,
        selectedEpisode: ep,
        isCollection: _isCollection,
      ),
    );
  }

  void _updateEpisodeScrollButtons() {
    if (!_episodeScrollController.hasClients) return;
    final canLeft = _episodeScrollController.position.pixels > 0;
    final canRight =
        _episodeScrollController.position.pixels <
        _episodeScrollController.position.maxScrollExtent;
    if (_canScrollEpisodesLeft != canLeft ||
        _canScrollEpisodesRight != canRight) {
      setState(() {
        _canScrollEpisodesLeft = canLeft;
        _canScrollEpisodesRight = canRight;
      });
    }
  }

  void _updateCastScrollButtons() {
    if (!_castScrollController.hasClients) return;
    final canLeft = _castScrollController.position.pixels > 0;
    final canRight =
        _castScrollController.position.pixels <
        _castScrollController.position.maxScrollExtent;
    if (_canScrollCastLeft != canLeft || _canScrollCastRight != canRight) {
      setState(() {
        _canScrollCastLeft = canLeft;
        _canScrollCastRight = canRight;
      });
    }
  }

  void _updateRelatedScrollButtons() {
    if (!_relatedScrollController.hasClients) return;
    final canLeft = _relatedScrollController.position.pixels > 0;
    final canRight =
        _relatedScrollController.position.pixels <
        _relatedScrollController.position.maxScrollExtent;
    if (_canScrollRelatedLeft != canLeft ||
        _canScrollRelatedRight != canRight) {
      setState(() {
        _canScrollRelatedLeft = canLeft;
        _canScrollRelatedRight = canRight;
      });
    }
  }

  void _updateSeasonScrollButtons() {
    if (!_seasonScrollController.hasClients) return;
    final canLeft = _seasonScrollController.position.pixels > 0;
    final canRight =
        _seasonScrollController.position.pixels <
        _seasonScrollController.position.maxScrollExtent;
    if (_canScrollSeasonsLeft != canLeft ||
        _canScrollSeasonsRight != canRight) {
      setState(() {
        _canScrollSeasonsLeft = canLeft;
        _canScrollSeasonsRight = canRight;
      });
    }
  }

  void _updateSimilarScrollButtons() {
    if (!_similarScrollController.hasClients) return;
    final canLeft = _similarScrollController.position.pixels > 0;
    final canRight =
        _similarScrollController.position.pixels <
        _similarScrollController.position.maxScrollExtent;
    if (_canScrollSimilarLeft != canLeft ||
        _canScrollSimilarRight != canRight) {
      setState(() {
        _canScrollSimilarLeft = canLeft;
        _canScrollSimilarRight = canRight;
      });
    }
  }

  void _scrollList(ScrollController controller, double directionMultiplier) {
    if (!controller.hasClients) return;
    final viewportWidth = controller.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.7 * directionMultiplier;
    final target = (controller.position.pixels + scrollAmount).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _fetchDetails() async {
    String effectiveBaseUrl = widget.movie.addonBaseUrl;
    String effectiveType = widget.movie.type;
    String effectiveId = widget.movie.id;

    if (effectiveId.startsWith('bestsimilar_') ||
        effectiveBaseUrl.contains('bestsimilar')) {
      final yearNum = widget.movie.year != null
          ? startYearOf(widget.movie.year)
          : null;
      final resolved = await MetadataService.findMovieByTitle(
        title: widget.movie.name,
        type: widget.movie.type,
        year: yearNum,
      );
      if (resolved != null) {
        effectiveBaseUrl = resolved.addonBaseUrl;
        effectiveType = resolved.type;
        effectiveId = resolved.id;
        _resolvedBaseUrl = effectiveBaseUrl;
        _resolvedType = effectiveType;
      }
    }

    var meta = await MetadataService.fetchMeta(
      baseUrl: effectiveBaseUrl,
      type: effectiveType,
      imdbId: effectiveId,
    );

    // If fetchMeta failed, try fallback search to resolve
    if (meta == null && !effectiveId.startsWith('tt')) {
      final yearNum = widget.movie.year != null
          ? startYearOf(widget.movie.year)
          : null;
      final resolved = await MetadataService.findMovieByTitle(
        title: widget.movie.name,
        type: widget.movie.type,
        year: yearNum,
      );
      if (resolved != null) {
        effectiveBaseUrl = resolved.addonBaseUrl;
        effectiveType = resolved.type;
        effectiveId = resolved.id;
        _resolvedBaseUrl = effectiveBaseUrl;
        _resolvedType = effectiveType;
        meta = await MetadataService.fetchMeta(
          baseUrl: resolved.addonBaseUrl,
          type: resolved.type,
          imdbId: resolved.id,
        );
      }
    }

    if (meta != null && meta.type.isNotEmpty) {
      _resolvedType = meta.type;
    }

    if (mounted) {
      setState(() {
        _detail = meta;
        _isLoading = false;
        _tmdbOverview = null;

        if (meta != null &&
            (_isSeries || meta.videos.isNotEmpty) &&
            meta.videos.isNotEmpty) {
          final seasons = meta.videos
              .map((v) => v.season)
              .where((s) => s != null)
              .toSet()
              .toList();
          seasons.sort();
          if (seasons.isNotEmpty) {
            _selectedSeason = seasons.first;
            _updateEpisodesForSeason();
          } else {
            _currentSeasonEpisodes = List.from(meta.videos);
          }
        }
      });
      _animController.forward();

      if (widget.autoPlay && meta != null) {
        // Same episode/video _buildPlayButton's own onTap picks.
        _handlePlayAction(
          _currentSeasonEpisodes.isNotEmpty
              ? _currentSeasonEpisodes.first
              : (meta.videos.isNotEmpty ? meta.videos.first : null),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateSeasonScrollButtons();
          _updateCastScrollButtons();
          _updateRelatedScrollButtons();
        }
      });

      // Fire off similar content fetch in background
      _fetchSimilarContent();
      _fetchCastFromTmdb();
    }
  }

  Future<void> _fetchCastFromTmdb() async {
    final meta = _detail;
    if (meta == null) return;
    // isConfigured, not apiKey: a key can also come from the build
    // (--dart-define / .env), which is the whole point of #34.
    if (!TmdbSettings.isConfigured) return;

    // Skip only when the addon already supplies every part of the credits
    // row. Cast photos alone are not enough: addons almost never send crew,
    // so a title with a photo-rich cast still had an empty Direction half
    // until this stopped short-circuiting on photos alone. Character names
    // are the third part, and were missing from this test -- an addon that
    // sent photos and a director stopped the lookup cold, leaving every
    // actor's card with a blank role even though TMDB had the characters.
    // Checked before the id lookup below, so a title that needs nothing
    // costs no requests.
    final hasPhotos = meta.castMembers.any(
      (c) => c.profileUrl != null && c.profileUrl!.isNotEmpty,
    );
    final hasCharacters = meta.castMembers.any(
      (c) => c.character != null && c.character!.trim().isNotEmpty,
    );
    final hasCrew = meta.directorsList.isNotEmpty || meta.director.isNotEmpty;
    if (hasPhotos && hasCharacters && hasCrew) return;

    final isTvShow =
        widget.movie.type == 'series' || widget.movie.type == 'anime';

    // `MovieDetail.tmdbId` is read from `moviedb_id`, which Cinemeta and
    // most Stremio addons do not send -- they send `imdb_id`. Bailing out
    // when it was null meant no TMDB request was made for essentially any
    // title, so the page always fell back to the addon's plain name
    // strings: no photos, no character names, no crew. Resolve the id from
    // IMDb instead of giving up.
    var tmdbId = meta.tmdbId;
    if (tmdbId == null || tmdbId.isEmpty) {
      tmdbId = await TmdbService.resolveTmdbIdFromImdb(
        meta.id,
        isTvShow: isTvShow,
      );
      if (!mounted) return;
    }
    if (tmdbId == null || tmdbId.isEmpty) return;

    // The synopsis in the viewer's language, fetched next to the credits so
    // the page makes one TMDB pass per title. TMDB's catalog copy replaces
    // the addon's when it exists -- and translated, where the addon only
    // ever has English. Silent when there is nothing better to show.
    final localeCode = AppThemeService.locale.value?.languageCode;
    TmdbService.fetchOverview(
      tmdbId: tmdbId,
      isTvShow: isTvShow,
      localeCode: localeCode,
    ).then((overview) {
      if (overview != null && overview.isNotEmpty && mounted) {
        setState(() => _tmdbOverview = overview);
      }
    });

    final credits = await TmdbService.fetchCredits(tmdbId, isTvShow: isTvShow);
    if (credits.isEmpty || !mounted) return;
    setState(() {
      if (credits.cast.isNotEmpty) _enrichedCast = credits.cast;
      // Crew is taken whenever TMDB has any: unlike cast, the addon almost
      // never supplies it, so there is nothing better to preserve.
      if (credits.crew.isNotEmpty) _enrichedCrew = credits.crew;
    });
  }

  Future<void> _fetchSimilarContent() async {
    if (_isFetchingSimilar) return;
    setState(() => _isFetchingSimilar = true);

    try {
      final title = _detail?.name ?? widget.movie.name;
      final yearStr = _detail?.year ?? widget.movie.year;
      final year = yearStr != null
          ? startYearOf(yearStr)
          : null;
      final isTv = _isSeries;

      final hit = await BestSimilarScraper.findBest(
        title: title,
        year: year,
        isTv: isTv,
      );

      if (hit == null || !mounted) {
        if (mounted) setState(() => _isFetchingSimilar = false);
        return;
      }

      final details = await BestSimilarScraper.fetchDetails(
        id: hit.id,
        slug: hit.slug,
      );

      if (mounted) {
        setState(() {
          _similarItems = details?.similar ?? [];
          _isFetchingSimilar = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateSimilarScrollButtons();
        });
      }
    } catch (e) {
      debugPrint('[Similar] fetch failed: $e');
      if (mounted) setState(() => _isFetchingSimilar = false);
    }
  }

  Future<void> _openSimilarItem(BSItem item) async {
    final resolved = await MetadataService.findMovieByTitle(
      title: item.title,
      type: item.isTv ? 'series' : (_resolvedType ?? widget.movie.type),
      year: item.year,
      preferredBaseUrl: _resolvedBaseUrl ?? widget.movie.addonBaseUrl,
    );

    if (resolved != null && mounted) {
      pushReplacementPage(context, DetailsPage(movie: resolved));
    }
  }

  void _updateEpisodesForSeason() {
    if (_detail == null || _selectedSeason == null) return;
    setState(() {
      _currentSeasonEpisodes = _detail!.videos
          .where((v) => v.season == _selectedSeason)
          .toList();
      _currentSeasonEpisodes.sort(
        (a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_episodeScrollController.hasClients) {
        _episodeScrollController.jumpTo(0);
      }
      _updateEpisodeScrollButtons();
    });
  }

  bool _isDesktop([BuildContext? ctx]) {
    return AppBreakpoints.of(ctx ?? context) == ScreenTier.desktop;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.bg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _Palette.accent),
            )
          : _detail == null
          ? _buildError()
          : _buildContent(context),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: AppColors.inkFaint,
          ),
          const SizedBox(height: _Space.md),
          Text(
            context.l10n.detailsUnavailable,
            style: TextStyle(color: AppColors.inkSubtle, fontSize: 18),
          ),
          const SizedBox(height: _Space.lg),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.inkAlpha(0.10),
              foregroundColor: AppColors.ink,
            ),
            child: Text(context.l10n.detailsGoBack),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final meta = _detail!;
    final bgUrl = meta.background ?? meta.poster ?? widget.movie.poster;
    final posterUrl = meta.poster ?? widget.movie.poster;
    final isDesktop = _isDesktop(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final contentMaxWidth = isDesktop ? 1440.0 : double.infinity;
    // How far down the poster/title block starts. Previously a fraction of
    // a "hero height" left over from when this page sat below the hub's top
    // bar -- once the page went fullscreen that read as an oversized empty
    // band with nothing above it to justify the space. The only thing that
    // actually needs guaranteed clearance up here is the floating back
    // button (see FloatingBackButton), so size to its own footprint
    // instead: status-bar inset down to its top edge, its own ~44px circle,
    // a little breathing room after it.
    final topGap = AppSpacing.floatingTopInset(context) + 44 + _Space.md;

    // The backdrop is part of the scroll content and only as tall as the
    // hero block, rather than a pinned layer filling the viewport forever.
    //
    // Pinned, it sat behind *everything*: scroll to the credits and the
    // artwork was still there under them, which is why this page could only
    // ever be dark -- ink over a photograph has to be white. Bounded, the
    // hero is over artwork and everything below it is on the page, so the
    // page can follow the theme and the shared controls on it (genre chips,
    // section headings, the library buttons) are right in both.
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      if (bgUrl != null)
                        Positioned.fill(child: _buildBackdrop(bgUrl)),
                      // Full-bleed art, inset content: the padding goes on
                      // the column, not on the Stack.
                      OverArtwork.yes(
                        child: _contentColumn(
                          isDesktop: isDesktop,
                          maxWidth: contentMaxWidth,
                          children: [
                            SizedBox(height: topGap),
                            isDesktop
                                ? _buildDesktopLayout(meta, posterUrl)
                                : _buildMobileLayout(meta, posterUrl),
                            const SizedBox(height: _Space.xl),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _contentColumn(
                    isDesktop: isDesktop,
                    maxWidth: contentMaxWidth,
                    bottomPadding: _Space.xxl + bottomInset,
                    children: [
                        if (_credits(meta).isNotEmpty) ...[
                          _buildCreditsRow(meta),
                          const SizedBox(height: _Space.xl),
                        ],
                        if (meta.videos.isNotEmpty) ...[
                          if (meta.videos
                                  .map((v) => v.season)
                                  .where((s) => s != null)
                                  .toSet()
                                  .length >
                              1) ...[
                            _buildSeasonSelector(meta),
                            const SizedBox(height: _Space.lg),
                          ] else ...[
                            DetailsSectionHeader(
                              _isCollection
                                  ? context.l10n.detailsMoviesInCollection
                                  : context.l10n.detailsEpisodes,
                            ),
                          ],
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 550),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  final isIncoming =
                                      child.key == ValueKey(_selectedSeason);
                                  final int incomingSeason =
                                      _selectedSeason ?? 1;
                                  final int previousSeason =
                                      _previousSeason ?? 1;

                                  final bool slidingRight =
                                      incomingSeason > previousSeason;

                                  // Incoming starts offset, Outgoing ends offset
                                  final Offset beginOffset = isIncoming
                                      ? (slidingRight
                                            ? const Offset(0.12, 0.0)
                                            : const Offset(-0.12, 0.0))
                                      : (slidingRight
                                            ? const Offset(-0.12, 0.0)
                                            : const Offset(0.12, 0.0));

                                  final slideAnimation =
                                      Tween<Offset>(
                                        begin: beginOffset,
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      );

                                  final scaleAnimation =
                                      Tween<double>(
                                        begin: 0.94,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      );

                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slideAnimation,
                                      child: ScaleTransition(
                                        scale: scaleAnimation,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                            child: _buildEpisodeSlider(
                              key: ValueKey(_selectedSeason),
                            ),
                          ),
                          const SizedBox(height: _Space.xl),
                        ],
                        if (widget.relatedItems != null &&
                            widget.relatedItems!.isNotEmpty) ...[
                          _buildRelatedRow(widget.relatedItems!),
                          const SizedBox(height: _Space.xl),
                        ],
                        if (_similarItems.isNotEmpty) ...[
                          _buildSimilarRow(),
                          const SizedBox(height: _Space.xl),
                        ] else if (_isFetchingSimilar) ...[
                          DetailsSectionHeader(context.l10n.detailsSimilarContent),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _Palette.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: _Space.xl),
                        ],
                        const SizedBox(height: _Space.xxl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const FloatingBackButton(),
      ],
    );
  }

  /// One run of page content: centered, width-capped on desktop, and inset
  /// from the screen edges by the page's own gutter. The hero and the rows
  /// below it are two runs so the backdrop can sit behind the first one
  /// without the second inheriting it.
  Widget _contentColumn({
    required bool isDesktop,
    required double maxWidth,
    required List<Widget> children,
    double bottomPadding = 0,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? _Space.xxl : _Space.lg,
            0,
            isDesktop ? _Space.xxl : _Space.lg,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // The hero's cinematic backdrop.
  //
  // This used to be pinned behind the *entire* viewport at every scroll
  // offset, so the artwork was still under the credits and the similar-titles
  // row. That read well in a dark-only app and made a light one impossible:
  // ink over a photograph has to be white, so the whole page was stuck white.
  //
  // Now it is part of the scroll content and as tall as the hero block, and
  // three gradients hand it off to the page rather than to a fixed dark, so
  // no single one has to be aggressive enough to look like a hard cutoff:
  //   1. a soft cap at the very top (keeps the back button legible)
  //   2. a bottom fade that settles into the page's own color
  //   3. a gentle horizontal wash so text on the left never fights the image
  // -------------------------------------------------------------------------
  Widget _buildBackdrop(String bgUrl) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: bgUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // Horizontal wash -- darkens where the title and synopsis sit,
          // leaving the rest of the image breathing room instead of blacking
          // it all out. Fades from the page's own color so the art looks
          // like it grows out of the page rather than sitting on it.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.canvas,
                  AppColors.scrim.withValues(alpha: 0.60),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 0.82],
              ),
            ),
          ),
          // Bottom fade into the page. This is what joins the hero to the
          // rows below it now that the backdrop ends with the hero instead
          // of running the whole viewport.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.scrim.withValues(alpha: 0.40),
                  AppColors.canvas,
                ],
                stops: const [0.0, 0.62, 0.98],
              ),
            ),
          ),
          // Top cap so the back button always has contrast. Stays a fixed
          // dark in either theme: it is over the photograph, not the page.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black45, Colors.transparent],
                stops: [0.0, 0.22],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Desktop: real two-column layout. Poster + actions pinned left;
  // logo/title, metadata, synopsis fill the right. With the backdrop now
  // persistent behind everything, this row no longer needs a "quick facts"
  // filler box just to feel less empty underneath the poster — genres are
  // already in the metadata line, so it's dropped to avoid repeating itself.
  // -------------------------------------------------------------------------
  Widget _buildDesktopLayout(MovieDetail meta, String? posterUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (posterUrl != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      // subtle accent-tinted glow behind the poster, on top
                      // of the usual drop shadow, so it reads as "lit" rather
                      // than just floating on black
                      BoxShadow(
                        color: _Palette.accent.withOpacity(0.18),
                        blurRadius: 46,
                        spreadRadius: -6,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            // Artwork stand-in while the poster loads, so it keeps a fixed
            // dark fill in either theme -- it is standing in for a picture.
            const ColoredBox(color: Color(0xFF15171F)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: _Space.lg),
              _buildPlayButton(fullWidth: true),
              const SizedBox(height: _Space.sm),
              _buildLibraryButton(),
            ],
          ),
        ),
        const SizedBox(width: _Space.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoOrTitle(meta, isDesktop: true),
              const SizedBox(height: _Space.md),
              _buildMetadataRow(meta),
              if (_synopsisText(meta).isNotEmpty) ...[
                const SizedBox(height: _Space.lg),
                _buildSynopsis(_synopsisText(meta)),
              ],
              if (meta.genres.isNotEmpty) ...[
                const SizedBox(height: _Space.lg),
                _buildGenreChips(meta.genres),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(MovieDetail meta, String? posterUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (posterUrl != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.accent.withOpacity(0.16),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    width: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(width: _Space.md),
            Expanded(child: _buildLogoOrTitle(meta, isDesktop: false)),
          ],
        ),
        const SizedBox(height: _Space.lg),
        _buildMetadataRow(meta),
        const SizedBox(height: _Space.lg),
        // Play on its own line, the library actions under it. They used to
        // share one Row, which shrank the primary action to make room for the
        // secondary ones and left nothing for a fourth. Stacked, Play gets the
        // full width and the four actions split it between them.
        _buildPlayButton(fullWidth: true),
        const SizedBox(height: _Space.sm),
        _buildLibraryButton(),
        if (_synopsisText(meta).isNotEmpty) ...[
          const SizedBox(height: _Space.lg),
          _buildSynopsis(_synopsisText(meta)),
        ],
        if (meta.genres.isNotEmpty) ...[
          const SizedBox(height: _Space.md),
          _buildGenreChips(meta.genres),
        ],
      ],
    );
  }

  // Logo is now capped in both width AND height, so it can never dwarf the
  // poster next to it the way it did before (that's what made the poster
  // look like an afterthought in the screenshot).
  Widget _buildLogoOrTitle(MovieDetail meta, {required bool isDesktop}) {
    if (meta.logo != null && meta.logo!.isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 380 : 220,
          maxHeight: isDesktop ? 130 : 80,
        ),
        child: CachedNetworkImage(
          imageUrl: meta.logo!,
          alignment: mirroredIfRtl(context, Alignment.bottomLeft),
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
        fontSize: isDesktop ? 40 : 28,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.0,
        color: Colors.white,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }

  // Small pill chips for genres, sitting under the synopsis. This replaces
  // the old boxed "Quick Facts" panel — same information, but styled as a
  // lightweight row instead of a card that left dead space under the poster.
  Widget _buildGenreChips(List<String> genres) {
    return GenreTagRow(
      genres: genres,
      onTap: (g) => pushPage(context, DiscoverPage(query: g, isGenre: true)),
    );
  }

  Widget _buildMetadataRow(MovieDetail meta) {
    final List<Widget> items = [];

    if (meta.year != null && meta.year!.isNotEmpty) {
      items.add(
        Text(
          displayYearRange(meta.year),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_isSeries) {
      final seasonCount = meta.videos
          .map((v) => v.season)
          .where((s) => s != null)
          .toSet()
          .length;
      if (seasonCount > 0) {
        items.add(
          Text(
            context.l10n.detailsSeasonCount(seasonCount),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        );
      }
    } else if (meta.runtime != null && meta.runtime!.isNotEmpty) {
      items.add(
        Text(
          meta.runtime!,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    if (meta.imdbRating != null && meta.imdbRating!.isNotEmpty) {
      items.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: _Palette.gold, size: 14),
              const SizedBox(width: 4),
              Text(
                meta.imdbRating!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (meta.genres.isNotEmpty) {
      items.add(
        Text(
          meta.genres.take(3).join(' · '),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final List<Widget> spaced = [];
    for (int i = 0; i < items.length; i++) {
      spaced.add(items[i]);
      if (i < items.length - 1) {
        spaced.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _Space.sm),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white30, fontSize: 16),
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

  Widget _buildPlayButton({required bool fullWidth}) {
    return HoverButton(
      onTap: () => _handlePlayAction(
        _currentSeasonEpisodes.isNotEmpty
            ? _currentSeasonEpisodes.first
            : (_detail?.videos.isNotEmpty == true
                  ? _detail!.videos.first
                  : null),
      ),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_Palette.accent, _Palette.accentDim],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _Palette.accent.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 6),
            // Flexible as well as the icon's fixed size: the label is the
            // only part that grows with text scale, and without this it takes
            // the line and paints past the button.
            Flexible(
              child: Text(
                _isCollection
                    ? context.l10n.detailsPlayFirstMovie
                    : (_isSeries
                          ? context.l10n.detailsPlayEpisodes
                          : context.l10n.detailsPlayMovie),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MyListItem _buildMyListItem() {
    return MyListItem.fromMovieDetail(
      id: _detail!.id,
      name: _detail!.name,
      poster: _detail!.poster,
      year: _detail!.year,
      type: _detail!.type,
      imdbId: _detail!.id.startsWith('tt') ? _detail!.id : null,
      tmdbId: _detail!.tmdbId != null ? int.tryParse(_detail!.tmdbId!) : null,
    );
  }

  /// The shared Watchlist / Watched / Like row, so this page, Anime and
  /// anything else offering library actions stay spelled the same way.
  Widget _buildLibraryButton() {
    // `expanded` in both layouts: mobile gives it a full-width line under
    // Play, desktop the 280px poster column. Either way the four buttons
    // share the line rather than clustering at one end of it.
    return LibraryActionsRow(itemBuilder: _buildMyListItem, expanded: true);
  }

  /// What the synopsis block shows: TMDB's copy in the viewer's language
  /// when it arrived, else the addon's own text. Empty when neither has
  /// anything, which is when the block hides itself.
  String _synopsisText(MovieDetail meta) {
    final tmdb = _tmdbOverview;
    if (tmdb != null && tmdb.isNotEmpty) return tmdb;
    return meta.description ?? '';
  }

  Widget _buildSynopsis(String text) {
    const style = TextStyle(
      color: Colors.white70,
      fontSize: 15,
      height: 1.55,
      letterSpacing: 0.2,
    );
    const maxLines = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.clamp(0.0, 720.0);
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);

        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Text(
                  text,
                  maxLines: _isSynopsisExpanded ? null : maxLines,
                  overflow: _isSynopsisExpanded
                      ? TextOverflow.visible
                      : TextOverflow.fade,
                  style: style,
                ),
              ),
            ),
            if (isOverflowing) ...[
              const SizedBox(height: _Space.xs),
              GestureDetector(
                onTap: () =>
                    setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
                child: Text(
                  _isSynopsisExpanded
                      ? context.l10n.detailsShowLess
                      : context.l10n.detailsReadMore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Everyone credited on this title, crew first, as one flat list.
  ///
  /// Direction and Cast used to be two sections with two nearly identical
  /// card builders between them. They showed the same 76px avatar over the
  /// same name/role text stack and differed only in which field fed the
  /// second line -- `job` for crew, `character` for cast -- so the split
  /// bought two scroll positions, two hover states (only one of which had
  /// arrows) and two chances for the card geometry to drift apart.
  ///
  /// Crew leads because it is the shorter run and answers "whose film is
  /// this" before the reader starts scrolling through actors.
  List<Credit> _credits(MovieDetail meta) {
    final crew = _enrichedCrew ??
        (meta.directorsList.isNotEmpty
            ? meta.directorsList
            : meta.director
                  .map(
                    (d) => CrewMember(
                      name: d,
                      job: context.l10n.detailsDirector,
                    ),
                  )
                  .toList());

    final cast = _enrichedCast ??
        (meta.castMembers.isNotEmpty
            ? meta.castMembers
            : meta.cast.map((c) => CastMember(name: c)).toList());

    return [
      for (final c in crew)
        Credit(name: c.name, role: c.job, profileUrl: c.profileUrl),
      for (final c in cast)
        Credit(
          name: c.name,
          // The character they play, which is the whole reason a reader
          // scans a cast list. Left null when it is unknown: the card keeps
          // the line's height regardless, and a blank second line is
          // honest where the old "Cast" placeholder was not.
          role: (c.character != null && c.character!.trim().isNotEmpty)
              ? c.character!.trim()
              : null,
          profileUrl: c.profileUrl,
        ),
    ];
  }

  Widget _buildCreditsRow(MovieDetail meta) {
    final credits = _credits(meta);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringCast = true),
      onExit: (_) => setState(() => _isHoveringCast = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailsSectionHeader(context.l10n.detailsCastCrew),
          SizedBox(
            height: 148,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _castScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits.length,
                  separatorBuilder: (_, __) => const SizedBox(width: _Space.lg),
                  itemBuilder: (context, index) {
                    final credit = credits[index];
                    return CreditCard(
                      credit: credit,
                      onTap: () => pushPage(
                        context,
                        DiscoverPage(query: credit.name, isGenre: false),
                      ),
                    );
                  },
                ),
                if (_isDesktop()) ...[
                  if (_canScrollCastLeft)
                    PositionedDirectional(
                      start: 0,
                      top: 10,
                      bottom: 40,
                      child: _buildScrollArrow(
                        Icons.arrow_back_ios_new_rounded,
                        () => _scrollList(_castScrollController, -1),
                        _isHoveringCast,
                      ),
                    ),
                  if (_canScrollCastRight)
                    PositionedDirectional(
                      end: 0,
                      top: 10,
                      bottom: 40,
                      child: _buildScrollArrow(
                        Icons.arrow_forward_ios_rounded,
                        () => _scrollList(_castScrollController, 1),
                        _isHoveringCast,
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

  Widget _buildSeasonSelector(MovieDetail meta) {
    final seasons = meta.videos
        .map((v) => v.season)
        .whereType<int>()
        .toSet()
        .toList();
    seasons.sort();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringSeasons = true),
      onExit: (_) => setState(() => _isHoveringSeasons = false),
      child: SizedBox(
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ListView.separated(
              clipBehavior: Clip.none,
              controller: _seasonScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: _Space.sm),
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = _selectedSeason == season;
                return HoverButton(
                  onTap: () {
                    if (_selectedSeason != season) {
                      setState(() {
                        _previousSeason = _selectedSeason;
                        _selectedSeason = season;
                      });
                      _updateEpisodesForSeason();
                    }
                  },
                  scaleAmount: 1.02,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.ink.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.ink
                            : AppColors.ink.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      context.l10n.playerSeasonN(season),
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.ink,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_isDesktop()) ...[
              if (_canScrollSeasonsLeft)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildScrollArrow(
                    Icons.arrow_back_ios_new_rounded,
                    () => _scrollList(_seasonScrollController, -1),
                    _isHoveringSeasons,
                  ),
                ),
              if (_canScrollSeasonsRight)
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildScrollArrow(
                    Icons.arrow_forward_ios_rounded,
                    () => _scrollList(_seasonScrollController, 1),
                    _isHoveringSeasons,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeSlider({Key? key}) {
    final isDesktop = _isDesktop();
    final cardWidth = isDesktop ? 300.0 : 230.0;
    final fadeWidth = isDesktop ? 60.0 : 40.0;

    return MouseRegion(
      key: key,
      onEnter: (_) => setState(() => _isHoveringEpisodes = true),
      onExit: (_) => setState(() => _isHoveringEpisodes = false),
      child: SizedBox(
        height: isDesktop ? 275 : 245,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                final leftFadeStop = bounds.width > 0
                    ? (fadeWidth / bounds.width).clamp(0.01, 0.2)
                    : 0.05;
                final rightFadeStop = bounds.width > 0
                    ? (1.0 - (fadeWidth / bounds.width)).clamp(0.8, 0.99)
                    : 0.95;

                return LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    _canScrollEpisodesLeft ? Colors.transparent : Colors.black,
                    Colors.black,
                    Colors.black,
                    _canScrollEpisodesRight ? Colors.transparent : Colors.black,
                  ],
                  stops: [0.0, leftFadeStop, rightFadeStop, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                clipBehavior: Clip.hardEdge,
                controller: _episodeScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _currentSeasonEpisodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: _Space.md),
                itemBuilder: (context, index) {
                  final ep = _currentSeasonEpisodes[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _EpisodeCard(
                      episode: ep,
                      fallbackImageUrl:
                          _detail?.background ??
                          _detail?.poster ??
                          widget.movie.poster,
                      onTap: () => _handlePlayAction(ep),
                      isCollection: _isCollection,
                    ),
                  );
                },
              ),
            ),
            if (isDesktop) ...[
              if (_canScrollEpisodesLeft)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: fadeWidth + 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          _Palette.bg,
                          _Palette.bg.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _buildScrollArrow(
                        Icons.arrow_back_ios_new_rounded,
                        () => _scrollList(_episodeScrollController, -1),
                        _isHoveringEpisodes,
                      ),
                    ),
                  ),
                ),
              if (_canScrollEpisodesRight)
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: fadeWidth + 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerEnd,
                        end: AlignmentDirectional.centerStart,
                        colors: [
                          _Palette.bg,
                          _Palette.bg.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _buildScrollArrow(
                        Icons.arrow_forward_ios_rounded,
                        () => _scrollList(_episodeScrollController, 1),
                        _isHoveringEpisodes,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // "More Like This" — fills the dead space at the bottom of the page and
  // gives people somewhere to go next instead of hitting a wall of black.
  Widget _buildRelatedRow(List<Movie> related) {
    final isDesktop = _isDesktop();
    final cardWidth = isDesktop ? 150.0 : 120.0;
    final fadeWidth = isDesktop ? 60.0 : 40.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringRelated = true),
      onExit: (_) => setState(() => _isHoveringRelated = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailsSectionHeader(context.l10n.detailsMoreLikeThis),
          SizedBox(
            height: cardWidth * 1.5 + 8,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    final leftFadeStop = bounds.width > 0
                        ? (fadeWidth / bounds.width).clamp(0.01, 0.2)
                        : 0.05;
                    final rightFadeStop = bounds.width > 0
                        ? (1.0 - (fadeWidth / bounds.width)).clamp(0.8, 0.99)
                        : 0.95;

                    return LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        _canScrollRelatedLeft
                            ? Colors.transparent
                            : Colors.black,
                        Colors.black,
                        Colors.black,
                        _canScrollRelatedRight
                            ? Colors.transparent
                            : Colors.black,
                      ],
                      stops: [0.0, leftFadeStop, rightFadeStop, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    clipBehavior: Clip.hardEdge,
                    controller: _relatedScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: related.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _Space.md),
                    itemBuilder: (context, index) {
                      final item = related[index];
                      return SizedBox(
                        width: cardWidth,
                        child: HoverButton(
                          onTap: () {
                            pushReplacementPage(
                              context,
                              DetailsPage(movie: item),
                            );
                          },
                          scaleAmount: 1.05,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: item.poster != null
                                  ? CachedNetworkImage(
                                      imageUrl: item.poster!,
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(color: _Palette.surface),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isDesktop) ...[
                  if (_canScrollRelatedLeft)
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: fadeWidth + 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [
                              _Palette.bg,
                              _Palette.bg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildScrollArrow(
                            Icons.arrow_back_ios_new_rounded,
                            () => _scrollList(_relatedScrollController, -1),
                            _isHoveringRelated,
                          ),
                        ),
                      ),
                    ),
                  if (_canScrollRelatedRight)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: fadeWidth + 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerEnd,
                            end: AlignmentDirectional.centerStart,
                            colors: [
                              _Palette.bg,
                              _Palette.bg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _buildScrollArrow(
                            Icons.arrow_forward_ios_rounded,
                            () => _scrollList(_relatedScrollController, 1),
                            _isHoveringRelated,
                          ),
                        ),
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

  Widget _buildSimilarRow() {
    final isDesktop = _isDesktop();
    final cardWidth = isDesktop ? 160.0 : 130.0;
    final cardHeight = SimilarCard.heightFor(cardWidth);
    final fadeWidth = isDesktop ? 60.0 : 40.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringSimilar = true),
      onExit: (_) => setState(() => _isHoveringSimilar = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailsSectionHeader(context.l10n.detailsSimilarContent),
          SizedBox(
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    final leftFadeStop = bounds.width > 0
                        ? (fadeWidth / bounds.width).clamp(0.01, 0.2)
                        : 0.05;
                    final rightFadeStop = bounds.width > 0
                        ? (1.0 - (fadeWidth / bounds.width)).clamp(0.8, 0.99)
                        : 0.95;

                    return LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        _canScrollSimilarLeft
                            ? Colors.transparent
                            : Colors.black,
                        Colors.black,
                        Colors.black,
                        _canScrollSimilarRight
                            ? Colors.transparent
                            : Colors.black,
                      ],
                      stops: [0.0, leftFadeStop, rightFadeStop, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    clipBehavior: Clip.hardEdge,
                    controller: _similarScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _similarItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _Space.md),
                    itemBuilder: (context, index) {
                      final item = _similarItems[index];
                      return SimilarCard(
                        item: item,
                        width: cardWidth,
                        onTap: () => _openSimilarItem(item),
                      );
                    },
                  ),
                ),
                if (isDesktop) ...[
                  if (_canScrollSimilarLeft)
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 60,
                      child: Container(
                        width: fadeWidth + 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [
                              _Palette.bg,
                              _Palette.bg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildScrollArrow(
                            Icons.arrow_back_ios_new_rounded,
                            () => _scrollList(_similarScrollController, -1),
                            _isHoveringSimilar,
                          ),
                        ),
                      ),
                    ),
                  if (_canScrollSimilarRight)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 60,
                      child: Container(
                        width: fadeWidth + 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerEnd,
                            end: AlignmentDirectional.centerStart,
                            colors: [
                              _Palette.bg,
                              _Palette.bg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _buildScrollArrow(
                            Icons.arrow_forward_ios_rounded,
                            () => _scrollList(_similarScrollController, 1),
                            _isHoveringSimilar,
                          ),
                        ),
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

  Widget _buildScrollArrow(IconData icon, VoidCallback onTap, bool isVisible) {
    // All five rails route through here, which is the only reason ten arrows
    // could be labelled and turned around in one place. They are built from
    // `HoverButton`, which takes its icon as a `child` -- so the icon is not
    // lexically inside the gesture detector, and the scan that found the other
    // unlabelled controls could not see these at all (#69).
    final arrow = Center(
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !isVisible,
          child: HoverButton(
            onTap: onTap,
            scaleAmount: 1.1,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink.withOpacity(0.2)),
                  ),
                  child: Icon(
                    readingOrderArrow(context, icon),
                    color: AppColors.ink,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ArrowTooltip(icon: icon, child: arrow);
  }
}

/// One credited person, flattened from either a [CastMember] or a
/// [CrewMember] so the credits row has a single card shape to render.
class _EpisodeCard extends StatefulWidget {
  final Video episode;
  final String? fallbackImageUrl;
  final VoidCallback? onTap;
  final bool isCollection;

  const _EpisodeCard({
    required this.episode,
    this.fallbackImageUrl,
    this.onTap,
    this.isCollection = false,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final ep = widget.episode;
    final imgUrl = ep.thumbnail ?? widget.fallbackImageUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () {},
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: _Palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? AppColors.ink.withOpacity(0.22)
                    : AppColors.ink.withOpacity(0.04),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imgUrl != null)
                          CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const ColoredBox(color: Color(0xFF1B1E27)),
                          )
                        else
                          const ColoredBox(color: Color(0xFF1B1E27)),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        Center(
                          child: AnimatedOpacity(
                            opacity: _hovered ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(_Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.isCollection ? 'PART ${ep.episode ?? "?"}' : 'EP ${ep.episode ?? "?"}',
                              style: const TextStyle(
                                color: _Palette.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            if (ep.released != null && ep.released!.length >= 4)
                              Text(
                                widget.isCollection
                                    ? ep.released!.substring(0, 4)
                                    : (ep.released!.length >= 10 ? ep.released!.substring(0, 10) : ep.released!),
                                style: TextStyle(
                                  color: AppColors.inkDisabled,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ep.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        if (ep.overview != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            ep.overview!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.inkSubtle,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
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

