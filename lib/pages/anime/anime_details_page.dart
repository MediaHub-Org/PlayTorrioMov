import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/titles/title_display.dart';
import '../../services/app_breakpoints.dart';
import '../../services/app_spacing.dart';
import '../../services/app_units.dart';
import '../../widgets/details/details_poster_fit.dart';
import '../../widgets/details/details_metrics.dart';
import '../../widgets/common/details_section_header.dart';
import '../../models/anime/anime_media.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/anime/extractors/anidb_extractor.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/tv_type.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/clamped_text_scale.dart';
import '../../l10n/l10n.dart';
import '../../widgets/common/genre_tag_row.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/library_actions_row.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/common/slider_arrow.dart';
import 'anime_stream_sheet.dart';

/// The keys that activate a focused [_HoverScale]. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that
/// inside a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

// This page's own sizes, in rem (the ones it shares with DetailsPage are in
// details_metrics.dart), read through `context.rem(_Dim.x)`.
abstract final class _Dim {
  static const castRail = 11.25;
  static const portraitWidth = 6.25;
  static const portraitHeight = 6.875;
  static const jumpWidth = 8.125;
  static const controlHeight = 2.125;
  static const epCardWidth = 10.0;
  // +1 over the 16:9 box's own share: room for the optional second line
  // (the streamed-in title, where AniList has one) below "EP N".
  static const epRailHeight = 9.5;
  static const cardDesktop = 10.3125;
  static const cardMobile = 8.4375;
  static const cardTextBudget = 4.25;
  static const relationShadowBlur = 1.125;
  static const relationDropBlur = 0.875;
  static const relationTagRadius = 0.25;
}

// Font sizes without an AppType step, as plain constants (see AppType).
const double _kTitleDesktop = 38;
const double _kTitleMobile = 26;
const double _kSynopsis = 14.5;
const double _kEpNumber = 13.5;
// Size of an episode's streamed-in title, where AniList has one -- same
// weight class as the series rail's own blurb line.
const double _kEpStreamTitle = 11.5;
const double _kTagFont = 9.5;

class _Palette {
  static Color get bg => AppThemeService.currentPalette.value.scaffoldBackgroundColor;
  static Color get surface => AppThemeService.currentPalette.value.cardBackgroundColor;
  static Color get accent => AppThemeService.currentPalette.value.primaryColor;
  static Color get accentDim => AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.7);
  static const gold = Color(0xFFFFC107);
}

class AnimeDetailsPage extends StatefulWidget {
  final AnimeMedia anime;

  const AnimeDetailsPage({
    super.key,
    required this.anime,
  });

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimeMedia _anime;
  bool _isSynopsisExpanded = false;

  int _selectedEpisodeBatch = 0; // 50 episodes per chunk
  int? _highlightedEpisode;
  List<AniDbEpisode>? _aniDbEpisodes;

  static const int _chunkSize = 50;

  final TextEditingController _jumpEpController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _castScrollController = ScrollController();
  final ScrollController _relationsScrollController = ScrollController();
  final ScrollController _recsScrollController = ScrollController();
  final ScrollController _epScrollController = ScrollController();

  bool _canScrollCastLeft = false;
  bool _canScrollCastRight = true;
  bool _isHoveringCast = false;

  bool _canScrollRelationsLeft = false;
  bool _canScrollRelationsRight = true;
  bool _isHoveringRelations = false;

  bool _canScrollRecsLeft = false;
  bool _canScrollRecsRight = true;
  bool _isHoveringRecs = false;

  bool _canScrollEpLeft = false;
  bool _canScrollEpRight = true;
  bool _isHoveringEp = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // ratio: a slide as a fraction of the widget's own size
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
    _loadDetails();
    _resolveAniDbEpisodes();

    _castScrollController.addListener(_updateCastScrollButtons);
    _relationsScrollController.addListener(_updateRelationsScrollButtons);
    _recsScrollController.addListener(_updateRecsScrollButtons);
    _epScrollController.addListener(_updateEpScrollButtons);
  }

  @override
  void dispose() {
    _animController.dispose();
    _jumpEpController.dispose();
    _castScrollController.dispose();
    _relationsScrollController.dispose();
    _recsScrollController.dispose();
    _epScrollController.dispose();
    super.dispose();
  }

  void _loadDetails() async {
    final full = await AnilistService.instance.fetchAnimeDetails(_anime.id);
    if (mounted) {
      setState(() {
        if (full != null) _anime = full;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateCastScrollButtons();
          _updateRelationsScrollButtons();
          _updateRecsScrollButtons();
          _updateEpScrollButtons();
        }
      });
    }
  }

  void _resolveAniDbEpisodes() async {
    try {
      final slug = await AniDbExtractor.instance.mapAnime(
        titleCandidates: [
          _anime.titleEnglish,
          _anime.titleRomaji,
          _anime.titleNative,
          _anime.titleUserPreferred,
        ].where((t) => t.isNotEmpty).toList(),
      );
      if (slug != null) {
        final episodes = await AniDbExtractor.instance.getEpisodes(slug);
        if (episodes != null && mounted) {
          setState(() => _aniDbEpisodes = episodes);
        }
      }
    } catch (_) {
      // AniDB titles are enrichment. The episode list is already on screen
      // from the metadata addon, so failing here leaves the page as it was.
    }
  }

  int get _computedTotalEpisodes {
    if (_aniDbEpisodes != null && _aniDbEpisodes!.isNotEmpty) {
      return _aniDbEpisodes!.length;
    }
    if (_anime.totalEpisodes > 0) return _anime.totalEpisodes;
    if (_anime.nextAiring != null && _anime.nextAiring!.episode > 1) {
      return _anime.nextAiring!.episode - 1;
    }
    if (_anime.format.toUpperCase() == 'MOVIE') return 1;
    return 24;
  }

  void _updateCastScrollButtons() {
    if (!_castScrollController.hasClients) return;
    final canLeft = _castScrollController.position.pixels > 0;
    final canRight = _castScrollController.position.pixels <
        _castScrollController.position.maxScrollExtent;
    if (_canScrollCastLeft != canLeft || _canScrollCastRight != canRight) {
      setState(() {
        _canScrollCastLeft = canLeft;
        _canScrollCastRight = canRight;
      });
    }
  }

  void _updateEpScrollButtons() {
    if (!_epScrollController.hasClients) return;
    final canLeft = _epScrollController.position.pixels > 0;
    final canRight = _epScrollController.position.pixels <
        _epScrollController.position.maxScrollExtent;
    if (_canScrollEpLeft != canLeft || _canScrollEpRight != canRight) {
      setState(() {
        _canScrollEpLeft = canLeft;
        _canScrollEpRight = canRight;
      });
    }
  }

  void _updateRelationsScrollButtons() {
    if (!_relationsScrollController.hasClients) return;
    final canLeft = _relationsScrollController.position.pixels > 0;
    final canRight = _relationsScrollController.position.pixels <
        _relationsScrollController.position.maxScrollExtent;
    if (_canScrollRelationsLeft != canLeft ||
        _canScrollRelationsRight != canRight) {
      setState(() {
        _canScrollRelationsLeft = canLeft;
        _canScrollRelationsRight = canRight;
      });
    }
  }

  void _updateRecsScrollButtons() {
    if (!_recsScrollController.hasClients) return;
    final canLeft = _recsScrollController.position.pixels > 0;
    final canRight = _recsScrollController.position.pixels <
        _recsScrollController.position.maxScrollExtent;
    if (_canScrollRecsLeft != canLeft || _canScrollRecsRight != canRight) {
      setState(() {
        _canScrollRecsLeft = canLeft;
        _canScrollRecsRight = canRight;
      });
    }
  }

  void _scrollList(ScrollController controller, double directionMultiplier) {
    if (!controller.hasClients) return;
    final viewportWidth = controller.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.7 * directionMultiplier;
    final target = (controller.position.pixels + scrollAmount)
        .clamp(0.0, controller.position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _playEpisode(int episodeNumber) {
    AnimeStreamSheet.show(
      context,
      anime: _anime,
      episodeNumber: episodeNumber,
      autoPlay: false,
      aniDbEpisodes: _aniDbEpisodes,
      totalEpisodes: _computedTotalEpisodes,
    );
  }

  void _jumpToEpisode(String value) {
    final ep = int.tryParse(value.trim());
    if (ep == null || ep <= 0) return;

    final totalEps = _computedTotalEpisodes;
    final targetEp = ep.clamp(1, totalEps);
    final targetBatch = ((targetEp - 1) / _chunkSize).floor();

    setState(() {
      _selectedEpisodeBatch = targetBatch;
      _highlightedEpisode = targetEp;
    });
    FocusScope.of(context).unfocus();
  }

  void _navigateToAnime(AnimeMedia target) {
    pushPage(context, AnimeDetailsPage(anime: target));
  }

  /// Width, not platform.
  ///
  /// Everything this gates is a layout measurement -- hero height, a 1440
  /// content cap, padding, 38px vs 26px titles, 165px vs 135px cards --
  /// and DetailsPage, the sibling page making those same calls, has always
  /// asked AppBreakpoints. Asking defaultTargetPlatform instead meant a
  /// macOS window dragged narrow (or any web viewport) kept desktop
  /// metrics while Movie Details next to it switched to mobile ones.
  bool _isDesktop() =>
      AppBreakpoints.of(context) == ScreenTier.desktop;

  @override
  Widget build(BuildContext context) {
    final bgUrl = _anime.backdropUrl;
    final posterUrl = _anime.coverUrl;
    final isDesktop = _isDesktop();
    final screenSize = MediaQuery.sizeOf(context);

    final contentMaxWidth =
        isDesktop ? context.rem(DetailsDim.contentMaxWidth) : double.infinity;
    // See details_page.dart's identical comment: sized to the floating back
    // button's own footprint rather than a fraction of the hero's height,
    // which read as an oversized empty band once the page went fullscreen.
    final topGap = AppSpacing.floatingTopInset(context) +
        context.rem(DetailsDim.backButton) +
        context.rem(DetailsSpace.md);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedAmbientBackground(
        child: Stack(
          children: [
            if (bgUrl.isNotEmpty) _buildBackdrop(bgUrl, screenSize),

          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? context.rem(DetailsSpace.xxl) : context.rem(DetailsSpace.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: topGap),
                            isDesktop
                                ? _buildDesktopLayout(posterUrl)
                                : _buildMobileLayout(posterUrl),
                            SizedBox(height: context.rem(DetailsSpace.xl)),

                            // Credits, in the spine's position -- before
                            // episodes, where Movies and Series put Cast &
                            // Crew. Characters & Voice Cast *is* the anime
                            // form of that block: a character-to-voice-actor
                            // list answers for anime what actor-to-character
                            // answers for film, so it replaces Cast & Crew
                            // rather than sitting beside it.
                            if (_anime.characters.isNotEmpty) ...[
                              _buildCharactersRow(),
                              // Tighter than the page's section rhythm: Cast
                              // and Staff read as one credits group, not two
                              // blocks that happen to follow each other.
                              SizedBox(height: context.rem(DetailsSpace.md)),
                            ],

                            // Director & Staff: anime's one section-specific
                            // block, and the reason it comes after credits
                            // rather than leading. It answers something
                            // Characters cannot -- who directed it, who
                            // scored it, which studio made it -- and has no
                            // other home on the page, which is why it is
                            // kept rather than folded in or dropped.
                            if (_anime.staff.isNotEmpty) ...[
                              _buildStaffRow(),
                              SizedBox(height: context.rem(DetailsSpace.xl)),
                            ],

                            // Episodes Section with 50-Chunking & Jump Input
                            _buildEpisodesSection(),
                            SizedBox(height: context.rem(DetailsSpace.xl)),

                            // Franchise & Relations Row
                            if (_anime.relations.isNotEmpty) ...[
                              _buildRelationsRow(),
                              SizedBox(height: context.rem(DetailsSpace.xl)),
                            ],

                            // You May Also Like / Recommendations Row
                            if (_anime.recommendations.isNotEmpty) ...[
                              _buildRecommendationsRow(),
                              SizedBox(height: context.rem(DetailsSpace.xl)),
                            ],

                            SizedBox(height: context.rem(DetailsSpace.xxl)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const FloatingBackButton(),
        ],
      ),
    ),
    );
  }

  // ─── Persistent Cinematic Backdrop ─────────────────────────────
  Widget _buildBackdrop(String bgUrl, Size screenSize) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: screenSize.height,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: bgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => ColoredBox(color: _Palette.surface),
            ),
            // Horizontal wash: darkens where the title sits
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_Palette.bg, const Color(0x991A1D26), Colors.transparent],
                  stops: const [0.0, 0.42, 0.82],
                ),
              ),
            ),
            // Slow bottom fade: resolves smoothly to solid background
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0x661A1D26), _Palette.bg],
                  stops: const [0.0, 0.62, 0.94],
                ),
              ),
            ),
            // Top contrast cap for back button
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                  stops: [0.0, 0.22],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Desktop 2-Column Layout ───────────────────────────────────
  Widget _buildDesktopLayout(String posterUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: context.rem(DetailsDim.desktopPoster),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (posterUrl.isNotEmpty)
                DetailsPosterFit(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.rem(DetailsDim.posterRadius)),
                      boxShadow: [
                        BoxShadow(
                          color: _Palette.accent.withValues(alpha: 0.22),
                          blurRadius: context.rem(DetailsDim.glowBlur),
                          spreadRadius: -context.rem(DetailsDim.glowSpread),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: context.rem(DetailsDim.posterShadowBlur),
                          offset: Offset(0, context.rem(DetailsDim.posterShadowLift)),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.rem(DetailsDim.posterRadius)),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              ColoredBox(color: _Palette.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: context.rem(DetailsSpace.lg)),
              _buildPlayButton(fullWidth: true),
              SizedBox(height: context.rem(DetailsSpace.sm)),
              _buildLibraryButton(),
            ],
          ),
        ),
        SizedBox(width: context.rem(DetailsSpace.xl)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(isDesktop: true),
              SizedBox(height: context.rem(DetailsSpace.md)),
              _buildMetadataRow(),
              if (_anime.description.isNotEmpty) ...[
                SizedBox(height: context.rem(DetailsSpace.lg)),
                _buildSynopsis(_anime.description),
              ],
              if (_anime.genres.isNotEmpty) ...[
                SizedBox(height: context.rem(DetailsSpace.lg)),
                _buildGenreChips(_anime.genres),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Mobile / Compact Single Column Layout ─────────────────────
  Widget _buildMobileLayout(String posterUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (posterUrl.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.accent.withValues(alpha: 0.20),
                      blurRadius: context.rem(DetailsDim.mobileGlowBlur),
                      spreadRadius: -context.rem(AppRem.xs),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: context.rem(AppRem.md),
                      offset: Offset(0, context.rem(AppRem.sm)),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    width: context.rem(DetailsDim.mobilePoster),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            SizedBox(width: context.rem(DetailsSpace.md)),
            Expanded(child: _buildTitle(isDesktop: false)),
          ],
        ),
        SizedBox(height: context.rem(DetailsSpace.lg)),
        _buildMetadataRow(),
        SizedBox(height: context.rem(DetailsSpace.lg)),
        // Stacked, matching Movies and Series: Play takes the line, the four
        // library actions split the one under it. Sharing a Row with Play left
        // no width for a fourth action.
        _buildPlayButton(fullWidth: true),
        SizedBox(height: context.rem(DetailsSpace.sm)),
        _buildLibraryButton(),
        if (_anime.description.isNotEmpty) ...[
          SizedBox(height: context.rem(DetailsSpace.lg)),
          _buildSynopsis(_anime.description),
        ],
        if (_anime.genres.isNotEmpty) ...[
          SizedBox(height: context.rem(DetailsSpace.md)),
          _buildGenreChips(_anime.genres),
        ],
      ],
    );
  }

  Widget _buildTitle({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          animeDisplayTitle(_anime),
          style: TextStyle(
            fontSize: isDesktop ? _kTitleDesktop : _kTitleMobile,
            fontWeight: FontWeight.w900,
            height: 1.12, // ratio: a line height, not a size
            letterSpacing: -0.8, // px: tracking, not a layout size
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: context.rem(AppRem.blurLg),
                offset: Offset(0, context.rem(AppRem.snug)),
              ),
            ],
          ),
        ),
        if (_anime.titleNative.isNotEmpty &&
            _anime.titleNative != animeDisplayTitle(_anime))
          Padding(
            padding: EdgeInsets.only(top: context.rem(AppRem.snug)),
            child: Text(
              _anime.titleNative,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: isDesktop ? AppType.body : AppType.caption,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataRow() {
    final List<Widget> items = [];

    if (_anime.seasonYear > 0) {
      items.add(
        Text(
          '${_anime.seasonYear}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppType.bodyMd,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_anime.formattedFormat.isNotEmpty) {
      items.add(
        Text(
          _anime.formattedFormat,
          style: const TextStyle(color: Colors.white70, fontSize: AppType.body),
        ),
      );
    }

    final totalEps = _computedTotalEpisodes;
    if (totalEps > 0) {
      items.add(
        Text(
          '$totalEps Ep${totalEps > 1 ? "s" : ""}',
          style: const TextStyle(color: Colors.white70, fontSize: AppType.body),
        ),
      );
    }

    if (_anime.averageScore > 0) {
      items.add(
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rem(DetailsDim.ratingPadX),
            vertical: context.rem(DetailsDim.ratingPadY),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(context.rem(DetailsDim.ratingRadius)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: _Palette.gold, size: context.rem(DetailsDim.ratingStar)),
              SizedBox(width: context.rem(AppRem.xs)),
              Text(
                _anime.formattedScore,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppType.caption,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_anime.studioName.isNotEmpty) {
      items.add(
        Text(
          _anime.studioName,
          style: const TextStyle(color: Colors.white70, fontSize: AppType.body),
        ),
      );
    }

    final List<Widget> spaced = [];
    for (int i = 0; i < items.length; i++) {
      spaced.add(items[i]);
      if (i < items.length - 1) {
        spaced.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rem(DetailsSpace.sm)),
            child: const Text('•', style: TextStyle(color: Colors.white30, fontSize: AppType.bodyLg)),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: context.rem(AppRem.snug),
      children: spaced,
    );
  }

  /// The furthest episode actually watched, from Continue Watching.
  ///
  /// Anime plays through the shared PlayerScreen, so its progress is saved
  /// under `anilist:<id>` in ContinueWatchingService along with everything
  /// else. This page used to ask AnimeLibraryService instead, whose
  /// `lastWatchedEpisode` no code path ever writes -- so Play always said
  /// "Play Ep 1" however far in you were, and the episode grid never marked
  /// anything watched.
  int? get _lastWatchedEpisode =>
      ContinueWatchingService.lastWatchedEpisodeFor('anilist:${_anime.id}');

  Widget _buildPlayButton({required bool fullWidth}) {
    final lastWatched = _lastWatchedEpisode;
    final resumeEp = lastWatched ?? 1;

    return _HoverScale(
      onTap: () => _playEpisode(resumeEp),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: context.rem(AppRem.controlX),
          vertical: context.rem(AppRem.controlY),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_Palette.accent, _Palette.accentDim],
          ),
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
          boxShadow: [
            BoxShadow(
              color: _Palette.accent.withValues(alpha: 0.35),
              blurRadius: context.rem(AppRem.md),
              offset: Offset(0, context.rem(AppRem.xs)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: context.rem(AppRem.iconLg)),
            SizedBox(width: context.rem(AppRem.snug)),
            // Flexible as well as the icon's fixed size: the label is the
            // only part that grows with text scale, and without this it takes
            // the line and paints past the button -- 174px at 3x.
            Flexible(
              child: Text(
                lastWatched != null && lastWatched > 0
                    ? context.l10n.detailsResumeEp(resumeEp)
                    : context.l10n.detailsPlayEp(1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppType.bodyMd,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3, // px: tracking, not a layout size
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The same Watchlist / Watched / Like row Movies and Series use.
  ///
  /// This replaced a `PopupMenuButton` over AniList's own vocabulary
  /// (Watching / Plan to Watch / Completed / Dropped) that wrote only to
  /// [AnimeLibraryService]. Two things were wrong with that: anime was the
  /// one section with a different set of library verbs, and because the
  /// Library page filters anime by `MyListItem.type == 'anime'`, nothing
  /// saved from here ever appeared under its Anime tab.
  ///
  /// [AnimeLibraryService] is still written through [_mirrorToAnimeLibrary]
  /// so its AniList-shaped list stays in step; playback progress comes from
  /// [ContinueWatchingService], which is where the player actually saves
  /// it.
  Widget _buildLibraryButton() {
    // Both layouts now give the row a line to itself -- the poster column on
    // desktop, under Play on mobile -- so it spreads across the width rather
    // than clustering and needing to be centered.
    return LibraryActionsRow(
      itemBuilder: _buildMyListItem,
      onChanged: _mirrorToAnimeLibrary,
      expanded: true,
    );
  }

  MyListItem _buildMyListItem() {
    return MyListItem(
      // AniList ids are their own namespace, so they cannot be passed off as
      // TMDB or IMDb ids. The title/year fallback in `uniqueKey` is what
      // identifies these, which is also what lets an anime saved here match
      // the same show saved from a Stremio catalog.
      title: _anime.titleUserPreferred.isNotEmpty
          ? _anime.titleUserPreferred
          : _anime.titleRomaji,
      year: _anime.seasonYear > 0 ? _anime.seasonYear : null,
      type: 'anime',
      poster: _anime.coverImageLarge.isNotEmpty
          ? _anime.coverImageLarge
          : _anime.coverImageExtraLarge,
      addedAt: DateTime.now(),
    );
  }

  /// Keeps [AnimeLibraryService] in step with the shared row, mapping the
  /// standard actions onto its statuses: Watchlist -> Plan to Watch,
  /// Watched -> Completed, neither -> the list status is cleared.
  ///
  /// Clearing goes through [AnimeLibraryService.clearListStatus] rather
  /// than `removeFromWatchlist`: that entry is also the only carrier of
  /// `lastWatchedEpisode`, so deleting it to clear a list status would take
  /// any stored progress with it.
  void _mirrorToAnimeLibrary(MyListItem? entry) {
    final library = AnimeLibraryService.instance;
    if (entry == null || (!entry.isWatchlist && !entry.isWatched)) {
      // Liked alone is not a watch status, so it must not resurrect one.
      library.clearListStatus(_anime.id);
    } else {
      library.setWatchlistStatus(
        _anime,
        entry.isWatched
            ? AnimeWatchStatus.completed
            : AnimeWatchStatus.planToWatch,
      );
    }
    if (mounted) setState(() {});
  }

  Widget _buildSynopsis(String description) {
    return HoverButton(
      scaleAmount: 1.02,
      showFocusRing: true,
      // A paragraph, not a pill: the default ring's 9999 radius would curve
      // around four lines of text.
      focusRingBorderRadius: context.rem(AppRem.radiusSm) + context.rem(AppRem.xxs),
      onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        firstChild: Text(
          description,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: _kSynopsis,
            height: 1.55, // ratio: a line height, not a size
          ),
        ),
        secondChild: Text(
          description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: _kSynopsis,
            height: 1.55, // ratio: a line height, not a size
          ),
        ),
        crossFadeState: _isSynopsisExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
      ),
    );
  }

  Widget _buildGenreChips(List<String> genres) {
    return GenreTagRow(genres: genres);
  }

  // ─── Characters & Voice Cast Row ───────────────────────────────
  Widget _buildCharactersRow() {
    final isDesktop = _isDesktop();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailsSectionHeader(context.l10n.detailsCharactersCast),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringCast = true),
          onExit: (_) => setState(() => _isHoveringCast = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: context.rem(_Dim.castRail),
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _castScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _anime.characters.length,
                  separatorBuilder: (_, __) => SizedBox(width: context.rem(DetailsSpace.md)),
                  itemBuilder: (context, index) {
                    final char = _anime.characters[index];
                    return SizedBox(
                      width: context.rem(_Dim.portraitWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HoverScale(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                              child: CachedNetworkImage(
                                imageUrl: char.imageLarge,
                                width: context.rem(_Dim.portraitWidth),
                                height: context.rem(_Dim.portraitHeight),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: context.rem(_Dim.portraitWidth),
                                  height: context.rem(_Dim.portraitHeight),
                                  color: _Palette.surface,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: context.rem(AppRem.snug)),
                          Text(
                            char.nameFull,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppType.caption,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            char.role,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: TvType.scale(AppType.micro),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
              if (isDesktop)
                RailEdgeArrows(
                  visible: _isHoveringCast,
                  canGoPrevious: _canScrollCastLeft,
                  canGoNext: _canScrollCastRight,
                  onPrevious: () => _scrollList(_castScrollController, -1),
                  onNext: () => _scrollList(_castScrollController, 1),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Director & Staff Row ───────────────────────────────────────
  Widget _buildStaffRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailsSectionHeader(context.l10n.detailsStaff),
        SizedBox(
          height: context.rem(_Dim.castRail),
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _anime.staff.length,
            separatorBuilder: (_, __) => SizedBox(width: context.rem(DetailsSpace.md)),
            itemBuilder: (context, index) {
              final member = _anime.staff[index];
              return SizedBox(
                width: context.rem(_Dim.portraitWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      child: CachedNetworkImage(
                        imageUrl: member.imageLarge,
                        width: context.rem(_Dim.portraitWidth),
                        height: context.rem(_Dim.portraitHeight),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: context.rem(_Dim.portraitWidth),
                          height: context.rem(_Dim.portraitHeight),
                          color: _Palette.surface,
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.rem(AppRem.snug)),
                    Text(
                      member.nameFull,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      member.role,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: TvType.scale(AppType.micro),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Episodes Section (50-Chunking, Jump Input, SUB/DUB) ────────
  Widget _buildEpisodesSection() {
    final totalEps = _computedTotalEpisodes;
    final totalBatches = (totalEps / _chunkSize).ceil().clamp(1, 9999);
    final currentBatchSafe = _selectedEpisodeBatch.clamp(0, totalBatches - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episodes Header & Controls
        Wrap(
          spacing: context.rem(AppRem.ms),
          runSpacing: context.rem(AppRem.pillGap),
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            DetailsSectionHeader(
              context.l10n.detailsEpisodes,
              trailing: Text(
                context.l10n.detailsTotalEpisodes(totalEps),
                style: const TextStyle(color: Colors.white54, fontSize: AppType.body),
              ),
            ),

            // The controls flow onto their own lines rather than clamping.
            // They sit in a Wrap already, so the box can genuinely grow --
            // which the roadmap says is the better answer than a cap. At 3x
            // the strip wanted 516px more than the 312 it had; capped to 1.3
            // it still wanted 179, because the jump input and the batch
            // dropdown are fixed-width boxes whose labels grow inside them.
            Wrap(
              spacing: context.rem(AppRem.ms),
              runSpacing: context.rem(AppRem.pillGap),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // No SUB/DUB switcher here: it set a flag nothing read (the
                // sheet was never told), while the sheet itself filters
                // sources by SUB/DUB with counts and badges per source.
                // Jump to Ep Input
                  Container(
                    width: context.rem(_Dim.jumpWidth),
                    height: context.rem(_Dim.controlHeight),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141724),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _jumpEpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _jumpToEpisode,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(color: Colors.white, fontSize: AppType.caption),
                      decoration: InputDecoration(
                        // Dense, and the suffix icon's own min tap target
                        // (48px by default) capped to the box: left as the
                        // default, both fought the fixed 34px height above --
                        // the hint sat high and the button's own invisible
                        // hit area forced the row taller than its border,
                        // which is the "looks off" a fixed-height box cannot
                        // hide.
                        isDense: true,
                        hintText: context.l10n.detailsJumpToEpisode,
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: AppType.tiny),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.sm),
                          vertical: context.rem(AppRem.pillGap),
                        ),
                        // Loose, not the usual tap-target minimum: a
                        // fixed-height box with a target that size would
                        // have to grow around it again.
                        suffixIconConstraints: BoxConstraints.tightFor(
                          width: context.rem(1.75),
                          height: context.rem(1.5),
                        ),
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: context.l10n.detailsGoToEpisode,
                          icon: Icon(
                            Icons.arrow_forward_rounded,
                            color: _Palette.accent,
                            size: context.rem(AppRem.iconXs),
                          ),
                          onPressed: () =>
                              _jumpToEpisode(_jumpEpController.text),
                        ),
                      ),
                    ),
                  ),

                  // 50-Chunk Dropdown
                  if (totalBatches > 1)
                    // A fixed-height control: the batch label grows with the
                    // scale but the box cannot, so it clamps. Wrapping the
                    // strip above fixed the row; this is the one box inside
                    // it that still had nowhere to go.
                    ClampedTextScale(
                      child: Container(
                        height: context.rem(_Dim.controlHeight),
                        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141724),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                          border: Border.all(
                            color: _Palette.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: DropdownButton<int>(
                          value: currentBatchSafe,
                          underline: const SizedBox.shrink(),
                          dropdownColor: const Color(0xFF141724),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppType.caption,
                            fontWeight: FontWeight.bold,
                          ),
                          icon: Icon(
                            Icons.expand_more_rounded,
                            color: _Palette.accent,
                            size: context.rem(AppRem.iconXs),
                          ),
                          items: List.generate(
                            totalBatches,
                            (idx) {
                              final start = idx * _chunkSize + 1;
                              final end = math.min((idx + 1) * _chunkSize, totalEps);
                              return DropdownMenuItem(
                                value: idx,
                                child: Text('$start – $end'),
                              );
                            },
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedEpisodeBatch = val);
                            }
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),

        SizedBox(height: context.rem(DetailsSpace.md)),

        // Episode rail: Series speaks in EP cards, so anime does too. There
        // is no title or thumbnail behind these -- an AniDb episode is a
        // number -- so the card is the number, in the same 16:9 box, hover
        // play and watched/current language as the series rail.
        _buildEpisodeRail(
          totalEps,
          currentBatchSafe * _chunkSize,
          math.min((currentBatchSafe + 1) * _chunkSize, totalEps),
          _lastWatchedEpisode,
        ),
      ],
    );
  }

  Widget _buildEpisodeRail(
    int total,
    int startIndex,
    int endIndex,
    int? lastWatchedEp,
  ) {
    final count = endIndex - startIndex;
    if (count <= 0) return const SizedBox.shrink();
    final isDesktop = _isDesktop();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringEp = true),
      onExit: (_) => setState(() => _isHoveringEp = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: context.rem(_Dim.epRailHeight),
            child: ListView.separated(
              clipBehavior: Clip.none,
              controller: _epScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, __) =>
                  SizedBox(width: context.rem(DetailsSpace.md)),
              itemBuilder: (context, index) {
                final epNum = startIndex + index + 1;
                return SizedBox(
                  width: context.rem(_Dim.epCardWidth),
                  child: _AnimeEpisodeCard(
                    epNum: epNum,
                    info: _anime.episodeInfo(epNum, seasonEpisodes: total),
                    isWatched:
                        lastWatchedEp != null && epNum <= lastWatchedEp,
                    isCurrent: lastWatchedEp == epNum,
                    isHighlighted: _highlightedEpisode == epNum,
                    onTap: () => _playEpisode(epNum),
                  ),
                );
              },
            ),
          ),

          // Desktop Floating Scroll Arrows, same as the credits rails above.
          if (isDesktop)
            RailEdgeArrows(
              visible: _isHoveringEp,
              canGoPrevious: _canScrollEpLeft,
              canGoNext: _canScrollEpRight,
              onPrevious: () => _scrollList(_epScrollController, -1),
              onNext: () => _scrollList(_epScrollController, 1),
            ),
        ],
      ),
    );
  }

  // ─── Franchise & Relations Row ─────────────────────────────────
  Widget _buildRelationsRow() {
    final isDesktop = _isDesktop();
    final cardWidth = context.rem(isDesktop ? _Dim.cardDesktop : _Dim.cardMobile);
    final cardHeight = cardWidth * 1.5 + context.rem(_Dim.cardTextBudget); // ratio: a 2:3 poster

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailsSectionHeader(context.l10n.detailsFranchiseRelations),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringRelations = true),
          onExit: (_) => setState(() => _isHoveringRelations = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _relationsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _anime.relations.length,
                  separatorBuilder: (_, __) => SizedBox(width: context.rem(DetailsSpace.md)),
                  itemBuilder: (context, index) {
                    final rel = _anime.relations[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _HoverScale(
                        onTap: () async {
                          final media = await AnilistService.instance
                              .fetchAnimeDetails(rel.id);
                          if (media != null && mounted) {
                            _navigateToAnime(media);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                                boxShadow: [
                                  BoxShadow(
                                    color: _Palette.accent.withValues(alpha: 0.15),
                                    blurRadius: context.rem(_Dim.relationShadowBlur),
                                    spreadRadius: -context.rem(AppRem.xs),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: context.rem(_Dim.relationDropBlur),
                                    offset: Offset(0, context.rem(AppRem.snug)),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: CachedNetworkImage(
                                    imageUrl: rel.coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: _Palette.surface,
                                      child: Icon(
                                        Icons.movie_creation_outlined,
                                        color: Colors.white24,
                                        size: context.rem(AppRem.xl),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.sm)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rem(AppRem.snug),
                                vertical: context.rem(AppRem.xxs),
                              ),
                              decoration: BoxDecoration(
                                color: _Palette.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(context.rem(_Dim.relationTagRadius)),
                              ),
                              child: Text(
                                rel.relationType.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: _Palette.accent,
                                  fontSize: TvType.scale(_kTagFont),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2, // px: tracking, not a layout size
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              rel.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppType.small,
                                fontWeight: FontWeight.w700,
                                height: 1.2, // ratio: a line height, not a size
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
              if (isDesktop)
                RailEdgeArrows(
                  visible: _isHoveringRelations,
                  canGoPrevious: _canScrollRelationsLeft,
                  canGoNext: _canScrollRelationsRight,
                  onPrevious: () => _scrollList(_relationsScrollController, -1),
                  onNext: () => _scrollList(_relationsScrollController, 1),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Recommendations Row ───────────────────────────────────────
  Widget _buildRecommendationsRow() {
    final isDesktop = _isDesktop();
    final cardWidth = context.rem(isDesktop ? _Dim.cardDesktop : _Dim.cardMobile);
    final cardHeight = cardWidth * 1.5 + context.rem(_Dim.cardTextBudget); // ratio: a 2:3 poster

    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(AppRem.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailsSectionHeader(context.l10n.detailsYouMayAlsoLike),
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringRecs = true),
            onExit: (_) => setState(() => _isHoveringRecs = false),
            child: SizedBox(
              height: cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    clipBehavior: Clip.none,
                    controller: _recsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _anime.recommendations.length,
                    separatorBuilder: (_, __) => SizedBox(width: context.rem(DetailsSpace.md)),
                    itemBuilder: (context, index) {
                      final rec = _anime.recommendations[index];
                      return SizedBox(
                        width: cardWidth,
                        child: _HoverScale(
                          onTap: () => _navigateToAnime(rec),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _Palette.accent.withValues(alpha: 0.15),
                                      blurRadius: context.rem(_Dim.relationShadowBlur),
                                      spreadRadius: -context.rem(AppRem.xs),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: context.rem(_Dim.relationDropBlur),
                                      offset: Offset(0, context.rem(AppRem.snug)),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: CachedNetworkImage(
                                      imageUrl: rec.coverUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: _Palette.surface,
                                        child: Icon(
                                          Icons.movie_creation_outlined,
                                          color: Colors.white24,
                                          size: context.rem(AppRem.xl),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: context.rem(AppRem.sm)),
                              Text(
                                animeDisplayTitle(rec),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppType.small,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25, // ratio: a line height, not a size
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (rec.formattedFormat.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: context.rem(AppRem.xxs)),
                                  child: Text(
                                    rec.formattedFormat,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: AppType.tiny,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
                  if (isDesktop)
                    RailEdgeArrows(
                      visible: _isHoveringRecs,
                      canGoPrevious: _canScrollRecsLeft,
                      canGoNext: _canScrollRecsRight,
                      onPrevious: () => _scrollList(_recsScrollController, -1),
                      onNext: () => _scrollList(_recsScrollController, 1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _HoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverScale({required this.child, this.onTap});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hover = false;
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final onTap = widget.onTap;
    if (onTap == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final hover = _hover || _focused;
    return Focus(
      canRequestFocus: widget.onTap != null,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scaleByDouble(
              hover ? 1.04 : 1.0,
              hover ? 1.04 : 1.0,
              1.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          child: widget.child,
        ),
      ),
      ),
    );
  }
}

/// One anime episode in the rail: the number in a 16:9 box, an "EP N" foot,
/// and the series rail's watched/current language. An AniDb episode is just
/// a number, so that box is the number by default -- but when AniList's
/// [info] has art and a name for it, the box shows that instead and a
/// second line carries the name, the way the series rail does with its own
/// TMDB stills.
class _AnimeEpisodeCard extends StatefulWidget {
  final int epNum;
  final AnimeStreamingEpisode? info;
  final bool isWatched;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _AnimeEpisodeCard({
    required this.epNum,
    this.info,
    required this.isWatched,
    required this.isCurrent,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_AnimeEpisodeCard> createState() => _AnimeEpisodeCardState();
}

class _AnimeEpisodeCardState extends State<_AnimeEpisodeCard> {
  bool _hovered = false;
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered || _focused;
    final numberColor = widget.isHighlighted
        ? const Color(0xFFEF4444)
        : widget.isCurrent
            ? _Palette.accent
            : (widget.isWatched ? Colors.white70 : Colors.white);
    final thumbnail = widget.info?.thumbnail;
    final hasArt = thumbnail != null && thumbnail.isNotEmpty;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: hovered ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9, // ratio: the series rail's box shape
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: widget.isHighlighted
                          ? const Color(0xFFEF4444).withValues(alpha: 0.30)
                          : widget.isCurrent
                              ? _Palette.accent.withValues(alpha: 0.35)
                              : (widget.isWatched
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFF141724)),
                      borderRadius:
                          BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      border: Border.all(
                        color: widget.isHighlighted
                            ? const Color(0xFFEF4444)
                            : widget.isCurrent
                                ? _Palette.accent
                                : (widget.isWatched
                                    ? Colors.white24
                                    : Colors.white.withValues(alpha: 0.08)),
                        width: (widget.isCurrent || widget.isHighlighted)
                            ? 1.5
                            : 1, // px: a border weight, not a layout size
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasArt)
                            CachedNetworkImage(
                              imageUrl: thumbnail,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          if (hasArt)
                            // Legible against any still, the way the series
                            // rail's own gradient is.
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xBF000000),
                                  ],
                                  stops: [0.4, 1.0],
                                ),
                              ),
                            ),
                          if (hasArt)
                            // A corner badge rather than the full-size digit
                            // once there is a still to show instead of it --
                            // the number still orients a viewer scanning a
                            // dozen cards, just without covering the art.
                            PositionedDirectional(
                              start: context.rem(AppRem.xs),
                              top: context.rem(AppRem.xs),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rem(AppRem.xs),
                                  vertical: context.rem(AppRem.xxs),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(
                                      context.rem(AppRem.radiusSm)),
                                ),
                                child: Text(
                                  '${widget.epNum}',
                                  style: TextStyle(
                                    color: numberColor,
                                    fontSize: AppType.tiny,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Text(
                                '${widget.epNum}',
                                style: TextStyle(
                                  color: numberColor,
                                  fontSize: _kEpNumber,
                                  fontWeight: (widget.isCurrent ||
                                          widget.isHighlighted)
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                          Center(
                            child: AnimatedOpacity(
                              opacity: hovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                padding: EdgeInsets.all(
                                    context.rem(AppRem.iconXs)),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: context.rem(AppRem.icon),
                                ),
                              ),
                            ),
                          ),
                          // Watched episodes read dimmed, the way the series
                          // rail dims its watched cards. The current one keeps
                          // its face: it is the resume point, not history.
                          if (widget.isWatched && !widget.isCurrent)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                Text(
                  'EP ${widget.epNum}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isCurrent
                        ? _Palette.accent
                        : (widget.isWatched
                            ? Colors.white38
                            : Colors.white),
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.info?.title.isNotEmpty ?? false) ...[
                  SizedBox(height: context.rem(AppRem.xxs)),
                  Text(
                    widget.info!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isWatched
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: _kEpStreamTitle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
