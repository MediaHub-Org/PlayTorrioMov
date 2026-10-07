import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';
import '../../models/stream/stream_model.dart';
import '../../services/stream/stream_service.dart';
import '../../services/stream/stream_bitrate_resolver.dart';
import '../../services/scraper/stream_scraper.dart';
import '../../services/anime/anime_scraper_service.dart';
import '../common/source_badges.dart';
import '../../services/tv_type.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// The keys that activate a focused source card. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that
/// inside a `const` set literal.
final _sourceCardActivators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

/// Glassmorphic Sources Side Panel for selecting episode stream sources,
/// with targeted scraping, episode caching, and error recovery banners.
class PlayerSourcesPanel extends StatefulWidget {
  final Video episode;
  final MovieDetail? detail;
  final String currentAddonName;
  final String? errorMessage;
  final List<StreamSource>? cachedSources;
  final Function(List<StreamSource> sources) onSourcesLoaded;
  final Function(StreamSource source, Video episode) onPlaySource;
  final VoidCallback onBackToEpisodes;
  final VoidCallback onClose;

  const PlayerSourcesPanel({
    super.key,
    required this.episode,
    this.detail,
    required this.currentAddonName,
    this.errorMessage,
    this.cachedSources,
    required this.onSourcesLoaded,
    required this.onPlaySource,
    required this.onBackToEpisodes,
    required this.onClose,
  });

  @override
  State<PlayerSourcesPanel> createState() => _PlayerSourcesPanelState();
}

class _PlayerSourcesPanelState extends State<PlayerSourcesPanel> {
  final List<StreamSource> _sources = [];
  bool _isLoading = false;
  StreamSubscription<StreamSource>? _streamSub;
  int? _hoveredIndex;
  int? _focusedIndex;

  /// Manifest-resolved bitrates for direct streams (url -> kbps), read
  /// from HLS masters the same way the watch screen's own cards do.
  final Map<String, int> _resolvedBitrates = {};
  final List<StreamSource> _bitrateProbeQueue = [];
  int _activeBitrateProbes = 0;
  static const int _maxConcurrentBitrateProbes = 4;

  @override
  void initState() {
    super.initState();

    if (widget.cachedSources != null && widget.cachedSources!.isNotEmpty) {
      _sources.addAll(widget.cachedSources!);
      _isLoading = false;
      _queueBitrateProbes(widget.cachedSources!);
    } else {
      _startScraping();
    }
  }

  void _startScraping() {
    setState(() {
      _sources.clear();
      _isLoading = true;
    });

    final detail = widget.detail;
    final ep = widget.episode;
    final type = detail?.type ?? 'tv';
    final id = ep.id.isNotEmpty
        ? ep.id
        : '${detail?.id ?? ""}:${ep.season ?? 1}:${ep.episode ?? 1}';
    final title = detail?.name ?? ep.title;
    final year = int.tryParse(detail?.year ?? '');
    final epNum = ep.episode ?? 1;

    _streamSub?.cancel();

    final isAnime = type == 'anime' ||
        id.startsWith('anilist:') ||
        (detail?.id.startsWith('anilist:') ?? false) ||
        widget.currentAddonName == 'MegaPlay' ||
        widget.currentAddonName == 'AniDB' ||
        widget.currentAddonName == 'WatchHentai' ||
        widget.currentAddonName == 'Hentaini';

    if (isAnime) {
      int? anilistId;
      if (detail?.id.startsWith('anilist:') == true) {
        anilistId = int.tryParse(detail!.id.replaceFirst('anilist:', ''));
      } else if (id.startsWith('anilist:')) {
        final parts = id.split(':');
        if (parts.length >= 2) {
          anilistId = int.tryParse(parts[1]);
        }
      }

      _streamSub = AnimeScraperService.instance
          .scrapeStreamsByDetails(
        title: title,
        anilistId: anilistId,
        episodeNumber: epNum,
      )
          .listen(
        (source) {
          if (!mounted) return;
          setState(() {
            final exists = _sources.any((s) =>
                (source.url != null && s.url == source.url) ||
                (s.name == source.name && s.title == source.title));
            if (!exists) {
              _sources.add(source);
              _queueBitrateProbes([source]);
            }
          });
        },
        onError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onDone: () {
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onSourcesLoaded(List.from(_sources));
          }
        },
      );
      return;
    }

    _streamSub = StreamService.fetchStreamsForTargetAddon(
      targetAddonName: widget.currentAddonName,
      type: type,
      id: id,
      title: title,
      year: year,
      season: ep.season,
      episode: ep.episode,
    ).listen(
      (source) {
        if (!mounted) return;
        setState(() {
          // Deduplicate by URL / infoHash / title
          final exists = _sources.any((s) =>
              (source.infoHash != null && s.infoHash == source.infoHash) ||
              (source.url != null && s.url == source.url) ||
              (s.name == source.name && s.title == source.title));
          if (!exists) {
            _sources.add(source);
            _queueBitrateProbes([source]);
          }
        });
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
      onDone: () {
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onSourcesLoaded(List.from(_sources));
        }
      },
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  /// Reads the top variant's BANDWIDTH off HLS master manifests, four at a
  /// time. Same rule as the watch screen's own cards
  /// ([StreamBitrateResolver.shouldProbe]): titles that state a bitrate and
  /// anything that is not a playlist-looking URL never reach the network.
  void _queueBitrateProbes(List<StreamSource> sources) {
    for (final s in sources) {
      if (!StreamBitrateResolver.shouldProbe(s)) continue;
      final url = s.url;
      if (url == null ||
          url.isEmpty ||
          _resolvedBitrates.containsKey(url)) {
        continue;
      }
      _bitrateProbeQueue.add(s);
    }
    _drainBitrateProbeQueue();
  }

  void _drainBitrateProbeQueue() {
    while (_activeBitrateProbes < _maxConcurrentBitrateProbes &&
        _bitrateProbeQueue.isNotEmpty) {
      final source = _bitrateProbeQueue.removeAt(0);
      _activeBitrateProbes++;
      StreamBitrateResolver.resolveKbps(source).then((kbps) {
        _activeBitrateProbes--;
        if (kbps != null && mounted) {
          setState(() => _resolvedBitrates[source.url!] = kbps);
        }
        _drainBitrateProbeQueue();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    // A phone gets the whole screen, like YouTube's own settings pages. The
    // 94% drawer this replaced left a 6% sliver of video down one edge: too
    // little to watch, enough to make the panel read as covering the player
    // rather than replacing it.
    final drawerWidth = isCompact ? screenWidth : context.rem(27.5);
    final sNum = widget.episode.season ?? 1;
    final eNum = widget.episode.episode ?? 1;

    // See the note in player_episodes_panel: the drawer's edge line and shadow
    // sit on whichever face is towards the content.
    final towardsContent = Directionality.of(context) == TextDirection.rtl
        ? Offset(context.rem(AppRem.sm), 0)
        : Offset(-context.rem(AppRem.sm), 0);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xF2080C14),
          border: const BorderDirectional(
            start: BorderSide(color: Color(0x33FFFFFF), width: 1.2), // px: a hairline, not a layout size
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              offset: towardsContent,
              blurRadius: context.rem(2.25),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Bar ──
                _buildHeader(sNum, eNum, isCompact),

                // ── Error Notice Banner (if previous stream failed) ──
                if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty)
                  _buildErrorBanner(widget.errorMessage!, isCompact),

                const Divider(height: 1, color: Color(0x1AFFFFFF)), // px: a hairline, not a layout size

                // ── Sources List / Loading / Empty State ──
                Expanded(
                  child: _sources.isEmpty && _isLoading
                      ? _buildLoadingState()
                      : (_sources.isEmpty && !_isLoading
                          ? _buildEmptyState()
                          : _buildSourcesList(isCompact)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int sNum, int eNum, bool isCompact) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.paddingOf(context).top + context.rem(AppRem.ms),
        start: context.rem(isCompact ? AppRem.ms : AppRem.md),
        end: context.rem(isCompact ? AppRem.ms : AppRem.md),
        bottom: context.rem(AppRem.ms),
      ),
      color: const Color(0x66000000),
      child: Row(
        children: [
          // Back to Episodes Button
          PlayerIconButton(
            size: context.rem(2.25),
            iconSize: context.rem(1.25),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: context.l10n.playerBackToEpisodes,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            onPressed: widget.onBackToEpisodes,
          ),
          SizedBox(width: context.rem(0.625)),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Flexible + FittedBox: the badge is a fixed-width pill
                    // whose label grows with the text scale, and at 3x it
                    // alone wanted more than the row had. Scaling it down
                    // keeps the episode marker legible without pushing the
                    // title off the edge.
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
                        decoration: BoxDecoration(
                          color: PlayerTheme.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(context.rem(0.3125)),
                          border: Border.all(color: PlayerTheme.accent.withValues(alpha: 0.50)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'S$sNum : E$eNum',
                            style: const TextStyle(
                              color: Color(0xFF9D84FF),
                              fontSize: AppType.tiny,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.rem(AppRem.sm)),
                    Flexible(
                      child: Text(
                        widget.episode.title.isNotEmpty
                            ? widget.episode.title
                            : context.l10n.playerEpisodeN(eNum),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppType.bodyPlus,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rem(AppRem.xxs)),
                Text(
                  context.l10n.playerProviderName(widget.currentAddonName),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: AppType.tinyPlus,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Close Drawer Button
          PlayerIconButton(
            size: context.rem(2.25),
            iconSize: context.rem(1.125),
            icon: const Icon(Icons.close_rounded),
            tooltip: context.l10n.playerClose,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, bool isCompact) {
    return Container(
      margin: EdgeInsets.all(context.rem(isCompact ? 0.625 : 0.875)),
      padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.6875)),
      decoration: BoxDecoration(
        color: const Color(0x33EF4444),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
        border: Border.all(color: const Color(0x99EF4444), width: 1.2), // px: a hairline, not a layout size
        boxShadow: [
          BoxShadow(
            color: const Color(0x33EF4444),
            blurRadius: context.rem(AppRem.ms),
            offset: Offset(0, context.rem(AppRem.xxs)),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFFCA5A5), size: context.rem(AppRem.iconMd)),
          SizedBox(width: context.rem(0.625)),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.captionPlus,
                fontWeight: FontWeight.w600,
                height: 1.3, // ratio: a line height, not a size
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: context.rem(AppRem.xl),
            height: context.rem(AppRem.xl),
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              valueColor: AlwaysStoppedAnimation<Color>(PlayerTheme.accent),
            ),
          ),
          SizedBox(height: context.rem(AppRem.md)),
          Text(
            context.l10n.playerScrapingFrom(widget.currentAddonName),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: AppType.small,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rem(AppRem.lg)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.30), size: context.rem(3)),
            SizedBox(height: context.rem(AppRem.ms)),
            Text(
              context.l10n.playerNoStreams,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppType.bodyPlus,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.rem(AppRem.snug)),
            Text(
              context.l10n.playerNoStreamsHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: AppType.caption,
              ),
            ),
            SizedBox(height: context.rem(AppRem.md)),
            ElevatedButton.icon(
              onPressed: _startScraping,
              icon: Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconXs)),
              label: Text(context.l10n.playerRescrape),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlayerTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesList(bool isCompact) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.rem(isCompact ? AppRem.ms : AppRem.md),
        vertical: context.rem(0.875),
      ),
      itemCount: _sources.length + (_isLoading ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: context.rem(AppRem.sm)),
      itemBuilder: (context, index) {
        if (index == _sources.length && _isLoading) {
          return Container(
            padding: EdgeInsets.all(context.rem(AppRem.ms)),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: context.rem(0.875),
                  height: context.rem(0.875),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(PlayerTheme.accent),
                  ),
                ),
                SizedBox(width: context.rem(0.625)),
                Text(
                  context.l10n.playerScrapingMore,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: AppType.tinyPlus,
                  ),
                ),
              ],
            ),
          );
        }

        final source = _sources[index];
        // Focus reuses the hover styling below: a card taking focus should
        // look at least as reachable as one under a pointer.
        final isHovered = _hoveredIndex == index || _focusedIndex == index;

        return _buildSourceCard(source, index, isHovered, isCompact);
      },
    );
  }

  Widget _buildSourceCard(
    StreamSource source,
    int index,
    bool isHovered,
    bool isCompact,
  ) {
    // Scraper, quality and container only: the release name's facts already
    // read as badges, so the full string would repeat them as a paragraph.
    // The site comes from the registered roster (see
    // ScraperManager.providerDisplayName); the raw add-on name is a
    // delivery label most scrapers share.
    final title = (source.title == null && source.name == null)
        ? context.l10n.playerStreamSourceFallback
        : source.compactTitleFor(
            ScraperManager.instance.providerDisplayName(source),
          );
    // StreamSource.isMagnet, not a bare infoHash check: a magnet: URL
    // with no separate infoHash field is still a torrent, and the icon
    // has to agree with the P2P/HTTP badge next to it.
    final isTorrent = source.isMagnet;
    final resolution = _extractResolution(title);
    // Stated in the title, or probed from the HLS manifest in the
    // background when the source arrived (see [_queueBitrateProbes]).
    // Torrents show nothing here: this panel has no runtime to estimate
    // from, and a title-stated bitrate already surfaced above.
    final bitrateKbps =
        source.bitrateKbps ?? _resolvedBitrates[source.url];

    return Focus(
      onFocusChange: (focused) =>
          setState(() => _focusedIndex = focused ? index : null),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!_sourceCardActivators.contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        widget.onPlaySource(source, widget.episode);
        return KeyEventResult.handled;
      },
      child: FocusRing(
        visible: _focusedIndex == index,
        borderRadius: context.rem(0.875),
        child: MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onPlaySource(source, widget.episode),
        child: AnimatedScale(
          scale: isHovered ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0x331E2435) : const Color(0x1F121722),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
              border: Border.all(
                color: isHovered
                    ? PlayerTheme.accent.withValues(alpha: 0.80)
                    : Colors.white.withValues(alpha: 0.10),
                width: isHovered ? 1.4 : 1.0, // px: a hairline, not a layout size
              ),
              boxShadow: [
                if (isHovered)
                  BoxShadow(
                    color: PlayerTheme.accent.withValues(alpha: 0.25),
                    blurRadius: context.rem(0.875),
                    offset: Offset(0, context.rem(0.1875)),
                  ),
              ],
            ),
            padding: EdgeInsets.all(context.rem(isCompact ? 0.625 : AppRem.ms)),
            child: Row(
              children: [
                // Icon / Type Badge
                Container(
                  padding: EdgeInsets.all(context.rem(AppRem.sm)),
                  decoration: BoxDecoration(
                    color: isTorrent
                        ? const Color(0x33F59E0B)
                        : const Color(0x337C5CFF),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                  ),
                  child: Icon(
                    isTorrent ? Icons.cloud_download_rounded : Icons.play_arrow_rounded,
                    color: isTorrent ? const Color(0xFFFBBF24) : const Color(0xFF9D84FF),
                    size: context.rem(AppRem.iconSm),
                  ),
                ),
                SizedBox(width: context.rem(AppRem.ms)),

                // Source Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row (Resolution, Type, Provider). A Wrap, not
                      // a Row: the resolution pill and the delivery badges
                      // are all fixed-width, so at a large text scale they
                      // together exceed the row and there is nothing left to
                      // flex. The column has room to grow, so letting the
                      // badges flow onto a second line is the honest fix.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: context.rem(AppRem.snug),
                        runSpacing: context.rem(AppRem.xs),
                        children: [
                          if (resolution.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: context.rem(0.3125), vertical: context.rem(0.0938)),
                              decoration: BoxDecoration(
                                color: _getResolutionColor(resolution),
                                borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                              ),
                              child: Text(
                                resolution,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: TvType.scale(AppType.nanoPlus),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),

                          // Shared with every out-of-player source picker,
                          // so a source's delivery and seed health read the
                          // same wherever it is listed.
                          ...sourceDeliveryBadges(source),

                          // The probed or stated bitrate, in the panel's own
                          // pill shape rather than a shared badge: it is a
                          // measurement, not a category, and it sits beside
                          // the resolution it qualifies.
                          if (bitrateKbps != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: context.rem(0.3125), vertical: context.rem(0.0938)),
                              decoration: BoxDecoration(
                                color: PlayerTheme.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                                border: Border.all(color: PlayerTheme.accent.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                StreamSource.formatBitrate(bitrateKbps),
                                style: TextStyle(
                                  color: const Color(0xFF9D84FF),
                                  fontSize: TvType.scale(AppType.nanoPlus),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),

                          // The site behind the source, resolved through the
                          // registered roster -- never a bare file id or a
                          // shared delivery label.
                          Text(
                            ScraperManager.instance.providerDisplayName(source),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: AppType.tiny,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: context.rem(AppRem.xs)),

                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppType.captionPlus,
                          fontWeight: FontWeight.w600,
                          height: 1.25, // ratio: a line height, not a size
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: context.rem(AppRem.sm)),

                if (source.isMagnet && source.magnetUrl != null) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: source.magnetUrl!));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: context.rem(AppRem.iconSm)),
                                SizedBox(width: context.rem(AppRem.sm)),
                                Text(
                                  context.l10n.playerMagnetCopied,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppType.small,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF1A1D26),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(context.rem(0.4375)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: Colors.white70,
                          size: context.rem(AppRem.iconXs),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.rem(AppRem.snug)),
                ],

                // Play Button Icon
                Container(
                  padding: EdgeInsets.all(context.rem(0.4375)),
                  decoration: BoxDecoration(
                    color: (isHovered ? PlayerTheme.accent : Colors.white.withValues(alpha: 0.08)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: context.rem(AppRem.iconXs),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  String _extractResolution(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('4k') || lower.contains('2160p') || lower.contains('uhd')) return '4K';
    if (lower.contains('1080p') || lower.contains('fhd')) return '1080P';
    if (lower.contains('720p') || lower.contains('hd')) return '720P';
    if (lower.contains('480p') || lower.contains('sd')) return '480P';
    return '';
  }

  Color _getResolutionColor(String res) {
    switch (res) {
      case '4K':
        return const Color(0xFF8B5CF6);
      case '1080P':
        return const Color(0xFF10B981);
      case '720P':
        return const Color(0xFF3B82F6);
      default:
        return Colors.white.withValues(alpha: 0.20);
    }
  }
}
