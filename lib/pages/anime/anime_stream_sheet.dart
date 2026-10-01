import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/titles/title_display.dart';
import '../../l10n/l10n.dart';
import '../../models/anime/anime_media.dart';
import '../../models/stream/stream_model.dart';
import '../../services/anime/anime_scraper_service.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../utils/navigation/adaptive_sheet.dart';
import '../../widgets/common/source_badges.dart';
import '../../widgets/common/hover_button.dart';
import '../../services/theme/app_theme_service.dart';
import '../player/player_screen.dart';

import '../../services/anime/extractors/anidb_extractor.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class AnimeStreamSheet extends StatefulWidget {
  final AnimeMedia anime;
  final int episodeNumber;
  final bool autoPlay;
  final List<AniDbEpisode>? aniDbEpisodes;
  final int? totalEpisodes;

  const AnimeStreamSheet({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.autoPlay = false,
    this.aniDbEpisodes,
    this.totalEpisodes,
  });

  /// The one entry point every "play this episode" action goes through, so
  /// the sheet-vs-full-screen-on-TV choice (see [showAdaptiveSheet]) lives
  /// in one place rather than being copied at each of its call sites.
  static Future<void> show(
    BuildContext context, {
    required AnimeMedia anime,
    required int episodeNumber,
    bool autoPlay = false,
    List<AniDbEpisode>? aniDbEpisodes,
    int? totalEpisodes,
  }) {
    return showAdaptiveSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimeStreamSheet(
        anime: anime,
        episodeNumber: episodeNumber,
        autoPlay: autoPlay,
        aniDbEpisodes: aniDbEpisodes,
        totalEpisodes: totalEpisodes,
      ),
    );
  }

  @override
  State<AnimeStreamSheet> createState() => _AnimeStreamSheetState();
}

/// Whether an anime source is a dub. Scrapers stamp the category into the
/// name (`MegaPlay • DUB`), so a word match is the whole signal -- kept in
/// one place because the sheet filters, counts and badges off it, and three
/// copies of a substring check is how they drift apart.
bool isDubSource(StreamSource s) {
  final haystack = '${s.name ?? ''} ${s.description ?? ''}'.toLowerCase();
  return haystack.contains('dub');
}

class _AnimeStreamSheetState extends State<AnimeStreamSheet> {
  final AnimeScraperService _scraper = AnimeScraperService.instance;

  final List<StreamSource> _allSources = [];
  String _selectedCategory = 'all'; // 'all', 'sub', 'dub'
  bool _isScraping = true;
  String? _error;
  StreamSubscription<StreamSource>? _streamSub;

  @override
  void initState() {
    super.initState();
    _startScraping();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _startScraping() {
    setState(() {
      _allSources.clear();
      _isScraping = true;
      _error = null;
    });

    _streamSub = _scraper
        .scrapeStreamsStream(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
    )
        .listen(
      (source) {
        if (mounted) {
          setState(() {
            _allSources.add(source);
          });

          if (widget.autoPlay && _allSources.length == 1) {
            _playSource(source);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isScraping = false;
            _error = e.toString();
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScraping = false;
            if (_allSources.isEmpty) {
              _error =
                  context.l10n.animeNoStreamsForEpisode(widget.episodeNumber);
            }
          });
        }
      },
    );
  }

  List<StreamSource> get _filteredSources {
    if (_selectedCategory == 'sub') {
      return _allSources.where((s) => !isDubSource(s)).toList();
    } else if (_selectedCategory == 'dub') {
      return _allSources.where(isDubSource).toList();
    }
    return _allSources;
  }

  void _playSource(StreamSource source) {
    final detail = AnimeScraperService.toMovieDetail(
      widget.anime,
      aniDbEpisodes: widget.aniDbEpisodes,
      customEpisodeCount: widget.totalEpisodes,
    );
    final video =
        AnimeScraperService.toVideo(widget.anime, widget.episodeNumber);

    // Close the sheet, then push onto the ROOT navigator: replacing the
    // root's top route tore down the hub underneath and made Back exit
    // the app.
    final playerTitle = context.l10n.playerTitleEpisode(
      animeDisplayTitle(widget.anime),
      widget.episodeNumber,
    );
    Navigator.pop(context);
    pushFullscreenPage(
      PlayerScreen(
        source: source,
        title: playerTitle,
        backdropUrl: widget.anime.backdropUrl,
        detail: detail,
        episode: video,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final filtered = _filteredSources;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.rem(AppRem.lg))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: context.rem(AppRem.ms), bottom: context.rem(AppRem.sm)),
            width: context.rem(2.5),
            height: context.rem(AppRem.xs),
            decoration: BoxDecoration(
              color: AppColors.inkFaint,
              borderRadius: BorderRadius.circular(context.rem(AppRem.xxs)),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rem(1.25), vertical: context.rem(0.625)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${animeDisplayTitle(widget.anime)} • Ep ${widget.episodeNumber}',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: AppType.bodyLg,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.rem(AppRem.xxs)),
                      Row(
                        children: [
                          if (_isScraping) ...[
                            SizedBox(
                              width: context.rem(AppRem.ms),
                              height: context.rem(AppRem.ms),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppThemeService.currentPalette.value.primaryColor,
                              ),
                            ),
                            SizedBox(width: context.rem(AppRem.sm)),
                            Text(
                              context.l10n.animeCascading,
                              style: TextStyle(
                                color: AppThemeService.currentPalette.value.primaryColor,
                                fontSize: AppType.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else
                            Text(
                              context.l10n.animeSourcesFound(
                                _allSources.length,
                              ),
                              style: TextStyle(
                                color: AppColors.inkSubtle,
                                fontSize: AppType.caption,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonClose,
                  icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Sub / Dub Category Filter Pills. Each names its count, and an
          // empty one is dimmed and inert rather than a tap that leads to
          // a "no sources" dead end -- most episodes ship no dub at all.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rem(1.25), vertical: context.rem(AppRem.xs)),
            child: Row(
              children: [
                _buildFilterChip('All (${_allSources.length})', 'all'),
                SizedBox(width: context.rem(AppRem.sm)),
                _buildFilterChip(
                  'Sub (${_allSources.where((s) => !isDubSource(s)).length})',
                  'sub',
                  enabled: _allSources.any((s) => !isDubSource(s)),
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                _buildFilterChip(
                  'Dub (${_allSources.where(isDubSource).length})',
                  'dub',
                  enabled: _allSources.any(isDubSource),
                ),
              ],
            ),
          ),

          SizedBox(height: context.rem(AppRem.snug)),
          Divider(color: AppColors.inkAlpha(0.10), height: 1), // px: a hairline, not a layout size

          // Stream list
          Flexible(
            child: _allSources.isEmpty && _isScraping
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: context.rem(2.5)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.accent),
                        SizedBox(height: context.rem(0.875)),
                        Text(
                          context.l10n.animeExtracting,
                          style: TextStyle(color: AppColors.inkMuted, fontSize: AppType.small),
                        ),
                      ],
                    ),
                  )
                : _allSources.isEmpty && _error != null
                    ? Padding(
                        padding: EdgeInsets.all(context.rem(1.75)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: context.rem(2.5),
                            ),
                            SizedBox(height: context.rem(0.625)),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: AppType.small,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.rem(0.875)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                              ),
                              onPressed: _startScraping,
                              child: Text(context.l10n.animeRetryScraping),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(context.rem(AppRem.xl)),
                            child: Text(
                              context.l10n.animeNoCategorySources(
                                _selectedCategory.toUpperCase(),
                              ),
                              style: TextStyle(
                                  color: AppColors.inkSubtle, fontSize: AppType.small),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.all(context.rem(AppRem.md)),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: context.rem(0.625)),
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              final isDub = isDubSource(s);

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _playSource(s),
                                  borderRadius: BorderRadius.circular(context.rem(0.875)),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.rem(AppRem.md),
                                      vertical: context.rem(AppRem.ms),
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.raised,
                                      borderRadius: BorderRadius.circular(context.rem(0.875)),
                                      border: Border.all(
                                        color:
                                            AppColors.inkAlpha(0.08),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(context.rem(AppRem.sm)),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(context.rem(AppRem.radiusPill)),
                                          ),
                                          child: Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: AppColors.accent,
                                            size: context.rem(AppRem.iconLg),
                                          ),
                                        ),
                                        SizedBox(width: context.rem(0.875)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.name ?? context.l10n.playerStreamSourceFallback,
                                                style: TextStyle(
                                                  color: AppColors.ink,
                                                  fontSize: AppType.body,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: context.rem(0.1875)),
                                              Text(
                                                s.description ?? s.addonName,
                                                style: TextStyle(
                                                  color: AppColors.inkSubtle,
                                                  fontSize: AppType.tiny,
                                                ),
                                              ),
                                              // Same seed badge the movie
                                              // and series picker shows, so
                                              // a torrent source reads the
                                              // same here. A direct link has
                                              // none, and then the gap above
                                              // it would be dead space.
                                              if (sourceDeliveryBadges(s)
                                                  .isNotEmpty) ...[
                                                SizedBox(height: context.rem(AppRem.snug)),
                                                Wrap(
                                                  spacing: context.rem(AppRem.snug),
                                                  runSpacing: context.rem(AppRem.xs),
                                                  children:
                                                      sourceDeliveryBadges(s),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.rem(AppRem.sm),
                                            vertical: context.rem(AppRem.xs),
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDub
                                                ? Colors.orange
                                                    .withValues(alpha: 0.2)
                                                : Colors.blue
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(context.rem(AppRem.snug)),
                                          ),
                                          child: Text(
                                            isDub ? 'DUB' : 'SUB',
                                            style: TextStyle(
                                              color: isDub
                                                  ? Colors.orangeAccent
                                                  : Colors.lightBlueAccent,
                                              fontSize: TvType.scale(AppType.micro),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
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
  }

  Widget _buildFilterChip(String label, String category, {bool enabled = true}) {
    final isSelected = _selectedCategory == category;
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;
    return IgnorePointer(
      ignoring: !enabled,
      child: ExcludeFocus(
        excluding: !enabled,
        child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: HoverButton(
          scaleAmount: 1.05,
          showFocusRing: true,
          focusRingBorderRadius: context.rem(AppRem.radiusLg) + context.rem(AppRem.xxs),
          onTap: () => setState(() => _selectedCategory = category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.snug)),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor
                  : AppColors.inkAlpha(0.08),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : AppColors.inkAlpha(0.12),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.ink : AppColors.inkMuted,
                fontSize: AppType.caption,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
