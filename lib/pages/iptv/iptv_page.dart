import 'package:flutter/material.dart';

import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/header_pill_style.dart';
import '../../widgets/common/page_search_button.dart';
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

    final pillHeader = _IptvGlassAppBar(
      onSearchTap: _navigateToSearch,
      onSourcesTap: () => IptvPortalsModal.show(context),
      onMultiViewTap: _navigateToMultiView,
    );
    // Nested inside the hero's own Stack (see IptvHeroCarousel) so it
    // scrolls away with the hero instead of staying pinned to the viewport;
    // with no hero to nest into, it renders inline instead.
    final heroWillRender = spotlightEnabled && _featured.isNotEmpty;

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
          if (heroWillRender)
            IptvHeroCarousel(
              channels: _featured,
              onWatchNow: _watchChannelNow,
              onSourcesTap: _openChannel,
              header: pillHeader,
            )
          else
            pillHeader,

          const SizedBox(height: 20),

          // 2. Curated Slider Sections (driven by user-customized category visibility and order)
          for (final catName in visibleCategories)
            if (categoryMap.containsKey(catName) &&
                categoryMap[catName]!.$2.isNotEmpty)
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
      body: Container(
        color: const Color(0xFF080A0F),
        child: Stack(
          children: [
            RepaintBoundary(child: backgroundContent),
            ...overlayChildren,
          ],
        ),
      ),
    );
  }
}

/// Live TV's own header pill row -- title, channel count, and the Sources/
/// Multi-view/Search actions all share [headerPillDecoration] with the
/// genre/decade/sort pills and [PageSearchButton] used everywhere else, so
/// this reads as the same design language instead of the bespoke gradient
/// "glass" look it used to have.
class _IptvGlassAppBar extends StatelessWidget {
  final Function(Offset? tapPosition) onSearchTap;
  final VoidCallback onSourcesTap;
  final VoidCallback onMultiViewTap;

  const _IptvGlassAppBar({
    required this.onSearchTap,
    required this.onSourcesTap,
    required this.onMultiViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: headerPillDecoration,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.live_tv_rounded,
                    color: Colors.white70,
                    size: headerPillIconSize,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LIVE TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: headerPillDecoration,
              child: const Text(
                '60+ CHANNELS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),

            const Spacer(),

            HeaderPillIconButton(
              icon: Icons.settings_input_antenna_rounded,
              tooltip: 'Manage Portals & Playlists',
              onTap: onSourcesTap,
            ),
            const SizedBox(width: 8),
            HeaderPillIconButton(
              icon: Icons.grid_view_rounded,
              tooltip: 'Multi-View (watch several channels at once)',
              onTap: onMultiViewTap,
            ),
            const SizedBox(width: 8),
            PageSearchButton(onTap: onSearchTap),
          ],
        ),
      ),
    );
  }
}
