import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_colors.dart';
import '../../models/movie/video.dart';
import '../../services/tv_type.dart';
import 'player_glass.dart';
import '../../services/app_units.dart';

/// The keys that activate a focused episode card. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that
/// inside a `const` set literal.
final _episodeCardActivators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

/// Ultra-responsive, glassmorphic Episodes Side Panel with season tabs,
/// auto-scroll to current episode, animated card expansion, and high FPS rendering.
class PlayerEpisodesPanel extends StatefulWidget {
  final List<Video> videos;
  final Video? currentEpisode;
  final Function(Video selectedEpisode) onEpisodeSelected;
  final VoidCallback onClose;

  const PlayerEpisodesPanel({
    super.key,
    required this.videos,
    this.currentEpisode,
    required this.onEpisodeSelected,
    required this.onClose,
  });

  @override
  State<PlayerEpisodesPanel> createState() => _PlayerEpisodesPanelState();
}

class _PlayerEpisodesPanelState extends State<PlayerEpisodesPanel> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();
  late int _selectedSeason;
  String? _selectedEpisodeId;
  int? _hoveredIndex;
  int? _focusedIndex;

  List<int> _seasons = [];
  Map<int, List<Video>> _seasonEpisodes = {};
  Map<int, String> _seasonLabels = {};

  @override
  void initState() {
    super.initState();
    _organizeSeasons();

    _selectedEpisodeId = widget.currentEpisode?.id;

    // Find the season/batch containing the current episode
    int initialSeason = _seasons.isNotEmpty ? _seasons.first : 1;
    if (widget.currentEpisode != null) {
      for (final entry in _seasonEpisodes.entries) {
        final hasEp = entry.value.any((v) =>
            v.id == widget.currentEpisode?.id ||
            (v.episode != null && v.episode == widget.currentEpisode?.episode));
        if (hasEp) {
          initialSeason = entry.key;
          break;
        }
      }
    }
    _selectedSeason = initialSeason;

    // Auto-scroll to currently playing episode and active season tab on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentEpisode(immediate: true);
      _scrollToActiveSeason(immediate: true);
    });
  }

  void _organizeSeasons() {
    final map = <int, List<Video>>{};
    final distinctSeasons = widget.videos.map((v) => v.season ?? 1).toSet();

    if (distinctSeasons.length > 1) {
      for (final video in widget.videos) {
        final s = video.season ?? 1;
        map.putIfAbsent(s, () => []).add(video);
      }
      final seasons = map.keys.toList()..sort();
      for (final s in seasons) {
        map[s]!.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
      }
      _seasons = seasons;
      _seasonEpisodes = map;
      // Season tabs take their label at build time, from the app's language;
      // only the episode-range batches below are labeled here.
      _seasonLabels = {};
    } else if (widget.videos.length > 50) {
      // Group single season with 50+ episodes into 50-episode tabs (e.g. 1-50, 51-100)
      const chunkSize = 50;
      final sortedVideos = List<Video>.from(widget.videos)
        ..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));

      final batchKeys = <int>[];
      final batchLabels = <int, String>{};

      for (int i = 0; i < sortedVideos.length; i += chunkSize) {
        final batchNum = (i ~/ chunkSize) + 1;
        final end = (i + chunkSize < sortedVideos.length) ? i + chunkSize : sortedVideos.length;
        final chunk = sortedVideos.sublist(i, end);
        final startEp = chunk.first.episode ?? (i + 1);
        final endEp = chunk.last.episode ?? end;

        map[batchNum] = chunk;
        batchKeys.add(batchNum);
        batchLabels[batchNum] = '$startEp - $endEp';
      }

      _seasons = batchKeys;
      _seasonEpisodes = map;
      _seasonLabels = batchLabels;
    } else {
      const s = 1;
      map[s] = List<Video>.from(widget.videos)
        ..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
      _seasons = [s];
      _seasonEpisodes = map;
      _seasonLabels = {};
    }
  }

  void _scrollToCurrentEpisode({bool immediate = false}) {
    if (!mounted || widget.currentEpisode == null) return;

    final currentList = _seasonEpisodes[_selectedSeason] ?? [];
    final idx = currentList.indexWhere((v) => v.id == widget.currentEpisode?.id);
    if (idx < 0) return;

    // Approximate card height: 110px compact, 180px expanded
    final targetOffset = (idx * 116.0).clamp(
      0.0,
      _scrollController.hasClients ? _scrollController.position.maxScrollExtent : 9999.0,
    );

    if (immediate) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(targetOffset);
      } else {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(targetOffset);
          }
        });
      }
    } else {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _scrollToActiveSeason({bool immediate = false}) {
    if (!mounted || _seasons.isEmpty) return;
    final idx = _seasons.indexOf(_selectedSeason);
    if (idx < 0) return;
    final targetOffset = (idx * 86.0).clamp(
      0.0,
      _seasonScrollController.hasClients ? _seasonScrollController.position.maxScrollExtent : 9999.0,
    );
    if (immediate) {
      if (_seasonScrollController.hasClients) {
        _seasonScrollController.jumpTo(targetOffset);
      } else {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted && _seasonScrollController.hasClients) {
            _seasonScrollController.jumpTo(targetOffset);
          }
        });
      }
    } else {
      if (_seasonScrollController.hasClients) {
        _seasonScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _selectSeason(int season) {
    if (_selectedSeason == season) return;
    setState(() {
      _selectedSeason = season;
      final episodesInSeason = _seasonEpisodes[season] ?? [];
      if (episodesInSeason.isNotEmpty) {
        _selectedEpisodeId = episodesInSeason.first.id;
      }
    });

    _scrollToActiveSeason();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _handleEpisodeTap(Video video) {
    if (_selectedEpisodeId == video.id) {
      // Second tap on the selected card -> open sources panel!
      widget.onEpisodeSelected(video);
    } else {
      // First tap -> select and smoothly expand card
      setState(() {
        _selectedEpisodeId = video.id;
      });
    }
  }

  void _scrollStep(bool down) {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.offset;
    final target = (current + (down ? 240.0 : -240.0)).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollSeason(bool right) {
    if (!_seasonScrollController.hasClients) return;
    final current = _seasonScrollController.offset;
    final target = (current + (right ? 140.0 : -140.0)).clamp(
      0.0,
      _seasonScrollController.position.maxScrollExtent,
    );
    _seasonScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _seasonScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    // A phone gets the whole screen, like YouTube's own settings pages. The
    // 94% drawer this replaced left a 6% sliver of video down one edge: too
    // little to watch, enough to make the panel read as covering the player
    // rather than replacing it.
    final drawerWidth = isCompact ? screenWidth : 440.0;
    final episodes = _seasonEpisodes[_selectedSeason] ?? [];

    // The drawer slides in from the trailing edge, so its edge line and its
    // shadow are on the leading face -- which is the left in English and the
    // right in Arabic. `BoxShadow.offset` has no directional form, so the sign
    // is read off the direction rather than written down (#68).
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
                _buildHeader(episodes.length, isCompact),

                // ── Season Tabs Row (if multi-season) ──
                if (_seasons.length > 1) _buildSeasonTabs(isCompact),

                const Divider(height: 1, color: Color(0x1AFFFFFF)), // px: a hairline, not a layout size

                // ── Scrollable Episodes List ──
                Expanded(
                  child: Stack(
                    children: [
                      ListView.separated(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(isCompact ? AppRem.ms : AppRem.md),
                          vertical: context.rem(0.875),
                        ),
                        itemCount: episodes.length,
                        separatorBuilder: (_, __) => SizedBox(height: context.rem(0.625)),
                        itemBuilder: (context, index) {
                          final video = episodes[index];
                          final isCurrentPlaying = widget.currentEpisode?.id == video.id ||
                              (widget.currentEpisode?.season == video.season &&
                                  widget.currentEpisode?.episode == video.episode);
                          final isSelected = _selectedEpisodeId == video.id;

                          return _buildEpisodeCard(
                            video: video,
                            index: index,
                            isCurrentPlaying: isCurrentPlaying,
                            isSelected: isSelected,
                            isCompact: isCompact,
                          );
                        },
                      ),

                      // Floating Quick Scroll Controls (Desktop / TV friendly)
                      if (!isCompact && episodes.length > 4) ...[
                        Positioned(
                          right: context.rem(AppRem.ms),
                          top: context.rem(AppRem.ms),
                          child: _buildScrollFloatingButton(
                            icon: Icons.keyboard_arrow_up_rounded,
                            tooltip: context.l10n.playerScrollUp,
                            onTap: () => _scrollStep(false),
                          ),
                        ),
                        Positioned(
                          right: context.rem(AppRem.ms),
                          bottom: context.rem(AppRem.ms),
                          child: _buildScrollFloatingButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: context.l10n.playerScrollDown,
                            onTap: () => _scrollStep(true),
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
    );
  }

  Widget _buildHeader(int episodeCount, bool isCompact) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        top: MediaQuery.paddingOf(context).top + context.rem(AppRem.ms),
        start: context.rem(isCompact ? 0.875 : 1.25),
        end: context.rem(isCompact ? 0.875 : 1.125),
        bottom: context.rem(AppRem.ms),
      ),
      color: const Color(0x66000000),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.rem(0.4375)),
            decoration: BoxDecoration(
              color: PlayerTheme.accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
              border: Border.all(
                color: PlayerTheme.accent.withValues(alpha: 0.40),
              ),
            ),
            child: Icon(
              Icons.video_library_rounded,
              color: const Color(0xFF9D84FF),
              size: context.rem(AppRem.icon),
            ),
          ),
          SizedBox(width: context.rem(AppRem.ms)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.detailsEpisodes,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppType.subhead,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '${_seasonLabels[_selectedSeason] ?? context.l10n.playerSeasonN(_selectedSeason)} • ${context.l10n.playerEpisodeCount(episodeCount)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildSeasonTabs(bool isCompact) {
    final showArrows = !isCompact && _seasons.length > 2;

    return Container(
      height: context.rem(3),
      padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.snug), horizontal: context.rem(AppRem.xs)),
      color: const Color(0x33000000),
      child: Row(
        children: [
          // Desktop Left Season Arrow
          if (showArrows)
            Padding(
              padding: EdgeInsetsDirectional.only(start: context.rem(AppRem.xs), end: context.rem(AppRem.xxs)),
              child: _buildSeasonArrowButton(
                icon: Icons.chevron_left_rounded,
                tooltip: context.l10n.playerPreviousSeasons,
                onTap: () => _scrollSeason(false),
              ),
            ),

          // Scrollable Season Tabs
          Expanded(
            child: ListView.separated(
              controller: _seasonScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: context.rem(isCompact ? AppRem.ms : AppRem.snug)),
              itemCount: _seasons.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rem(AppRem.sm)),
              itemBuilder: (context, index) {
                final season = _seasons[index];
                final isActive = season == _selectedSeason;
                final tabLabel = _seasonLabels[season] ?? context.l10n.playerSeasonN(season);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectSeason(season),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.snug)),
                      decoration: BoxDecoration(
                        color: isActive
                            ? PlayerTheme.accent.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                        border: Border.all(
                          color: isActive
                              ? PlayerTheme.accent.withValues(alpha: 0.80)
                              : Colors.white.withValues(alpha: 0.10),
                          width: 1.2, // px: a hairline, not a layout size
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: PlayerTheme.accent.withValues(alpha: 0.35),
                                  blurRadius: context.rem(0.625),
                                  offset: Offset(0, context.rem(AppRem.xxs)),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabLabel,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.70),
                          fontSize: AppType.captionPlus,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Desktop Right Season Arrow
          if (showArrows)
            Padding(
              padding: EdgeInsetsDirectional.only(start: context.rem(AppRem.xxs), end: context.rem(AppRem.xs)),
              child: _buildSeasonArrowButton(
                icon: Icons.chevron_right_rounded,
                tooltip: context.l10n.playerNextSeasons,
                onTap: () => _scrollSeason(true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
          child: Container(
            width: context.rem(1.75),
            height: context.rem(1.75),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1, // px: a hairline, not a layout size
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: context.rem(AppRem.icon),
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeCard({
    required Video video,
    required int index,
    required bool isCurrentPlaying,
    required bool isSelected,
    required bool isCompact,
  }) {
    final epNum = video.episode ?? (index + 1);
    final epTitle = video.title.isNotEmpty ? video.title : context.l10n.playerEpisodeN(epNum);
    final hasOverview = video.overview != null && video.overview!.trim().isNotEmpty;
    // Focus reuses the hover styling below: a card taking focus should look
    // at least as reachable as one under a pointer, not gain a second visual
    // language on top of it.
    final isHovered = _hoveredIndex == index || _focusedIndex == index;

    return Focus(
      onFocusChange: (focused) =>
          setState(() => _focusedIndex = focused ? index : null),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!_episodeCardActivators.contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        _handleEpisodeTap(video);
        return KeyEventResult.handled;
      },
      child: FocusRing(
        visible: _focusedIndex == index,
        borderRadius: context.rem(AppRem.radiusLg),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _handleEpisodeTap(video),
            child: AnimatedScale(
          scale: isSelected ? 1.0 : (isHovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF141926)
                  : (isHovered
                      ? const Color(0x331E2435)
                      : const Color(0x1F121722)),
              borderRadius: BorderRadius.circular(context.rem(0.875)),
              border: Border.all(
                color: isSelected
                    ? PlayerTheme.accent
                    : (isCurrentPlaying
                        ? const Color(0xFF10B981).withValues(alpha: 0.70)
                        : (isHovered
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.10))),
                width: isSelected ? 1.8 : 1.0, // px: a hairline, not a layout size
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: PlayerTheme.accent.withValues(alpha: 0.30),
                    blurRadius: context.rem(1.125),
                    offset: Offset(0, context.rem(AppRem.xs)),
                  )
                else if (isHovered)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.50),
                    blurRadius: context.rem(AppRem.ms),
                    offset: Offset(0, context.rem(0.1875)),
                  ),
              ],
            ),
            padding: EdgeInsets.all(context.rem(isCompact ? 0.625 : AppRem.ms)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Thumbnail + Episode Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      child: Container(
                        width: context.rem(isSelected ? 7.25 : (isCompact ? 5.75 : 6.5)),
                        height: context.rem(isSelected ? 4.25 : (isCompact ? 3.5 : 3.875)),
                        color: const Color(0xFF1A1F2C),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (video.thumbnail != null && video.thumbnail!.isNotEmpty)
                              Image.network(
                                video.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildThumbPlaceholder(epNum),
                              )
                            else
                              _buildThumbPlaceholder(epNum),

                            // Subtle dark gradient overlay
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Color(0x99000000)],
                                ),
                              ),
                            ),

                            // Episode Badge on Thumbnail
                            Positioned(
                              left: context.rem(0.3125),
                              bottom: context.rem(0.3125),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: context.rem(0.3125), vertical: context.rem(0.0938)),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                                ),
                                child: Text(
                                  context.l10n.playerEpShort(epNum),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: TvType.scale(AppType.micro),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),

                            // Center Play Icon Indicator
                            if (isSelected || isHovered)
                              Center(
                                child: Container(
                                  padding: EdgeInsets.all(context.rem(AppRem.snug)),
                                  decoration: BoxDecoration(
                                    color: (isSelected ? PlayerTheme.accent : Colors.black)
                                        .withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: context.rem(AppRem.iconXs),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: context.rem(AppRem.ms)),

                    // Episode Title & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // "NOW PLAYING" Badge
                              if (isCurrentPlaying) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
                                  margin: EdgeInsetsDirectional.only(end: context.rem(AppRem.snug)),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(context.rem(0.3125)),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.60),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: context.rem(AppRem.snug),
                                        height: context.rem(AppRem.snug),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: context.rem(AppRem.xs)),
                                      Text(
                                        context.l10n.playerPlaying.toUpperCase(),
                                        style: TextStyle(
                                          color: const Color(0xFF34D399),
                                          fontSize: TvType.scale(AppType.nanoPlus),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (video.released != null && video.released!.isNotEmpty) ...[
                                Text(
                                  video.released!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: AppType.tiny,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          SizedBox(height: context.rem(0.1875)),

                          // Episode Title
                          Text(
                            epTitle,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF9D84FF)
                                  : (isCurrentPlaying ? const Color(0xFF34D399) : Colors.white),
                              fontSize: isSelected ? AppType.bodyPlus : AppType.smallPlus,
                              fontWeight: isSelected || isCurrentPlaying
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: isSelected ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (!isSelected && hasOverview) ...[
                            SizedBox(height: context.rem(0.1875)),
                            Text(
                              video.overview!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: AppType.tinyPlus,
                                height: 1.25, // ratio: a line height, not a size
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Expanded Section for Selected Episode
                if (isSelected) ...[
                  SizedBox(height: context.rem(0.625)),
                  if (hasOverview) ...[
                    Text(
                      video.overview!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: AppType.caption,
                        height: 1.35, // ratio: a line height, not a size
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.rem(AppRem.ms)),
                  ],

                  // "SELECT SOURCE / PLAY" Action Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onEpisodeSelected(video),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      child: Container(
                        constraints: BoxConstraints(minHeight: context.rem(2.375)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accent, const Color(0xFF9D84FF)],
                          ),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: context.rem(0.625),
                              offset: Offset(0, context.rem(AppRem.xxs)),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: context.rem(AppRem.iconSm)),
                            SizedBox(width: context.rem(AppRem.sm)),
                            Text(
                              context.l10n.playerSelectSources,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppType.small,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildThumbPlaceholder(int epNum) {
    return Container(
      color: const Color(0xFF141926),
      alignment: Alignment.center,
      child: Icon(
        Icons.tv_rounded,
        color: Colors.white.withValues(alpha: 0.20),
        size: context.rem(1.625),
      ),
    );
  }

  Widget _buildScrollFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999), // px: a hairline, not a layout size
          child: Container(
            padding: EdgeInsets.all(context.rem(AppRem.snug)),
            decoration: BoxDecoration(
              color: const Color(0xD9080C14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: context.rem(AppRem.sm),
                  offset: Offset(0, context.rem(AppRem.xxs)),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: context.rem(AppRem.icon)),
          ),
        ),
      ),
    );
  }
}
