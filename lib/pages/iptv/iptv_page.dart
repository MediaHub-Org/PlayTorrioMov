import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_colors.dart';

import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/custom_channels_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/browse_scaffold.dart';
import '../../widgets/common/header_pill_style.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../../widgets/common/pill_filter_header_bar.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import '../../widgets/iptv/iptv_hero_slide.dart';
import '../../widgets/iptv/iptv_slider_section.dart' show IptvCardSizing;
import 'iptv_channel_sheet.dart';
import 'iptv_multiview_page.dart';
import 'iptv_player_page.dart';
import 'iptv_sources_page.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

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
  List<HardcodedChannel> _music = [];
  List<HardcodedChannel> _news = [];
  List<HardcodedChannel> _arabic = [];
  List<HardcodedChannel> _discovery = [];
  List<HardcodedChannel> _kids = [];
  List<HardcodedChannel> _spanish = [];
  List<HardcodedChannel> _german = [];
  List<HardcodedChannel> _russian = [];
  List<HardcodedChannel> _chinese = [];


  @override
  void initState() {
    super.initState();
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
    _music = HardcodedChannels.byCategory('Music');
    _news = HardcodedChannels.byCategory('News');
    _arabic = HardcodedChannels.byCategory('Arabic');
    _discovery = HardcodedChannels.byCategory('Discovery');
    _kids = HardcodedChannels.byCategory('Kids');
    _spanish = HardcodedChannels.byCategory('Spanish');
    _german = HardcodedChannels.byCategory('German');
    _russian = HardcodedChannels.byCategory('Russian');
    _chinese = HardcodedChannels.byCategory('Chinese');
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

  void _navigateToMultiView() {
    pushPage(context, const IptvMultiViewPage());
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
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
      'Music Television': (
        'MTV, VH1 & Trace hits',
        _music,
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
      'Spanish TV': (
        'La 1, La 2, 24h news & Teledeporte',
        _spanish,
      ),
      'German TV': (
        'Das Erste, ZDF, RTL, n-tv & WELT',
        _german,
      ),
      'Russian TV': (
        'Channel One, Rossiya 1, NTV & RT',
        _russian,
      ),
      'Chinese TV': (
        'CCTV-1, CCTV-4, CCTV News & CGTN',
        _chinese,
      ),
    };

    final pillHeader = _IptvGlassAppBar(
      onSourcesTap: () => pushPage(context, const IptvSourcesPage()),
      onMultiViewTap: _navigateToMultiView,
    );
    // Live TV now renders through the same scaffold as Movies, Series and
    // Anime, rather than hand-rolling a hero, a row list and a header band.
    // Auto-rotate and its interval map onto `heroInterval`. The hero takes
    // the scaffold's own height like every other section: a separate
    // user-selectable height made this carousel a different size from the
    // rest for no reason a viewer could name.
    // Liked channels lead, because someone opening Live TV is usually going
    // back to a channel they already keep. They lived only in Library until
    // now, which is the wrong place: you go to Library to manage what you
    // saved, and to Live TV to actually watch.
    final liked = FavoriteChannelsService.resolvedChannels;
    // Channels the user built from a portal stream. Their own row rather
    // than folded into a category: they exist because the built-in
    // catalog had no entry, so filing them under one of its headings
    // would hide exactly what makes them worth having. Second, after Liked,
    // because a liked channel is a stronger signal than a saved one.
    final mine = CustomChannelsService.items.value;

    final rows = <BrowseRow<HardcodedChannel>>[
      if (liked.isNotEmpty)
        BrowseRow<HardcodedChannel>(
          title: context.l10n.libraryShelfLiked,
          subtitle: context.l10n.iptvLikedSub,
          items: liked,
        ),
      if (mine.isNotEmpty)
        BrowseRow<HardcodedChannel>(
          title: context.l10n.iptvYourChannels,
          subtitle: context.l10n.iptvYourChannelsSub,
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
      contentLabel: context.l10n.navLiveTv,
      // Spotlight off, or nothing featured, means no hero -- the scaffold
      // then falls back to a fixed header band, which is what this page did
      // unconditionally before.
      heroItems: spotlightEnabled ? _featured : const [],
      rows: rows,
      header: pillHeader,
      // The same viewport-filling hero the other sections get: without an
      // extent the scaffold falls back to its shorter default and this
      // carousel reads smaller than every sibling. No band widget rides
      // along -- Live TV channels do not track Continue Watching, so there
      // is nothing to show under it -- the extent only sizes the hero.
      belowHeroExtent: ContinueWatchingSlider.bandHeight,
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
      rowSizingOf: (width, scale) =>
          IptvCardSizing.fromWidth(width, scale: scale).toRowSizing(),
      heroInterval: IptvSettings.heroAutoRotate.value
          ? Duration(seconds: IptvSettings.heroRotateSeconds.value)
          : null,
      onRefresh: () async {
        await _ctrl.scrape();
      },
    );

    // No scroll-track overlay here: BrowseScaffold floats its own over
    // whatever it is scrolling. Keeping this page's copy would have left a
    // second track driven by a controller no longer attached to any scroll
    // view.
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        color: AppColors.canvas,
        child: RepaintBoundary(child: content),
      ),
    );
  }
}

/// Live TV's header row. Sits on the shared [PillFilterHeaderBar] like
/// every other section's header, so the inset, the bar height, the
/// one-line scrolling behavior and the divider all come from one place
/// instead of this page re-deriving them -- it used to hand-roll its own
/// SafeArea and `fromLTRB(24, 24, 24, 16)` padding, which is why its
/// controls sat a few pixels off from Movies', Series' and Anime's.
///
/// The title and channel-count pills are the bar's [leading] run; the
/// two actions are its trailing pills.
class _IptvGlassAppBar extends StatelessWidget {
  final VoidCallback onSourcesTap;
  final VoidCallback onMultiViewTap;

  const _IptvGlassAppBar({
    required this.onSourcesTap,
    required this.onMultiViewTap,
  });

  @override
  Widget build(BuildContext context) {
    return PillFilterHeaderBar(
      transparent: true,
      leading: [
        HeaderPillLabel(label: context.l10n.navLiveTv.toUpperCase(), icon: Icons.live_tv_rounded),
        HeaderPillLabel(
          label: context.l10n.iptvChannelsBadge.toUpperCase(),
          emphasized: false,
          fontSize: TvType.scale(AppType.microPlus),
          letterSpacing: 0.4,
        ),
      ],
      pills: [
        HeaderPillIconButton(
          icon: Icons.settings_input_antenna_rounded,
          tooltip: context.l10n.iptvManagePortals,
          onTap: onSourcesTap,
        ),
        HeaderPillIconButton(
          icon: Icons.grid_view_rounded,
          tooltip: context.l10n.iptvMultiViewTooltip,
          onTap: onMultiViewTap,
        ),
      ],
    );
  }
}
