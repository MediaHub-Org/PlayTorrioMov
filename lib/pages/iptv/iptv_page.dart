import 'package:flutter/material.dart';

import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/custom_channels_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/content_display_enums.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/header_pill_style.dart';
import '../../widgets/common/page_search_button.dart';
import '../../widgets/common/pill_filter_header_bar.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import '../../widgets/iptv/iptv_hero_slide.dart';
import '../../widgets/iptv/iptv_slider_section.dart' show IptvCardSizing;
import 'iptv_channel_sheet.dart';
import 'iptv_multiview_page.dart';
import 'iptv_player_page.dart';
import 'iptv_portals_modal.dart';
import 'iptv_search_page.dart';

class IptvPage extends StatefulWidget {
  const IptvPage({super.key});

  @override
  State<IptvPage> createState() => _IptvPageState();
}

class _IptvPageState extends State<IptvPage> {
  final IptvController _ctrl = IptvController.instance;

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
    // Liking a channel has to reorder the row it appears in, and the sheet
    // that does the liking sits over this page rather than replacing it.
    FavoriteChannelsService.items.addListener(_onSettingsChanged);
    CustomChannelsService.items.addListener(_onSettingsChanged);
    _ctrl.init();
    _loadSections();
  }

  @override
  void dispose() {
    IptvSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    FavoriteChannelsService.items.removeListener(_onSettingsChanged);
    CustomChannelsService.items.removeListener(_onSettingsChanged);
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
      pushPage(
        context,
        IptvPlayerPage(
          channel: channel,
          hits: results,
          initialHitIndex: 0,
        ),
      );
    } else {
      IptvChannelSheet.show(context, channel);
    }
  }

  void _navigateToSearch() {
    pushPage(context, const IptvSearchPage());
  }

  void _navigateToMultiView() {
    pushPage(context, const IptvMultiViewPage());
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
    // Live TV now renders through the same scaffold as Movies, Series and
    // Anime, rather than hand-rolling a hero, a row list and a header band.
    // Its three hero settings survive the move: auto-rotate and its interval
    // map onto `heroInterval`, and the style-driven height goes through the
    // `heroHeightOf` hook added for exactly this.
    // Liked channels lead, because someone opening Live TV is usually going
    // back to a channel they already keep. They lived only in Library until
    // now, which is the wrong place: you go to Library to manage what you
    // saved, and to Live TV to actually watch.
    final liked = FavoriteChannelsService.resolvedChannels;
    // Channels the user built from a portal stream. Their own row rather
    // than folded into a category: they exist because the built-in
    // catalogue had no entry, so filing them under one of its headings
    // would hide exactly what makes them worth having. Second, after Liked,
    // because a liked channel is a stronger signal than a saved one.
    final mine = CustomChannelsService.items.value;

    final rows = <BrowseRow<HardcodedChannel>>[
      if (liked.isNotEmpty)
        BrowseRow<HardcodedChannel>(
          title: 'Liked',
          subtitle: 'Channels you keep, most recent first',
          items: liked,
        ),
      if (mine.isNotEmpty)
        BrowseRow<HardcodedChannel>(
          title: 'Your channels',
          subtitle: 'Built from a stream you found in a portal',
          items: mine,
        ),
      for (final catName in visibleCategories)
        if (categoryMap.containsKey(catName) &&
            categoryMap[catName]!.$2.isNotEmpty)
          BrowseRow<HardcodedChannel>(
            title: catName,
            subtitle: categoryMap[catName]!.$1,
            items: categoryMap[catName]!.$2,
          ),
    ];

    final content = BrowseScaffold<HardcodedChannel>(
      // Spotlight off, or nothing featured, means no hero -- the scaffold
      // then falls back to a fixed header band, which is what this page did
      // unconditionally before.
      heroItems: spotlightEnabled ? _featured : const [],
      rows: rows,
      header: pillHeader,
      heroBuilder: (context, channel) => IptvHeroSlide(
        channel: channel,
        onWatchNow: () => _watchChannelNow(channel),
        onSourcesTap: () => _openChannel(channel),
      ),
      itemBuilder: (context, channel) => IptvChannelCard(
        channel: channel,
        onTap: () => _openChannel(channel),
      ),
      // Channel art is a logo or a banner, not a poster, so these rows keep
      // their own card shape rather than being forced into the 2:3 default.
      rowSizingOf: (width) => IptvCardSizing.fromWidth(width).toRowSizing(),
      heroHeightOf: _heroHeight,
      heroInterval: IptvSettings.heroAutoRotate.value
          ? Duration(seconds: IptvSettings.heroRotateSeconds.value)
          : null,
      onRefresh: () async {
        await _ctrl.scrape();
      },
    );

    // No scroll-track overlay here any more: BrowseScaffold floats its own
    // over whatever it is scrolling. Keeping this page's copy would have
    // left a second track driven by a controller no longer attached to any
    // scroll view.
    return Scaffold(
      backgroundColor: palette.scaffoldBackgroundColor,
      body: Container(
        color: palette.scaffoldBackgroundColor,
        child: RepaintBoundary(child: content),
      ),
    );
  }

  /// Live TV's user-selectable hero height. Immersive is the default and is
  /// the same formula [BrowseScaffold] uses for a desktop-width hero; the
  /// other two are the shorter variants this section has always offered.
  double _heroHeight(double screenWidth, double screenHeight) {
    switch (IptvSettings.heroStyle.value) {
      case HeroStyle.compact:
        return (screenHeight * 0.38).clamp(300.0, 400.0);
      case HeroStyle.minimalist:
        return (screenHeight * 0.28).clamp(210.0, 260.0);
      case HeroStyle.immersive:
        return (screenHeight * 0.52).clamp(380.0, 560.0);
    }
  }
}

/// Live TV's header row. Sits on the shared [PillFilterHeaderBar] like
/// every other section's header, so the inset, the bar height, the
/// one-line scrolling behaviour and the divider all come from one place
/// instead of this page re-deriving them -- it used to hand-roll its own
/// SafeArea and `fromLTRB(24, 24, 24, 16)` padding, which is why its
/// controls sat a few pixels off from Movies', Series' and Anime's.
///
/// The title and channel-count pills are the bar's [leading] run; the
/// three actions are its trailing pills.
class _IptvGlassAppBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onSourcesTap;
  final VoidCallback onMultiViewTap;

  const _IptvGlassAppBar({
    required this.onSearchTap,
    required this.onSourcesTap,
    required this.onMultiViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return PillFilterHeaderBar(
      transparent: true,
      leading: const [
        HeaderPillLabel(label: 'LIVE TV', icon: Icons.live_tv_rounded),
        HeaderPillLabel(
          label: '60+ CHANNELS',
          emphasised: false,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
      ],
      pills: [
        HeaderPillIconButton(
          icon: Icons.settings_input_antenna_rounded,
          tooltip: 'Manage Portals & Playlists',
          onTap: onSourcesTap,
        ),
        HeaderPillIconButton(
          icon: Icons.grid_view_rounded,
          tooltip: 'Multi-View (watch several channels at once)',
          onTap: onMultiViewTap,
        ),
        PageSearchButton(onTap: onSearchTap),
      ],
    );
  }
}
