import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../services/theme/app_theme_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/iptv/iptv_hero_carousel.dart';
import '../../widgets/iptv/iptv_slider_section.dart';
import 'iptv_channel_sheet.dart';
import 'iptv_multiview_page.dart';
import 'iptv_player_page.dart';
import 'iptv_portals_modal.dart';
import 'iptv_search_page.dart';
import '../../services/app_breakpoints.dart';

class IptvPage extends StatefulWidget {
  const IptvPage({super.key});

  @override
  State<IptvPage> createState() => _IptvPageState();
}

class _IptvPageState extends State<IptvPage> {
  final IptvController _ctrl = IptvController.instance;
  final ScrollController _scrollController = ScrollController();

  List<HardcodedChannel> _featured = [];
  List<HardcodedChannel> _espnAndCollege = [];
  List<HardcodedChannel> _usSports = [];
  List<HardcodedChannel> _soccer = [];
  List<HardcodedChannel> _combat = [];
  List<HardcodedChannel> _racing = [];
  List<HardcodedChannel> _movies = [];
  List<HardcodedChannel> _news = [];
  List<HardcodedChannel> _arabic = [];
  List<HardcodedChannel> _discovery = [];
  List<HardcodedChannel> _kids = [];

  @override
  void initState() {
    super.initState();
    DiscordRpcService.instance.setWatchingLiveTv(channelName: 'Live TV');
    IptvSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
    _ctrl.init();
    _loadSections();
  }

  @override
  void dispose() {
    IptvSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    _scrollController.dispose();
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _loadSections() {
    _featured = [
      HardcodedChannels.byId('espn_plus') ?? HardcodedChannels.byId('espn')!,
      HardcodedChannels.byId('ncaa_cbb') ?? HardcodedChannels.byId('espn')!,
      HardcodedChannels.byId('ufc')!,
      HardcodedChannels.byId('bein_sports')!,
      HardcodedChannels.byId('champions_league')!,
      HardcodedChannels.byId('f1')!,
      HardcodedChannels.byId('nba')!,
      HardcodedChannels.byId('hbo')!,
    ];
    _espnAndCollege = [
      HardcodedChannels.byId('espn_plus')!,
      HardcodedChannels.byId('espn')!,
      HardcodedChannels.byId('espn2')!,
      HardcodedChannels.byId('espnu')!,
      HardcodedChannels.byId('ncaa_cbb')!,
      HardcodedChannels.byId('ncaa_mens_cbb')!,
      HardcodedChannels.byId('ncaa_womens_cbb')!,
      HardcodedChannels.byId('sec_network')!,
      HardcodedChannels.byId('acc_network')!,
      HardcodedChannels.byId('big_ten_network')!,
      HardcodedChannels.byId('pac_12_network')!,
      HardcodedChannels.byId('espnews')!,
      HardcodedChannels.byId('espn_deportes')!,
      HardcodedChannels.byId('longhorn_network')!,
      HardcodedChannels.byId('bally_sports')!,
    ];
    _usSports = [
      HardcodedChannels.byId('nba')!,
      HardcodedChannels.byId('nfl')!,
      HardcodedChannels.byId('nfl_redzone')!,
      HardcodedChannels.byId('mlb')!,
      HardcodedChannels.byId('nhl')!,
      HardcodedChannels.byId('fox_sports')!,
      HardcodedChannels.byId('cbs_sports')!,
      HardcodedChannels.byId('nbc_sports')!,
      HardcodedChannels.byId('dazn')!,
      HardcodedChannels.byId('eurosport')!,
    ];
    _soccer = HardcodedChannels.byCategory('Soccer');
    _combat = HardcodedChannels.byCategory('Combat');
    _racing = HardcodedChannels.byCategory('Racing');
    _movies = HardcodedChannels.byCategory('Movies');
    _news = HardcodedChannels.byCategory('News');
    _arabic = HardcodedChannels.byCategory('Arabic');
    _discovery = HardcodedChannels.byCategory('Discovery');
    _kids = HardcodedChannels.byCategory('Kids');
  }

  void _openChannel(HardcodedChannel channel) {
    IptvChannelSheet.show(context, channel);
  }

  void _watchChannelNow(HardcodedChannel channel) async {
    // If we have saved hits, launch immediately, otherwise open sheet to scan
    final results = _ctrl.channelResults;
    if (_ctrl.activeHardcoded?.id == channel.id && results.isNotEmpty) {
      Navigator.push(
        context,
        LiquidRevealRoute(
          page: IptvPlayerPage(
            channel: channel,
            hits: results,
            initialHitIndex: 0,
          ),
          tapPosition: null,
        ),
      );
    } else {
      IptvChannelSheet.show(context, channel);
    }
  }

  void _navigateToSearch(Offset? tapPosition) {
    Navigator.push(
      context,
      LiquidRevealRoute(page: const IptvSearchPage(), tapPosition: tapPosition),
    );
  }

  void _navigateToMultiView() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IptvMultiViewPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final palette = AppThemeService.currentPalette.value;
    final spotlightEnabled = IptvSettings.enableSpotlight.value;
    final visibleCategories = IptvSettings.visibleCategories.value;

    final Map<String, (String, List<HardcodedChannel>)> categoryMap = {
      'Premier Live Broadcasts': (
        'Top worldwide sporting events and championship channels',
        _featured,
      ),
      'ESPN & College Basketball (NCAA)': (
        'ESPN+, ESPN, ESPN2, ESPNU, NCAA Men\'s & Women\'s CBB, SEC & ACC',
        _espnAndCollege,
      ),
      'US Major Leagues & Sports': (
        'NBA TV, NFL Network, RedZone, MLB, NHL, Fox Sports & CBS Sports',
        _usSports,
      ),
      'Global Football & Soccer': (
        'UEFA Champions League, Premier League, beIN Sports, La Liga & Serie A',
        _soccer,
      ),
      'Combat & Martial Arts': (
        'UFC Fight Pass, WWE, AEW, World Boxing & PPV',
        _combat,
      ),
      'Motorsport & Racing': (
        'Formula 1, MotoGP, NASCAR Cup, IndyCar & Rally WRC',
        _racing,
      ),
      'Movies & Premium Networks': (
        'HBO, Showtime, Starz, Cinemax, Paramount & AMC',
        _movies,
      ),
      '24/7 Global News Networks': (
        'CNN, BBC World, Fox News, Sky News, Al Jazeera & Bloomberg',
        _news,
      ),
      'Arabic & Regional Hub': (
        'MBC, Rotana, OSN, Abu Dhabi TV, Dubai TV & Al Arabiya',
        _arabic,
      ),
      'Discovery & Documentaries': (
        'National Geographic, Discovery Channel, History & Animal Planet',
        _discovery,
      ),
      'Kids & Family': (
        'Cartoon Network, Disney Channel, Nickelodeon & Spacetoon',
        _kids,
      ),
    };

    final listContent = RefreshIndicator(
      color: palette.primaryColor,
      backgroundColor: palette.cardBackgroundColor,
      onRefresh: () async {
        _ctrl.scrape();
      },
      child: ListView(
        controller: _scrollController,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          // 1. Full Bleed Spotlight Hero Carousel
          if (spotlightEnabled)
            IptvHeroCarousel(
              channels: _featured,
              onWatchNow: _watchChannelNow,
              onSourcesTap: _openChannel,
            )
          else
            SizedBox(height: topPadding + 76),

          const SizedBox(height: 20),

          // 2. Curated Slider Sections (driven by user-customized category visibility and order)
          for (final catName in visibleCategories)
            if (categoryMap.containsKey(catName) && categoryMap[catName]!.$2.isNotEmpty)
              IptvSliderSection(
                title: catName,
                subtitle: categoryMap[catName]!.$1,
                channels: categoryMap[catName]!.$2,
                onChannelTap: _openChannel,
              ),

          const SizedBox(height: 90),
        ],
      ),
    );

    final backgroundContent = Container(
      color: palette.scaffoldBackgroundColor,
      child: listContent,
    );

    final overlayChildren = <Widget>[
      // Floating Glass App Bar (Home & Anime Page Style)
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _IptvGlassAppBar(
          topPadding: topPadding,
          onSearchTap: _navigateToSearch,
          onSourcesTap: () => IptvPortalsModal.show(context),
          onMultiViewTap: _navigateToMultiView,
        ),
      ),

      // Custom Scroll Track (Matching Home & Anime Page)
      if (AppBreakpoints.of(context) == ScreenTier.desktop)
        Positioned(
          right: 24,
          bottom: 40,
          child: CustomScrollTrack(controller: _scrollController),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: ValueListenableBuilder<bool>(
        valueListenable: GlassSettings.enabled,
        builder: (context, enabled, _) {
          final overlays = Stack(children: overlayChildren);
          if (enabled) {
            return LiquidGlassView(
              realTimeCapture: true,
              useSync: true,
              pixelRatio: 0.85,
              refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
              regionCapture: true,
              backgroundWidget: backgroundContent,
              child: overlays,
            );
          }

          return Container(
            color: const Color(0xFF080A0F),
            child: Stack(
              children: [
                RepaintBoundary(child: backgroundContent),
                ...overlayChildren,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IptvGlassAppBar extends StatelessWidget {
  final double topPadding;
  final Function(Offset? tapPosition) onSearchTap;
  final VoidCallback onSourcesTap;
  final VoidCallback onMultiViewTap;

  const _IptvGlassAppBar({
    required this.topPadding,
    required this.onSearchTap,
    required this.onSourcesTap,
    required this.onMultiViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(28, topPadding + 14, 28, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC080A0F),
            Color(0x77080A0F),
            Colors.transparent,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Row(
        children: [
          // Logo & Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFF), Color(0xFF00D2EF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.live_tv_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'LIVE TV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '60+ CHANNELS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Sources / Xtream Panels button
          _GlassActionButton(
            icon: Icons.settings_input_antenna_rounded,
            tooltip: 'Manage Portals & Playlists',
            onTap: onSourcesTap,
          ),

          const SizedBox(width: 10),

          // Multi-view button
          _GlassActionButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Multi-View (watch several channels at once)',
            onTap: onMultiViewTap,
          ),

          const SizedBox(width: 10),

          // Search button
          _GlassActionButton(
            icon: Icons.search_rounded,
            tooltip: 'Search Channels',
            onTapWithPosition: onSearchTap,
          ),
        ],
      ),
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Function(Offset? position)? onTapWithPosition;

  const _GlassActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onTapWithPosition,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (details) {
            if (widget.onTapWithPosition != null) {
              widget.onTapWithPosition!(details.globalPosition);
            } else if (widget.onTap != null) {
              widget.onTap!();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFF7C5CFF).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
                        blurRadius: 10,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? Colors.white : Colors.white70,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
