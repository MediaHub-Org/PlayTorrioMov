import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/pages/anime/anime_details_page.dart';
import 'package:playtorriomov/pages/settings/about_settings_page.dart';
import 'package:playtorriomov/pages/settings/addons_settings_page.dart';
import 'package:playtorriomov/pages/settings/backup_settings_page.dart';
import 'package:playtorriomov/pages/settings/builtin_providers_settings_page.dart';
import 'package:playtorriomov/pages/settings/debrid_settings_page.dart';
import 'package:playtorriomov/pages/settings/appearance/live_tv_settings_page.dart';
import 'package:playtorriomov/pages/settings/keyboard_shortcuts_page.dart';
import 'package:playtorriomov/pages/settings/settings_page.dart';
import 'package:playtorriomov/pages/settings/sync_settings_page.dart';
import 'package:playtorriomov/pages/settings/video_player_settings_page.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';
import 'package:playtorriomov/widgets/anime/anime_card.dart';
import 'package:playtorriomov/widgets/iptv/iptv_channel_card.dart';
import 'package:playtorriomov/widgets/movie/movie_card.dart';
import 'package:playtorriomov/services/continue_watching/continue_watching_service.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorriomov/widgets/common/pill_tab_row.dart';
import 'package:playtorriomov/models/details/credit.dart';
import 'package:playtorriomov/services/metadata/bestsimilar_scraper.dart' show BSItem;
import 'package:playtorriomov/models/trakt/trakt_calendar_entry.dart';
import 'package:playtorriomov/services/trakt/trakt_calendar_service.dart';
import 'package:playtorriomov/pages/player/watch_screen.dart' show FilterPillRail;
import 'package:playtorriomov/widgets/common/error_view.dart';
import 'package:playtorriomov/widgets/common/section_header.dart';
import 'package:playtorriomov/widgets/movie/upcoming_calendar_row.dart';
import 'package:playtorriomov/widgets/player/player_seek_bar.dart';
import 'package:playtorriomov/widgets/player/sub_sync_bar.dart';
import 'package:playtorriomov/widgets/details/credit_card.dart';
import 'package:playtorriomov/services/app_units.dart';
import 'package:playtorriomov/widgets/details/similar_card.dart';
import 'package:playtorriomov/widgets/home/continue_watching_slider.dart';
import 'package:playtorriomov/widgets/player/player_aspect_menu.dart';
import 'package:playtorriomov/widgets/player/player_audio_menu.dart';
import 'package:playtorriomov/widgets/player/player_volume_menu.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/models/download/download_task_model.dart';
import 'package:playtorriomov/services/download/download_service.dart';
import 'package:playtorriomov/pages/collection/collection_page.dart';
import 'package:playtorriomov/pages/search/search_page.dart';
import 'package:playtorriomov/pages/iptv/iptv_sources_page.dart';
import 'package:playtorriomov/widgets/player/player_cast_sheet.dart';
import 'package:playtorriomov/widgets/player/player_episodes_panel.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_sources_panel.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';
import 'package:playtorriomov/widgets/player/player_stats_menu.dart';
import 'package:playtorriomov/widgets/player/player_sub_style_modal.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';
import 'package:playtorriomov/widgets/player/player_top_bar.dart';
import 'package:playtorriomov/widgets/player/player_transport.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';

/// #69's own text: "the app scales today -- and overflows, because its
/// layouts are fixed-height." This is the checkable part of the audit that
/// entry calls for, scoped (per the same entry) to the highest-traffic
/// chrome rather than every fixed-height `Container` in `lib/` -- start
/// small and real, not exhaustive and unverified.
///
/// Each widget here pumps at a large accessibility text scale (3.0, the
/// top of Android's slider) inside the narrowest phone width the app
/// targets, and asserts no `RenderFlex overflowed` (or any other) exception
/// reached the test binding during layout.
void main() {
  Future<void> pumpAtScale(
    WidgetTester tester, {
    required Widget child,
    double scale = 3.0,
    Size size = const Size(360, 720),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // AdaptiveNavShell resolves its section labels through
        // AppLocalizations (#68); wired here so this exercises the real
        // localized path rather than HubSection.localizedLabel's
        // no-delegate English fallback.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: widget!,
        ),
        home: child,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A page carrying a looping animation -- the details pages' ambient
      // background -- never settles, so pumpAndSettle times out rather than
      // reporting anything about layout. Overflow is raised during layout on
      // the first frame, so a couple of pumps is all this needs.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  ContinueWatchingItem watching({String title = 'A Show With A Long Name'}) =>
      ContinueWatchingItem(
        id: 'tt1',
        title: title,
        type: 'series',
        season: 2,
        episode: 7,
        episodeTitle: 'An Episode Title That Runs On',
        positionSeconds: 30,
        totalDurationSeconds: 100,
        lastWatchedAt: DateTime(2026, 1, 1),
        isTorrent: false,
      );

  testWidgets(
    'a Continue Watching card does not overflow its own fixed height at 3x '
    'text scale',
    (tester) async {
      // The card is hosted at exactly cardWidthFor/cardHeightFor -- see the
      // slider's ListView -- and that height is `width * 0.62 + 60`, where
      // the 60 is the title/subtitle block and does not move with text
      // scale. Artwork takes `width * 0.58`, so the text gets what is left.
      // This reproduces that box rather than approximating it.
      const screenWidth = 360.0;
      // At the largest rem factor the layout uses, which is what 3x text
      // resolves to.
      final cardWidth =
          ContinueWatchingSlider.cardWidthFor(screenWidth, AppUnits.maxScale);
      final cardHeight =
          ContinueWatchingSlider.cardHeightFor(screenWidth, AppUnits.maxScale);

      await pumpAtScale(
        tester,
        size: const Size(screenWidth, 720),
        child: Scaffold(
          body: SizedBox(
            height: cardHeight,
            child: ContinueWatchingCard(
              item: watching(),
              width: cardWidth,
              palette: AppThemeService.currentPalette.value,
              onTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the title block has to clamp: cardHeightFor reserves a flat '
            '60px for it, and bandHeight is deliberately a pure function of '
            'width so the reservation cannot grow with the text',
      );
    },
  );

  testWidgets(
    'the Continue Watching section header does not overflow at 3x text scale',
    (tester) async {
      // headerHeight is pinned at 48 so bandHeight stays exact whether or
      // not the "See all" button is there. Pinned means the 18px title and
      // the button inside it have nowhere to go when the text grows.
      ContinueWatchingService.activeItems.value = [watching()];
      addTearDown(() => ContinueWatchingService.activeItems.value = []);

      await pumpAtScale(
        tester,
        child: const Scaffold(
          body: SingleChildScrollView(child: ContinueWatchingSlider()),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the header is a fixed 48px SizedBox; its title and count '
            'have to clamp rather than push past it',
      );
    },
  );

  /// The catalog grids are all `SliverGridDelegateWithFixedCrossAxisCount`
  /// with a fixed `childAspectRatio` and three columns on a phone, so a cell
  /// is a hard box: the poster is `Expanded` and the text below it is not,
  /// which means growing text eats the poster until there is none left and
  /// then overflows. Hosting the card in the real delegate is the only way
  /// to reproduce that -- a card pumped loose has unbounded height and can
  /// never overflow.
  Widget inCatalogueGrid(Widget card, {double aspectRatio = 0.62}) {
    return GridView(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      children: [card],
    );
  }

  testWidgets('MovieCard does not overflow its catalog cell at 3x text scale',
      (tester) async {
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: inCatalogueGrid(
          MovieCard(
            movie: Movie(
              id: 'tt0113277',
              name: 'A Film With A Fairly Long Title',
              year: '1995',
              type: 'movie',
              addonBaseUrl: 'https://v3-cinemeta.strem.io',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'the poster is Expanded and the title/year block is not, so at '
          'a large scale the text takes the cell and the poster is squeezed '
          'to nothing before anything gives',
    );
  });

  testWidgets('AnimeCard does not overflow its catalog cell at 3x text scale',
      (tester) async {
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: inCatalogueGrid(
          AnimeCard(
            anime: const AnimeMedia(
              id: 1,
              titleUserPreferred: 'An Anime With A Fairly Long Title',
              format: 'TV',
              seasonYear: 2023,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'IptvChannelCard does not overflow its Live TV cell at 3x text scale',
      (tester) async {
    // 0.58 rather than 0.62 -- Live TV's own grid ratio, matching
    // IptvCardSizing. See the Library's channel grid.
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: inCatalogueGrid(
          IptvChannelCard(
            channel: const HardcodedChannel(
              id: 'ch1',
              name: 'A Channel With A Long Name HD',
              short: 'CH1',
              category: 'News',
              keywords: ['ch1'],
              gradient: [Color(0xFF222222), Color(0xFF444444)],
            ),
            onTap: () {},
          ),
          aspectRatio: 0.58,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the mobile bottom section tab bar does not overflow at 3x text scale',
    (tester) async {
      // AdaptiveNavShell picks the mobile tier (bottom tab bar, not the
      // desktop chip row) below AppBreakpoints.tablet -- 360 is comfortably
      // under that. 'Live TV' and 'Profile' are HubController's longest
      // real labels, so this exercises the actual production strings, not
      // a friendlier stand-in.
      await pumpAtScale(
        tester,
        child: const Scaffold(body: AdaptiveNavShell(child: SizedBox())),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the bottom tab bar is a fixed AdaptiveNavShell.mobileBottomBarHeight; '
            'a label that grows with text scale has to clamp, not push past it',
      );
    },
  );

  testWidgets(
    'PillTabRow does not overflow the fixed AppBar.bottom height it is hosted in at 3x text scale',
    (tester) async {
      // Mirrors LibraryTabs: PillTabRow sits inside an AppBar's `bottom`,
      // a PreferredSize fixed at 52 tall -- see library_tabs.dart. Longer
      // labels than the two-word tabs any current hub actually uses, to
      // give the scroll-vs-overflow distinction a real workout too.
      await pumpAtScale(
        tester,
        child: Scaffold(
          appBar: AppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: PillTabRow(
                tabs: const [
                  SubTab(id: 'a', label: 'Audiobooks', icon: Icons.headphones_rounded),
                  SubTab(id: 'b', label: 'Books', icon: Icons.menu_book_rounded),
                  SubTab(id: 'c', label: 'Manga', icon: Icons.auto_stories_rounded),
                ],
                activeId: 'a',
                onSelected: (_) {},
              ),
            ),
          ),
          body: const SizedBox(),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'a label that grows with text scale has to clamp, not push past the '
            'fixed 52px AppBar.bottom PreferredSize it is hosted in',
      );
    },
  );

  testWidgets(
    'the anime details page action rows do not overflow at 3x text scale',
    (tester) async {
      // The roadmap's own next target for #69: the details page action rows.
      // Anime is the one that can be pumped offline -- it takes its data as a
      // constructor argument, where DetailsPage fetches its own over the
      // network. Its Play button is a bare Row of icon + label with no flex
      // on either, the same shape that broke the three catalog cards.
      await pumpAtScale(
        tester,
        settle: false,
        child: const AnimeDetailsPage(
          anime: AnimeMedia(
            id: 21,
            titleEnglish: 'One Piece',
            titleRomaji: 'ONE PIECE',
            totalEpisodes: 1120,
            format: 'TV',
            status: 'RELEASING',
            genres: ['Action', 'Adventure', 'Fantasy'],
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'Play is a full-width Row of icon + label with no flex on the '
            'label, so at a large scale the text takes the line and paints '
            'past the button',
      );
    },
  );

  testWidgets(
    'the player settings menu does not overflow at 3x text scale',
    (tester) async {
      // The roadmap's next #69 target after the details pages: the player's
      // chrome, which every user meets every session. This is the gear menu
      // -- four rows in a fixed-width card, each a fixed 44px Container.
      //
      // Pumped inside the real PlayerMenuAnchor, not bare. The anchor is
      // what bounds the card and scrolls it when the rows no longer fit, so
      // a bare pump reports a vertical overflow that production cannot
      // have -- the card is allowed to be taller than the screen there.
      await pumpAtScale(
        tester,
        child: const Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: SleepTimerMenu(),
              ),
            ],
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the sleep timer chips are sized by their labels, which grow '
            'with the scale and can want more than the card has',
      );
    },
  );

  testWidgets(
    'the player speed menu does not overflow at 3x text scale',
    (tester) async {
      // The -/+ buttons flank the slider in a Row, and the preset chips sit in
      // a Wrap: the slider takes what is left, and a chip that no longer fits
      // drops to a second line rather than running off the card.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: PlayerSpeedMenu(
                  currentRate: 1.0,
                  onRateSelected: (_) {},
                  onClose: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the subtitle style editor does not overflow at 3x text scale',
    (tester) async {
      // Two toggle tiles share a row, so each is under 170px wide at 360; the
      // fixed icon + title + switch overflowed there even at normal size.
      await pumpAtScale(
        tester,
        settle: false,
        child: const Scaffold(
          body: SizedBox(height: 700, child: SubtitleStyleEditor()),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the player aspect menu does not overflow at 3x text scale',
    (tester) async {
      // Same shape as the settings rows above: a fixed-height Container with
      // a bare Row inside it, so the label takes its natural width and the
      // check icon beside it goes past the edge.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: PlayerAspectMenu(
                  currentFit: BoxFit.contain,
                  currentForcedRatio: null,
                  onFitSelected: (_) {},
                  onRatioSelected: (_) {},
                  onClose: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a browse row header does not overflow at 3x text scale',
    (tester) async {
      // SectionHeader is the heading above every row on every browse page --
      // the most-repeated text in the app. Its title is Expanded and its
      // "See All" is short, so this was expected to pass; it is here because
      // "expected to pass" is what the last four probes also said, and one
      // of them was wrong.
      //
      // Wrapped in a scroll view because that is where it lives: a browse
      // page is a scrollable, so the header has unbounded height and a
      // subtitle that wraps to four lines at 3x is simply a taller header.
      // Pumped bare it reports a 790px vertical overflow production cannot
      // have.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: SingleChildScrollView(
            child: SectionHeader(
              title: 'Popular Movies This Week',
              subtitle: 'Updated daily from every addon you have installed',
              onSeeAll: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the settings hub does not overflow at 3x text scale',
    (tester) async {
      // The screen a user who needs large text is most likely to be on. Its
      // category tiles are fixed 76px boxes with a title and a badge, and
      // the real page is pumped rather than a tile in isolation because the
      // tile is private -- and because the page is what a user actually
      // meets.
      await pumpAtScale(
        tester,
        settle: false,
        child: const SettingsPage(),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'a fixed 76px tile whose title and badge both grow with the '
            'scale has to flex or clamp',
      );
    },
  );

  testWidgets(
    'the transport bar does not overflow at 3x text scale',
    (tester) async {
      // The player chrome the two menu probes above do not cover, and the
      // first item on #69's remaining list. The buttons are icon-only, so
      // the risk is the seek bar's two time labels: each sits in a
      // `minWidth: 46` box, and at 3x "1:23:45" wants far more than 46px.
      //
      // Pumped at the bottom of a Stack, which is where it lives -- it is
      // the last child of the player's overlay, anchored to the bottom edge.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: PlayerTransport(
                  position: const Duration(hours: 1, minutes: 23, seconds: 45),
                  duration: const Duration(hours: 2, minutes: 34, seconds: 56),
                  buffered: const Duration(hours: 1, minutes: 50),
                  volume: 0.8,
                  isMuted: false,
                  playbackRate: 1.0,
                  isSubtitlesActive: true,
                  onSeek: (_) {},
                  onVolumeChanged: (_) {},
                  onToggleMute: () {},
                  onOpenSubtitleMenu: () {},
                  onOpenSpeedMenu: () {},
                  onOpenStatsMenu: () {},
                  onOpenAudioMenu: () {},
                  onOpenAspectMenu: () {},
                  onOpenSleepTimerMenu: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the seek bar time labels sit in fixed minWidth boxes, and a '
            'long timestamp at 3x wants more than the box has',
      );
    },
  );

  testWidgets(
    'the top bar does not overflow at 3x text scale',
    (tester) async {
      // The fifth action in the row: the fullscreen button joined download,
      // copy link, cast and episodes, and a phone has to fit all of them
      // beside the title.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: PlayerTopBar(
            title: 'A Film With A Rather Long Title',
            subtitle: 'S1:E2 • An Episode Title',
            onBack: () {},
            onToggleEpisodes: () {},
            onCopyStreamUrl: () {},
            onDownload: () {},
            onToggleFullscreen: () {},
            onCast: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the stats popover does not overflow at 3x text scale',
    (tester) async {
      // The newest transport-bar popover, carrying the longest strings it
      // can meet: a two-part source name, a host and a full info hash next
      // to their labels.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: PlayerStatsMenu(
            sourceLabel: 'A Very Long Addon Name · 1080p BluRay x264',
            streamKind: 'Torrent',
            host: 'a-very-long-hostname.example.com',
            infoHash: '0123456789abcdef0123456789abcdef01234567',
            buffered: ValueNotifier<Duration?>(
              const Duration(seconds: 42),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the sources panel does not overflow at 3x text scale',
    (tester) async {
      // The other half of #69's first remaining item. This panel is a
      // full-height column of source rows, each with a title, a badge row
      // and a metadata line -- the most text-dense thing in the player.
      //
      // Given cached sources so it renders rows instead of starting a
      // scrape: the probe is about layout, and a scrape would leave the
      // panel in its loading state (and a pending timer) instead.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: PlayerSourcesPanel(
            episode: Video(
              id: 'tt1:1:1',
              title: 'Pilot',
              season: 1,
              episode: 1,
            ),
            currentAddonName: 'Cinemeta',
            cachedSources: [
              StreamSource(
                name: 'Torrentio',
                title: 'A Release Name That Is Quite Long Indeed 1080p',
                url: 'https://example.com/a.mkv',
                addonName: 'Torrentio',
              ),
              StreamSource(
                name: 'Debrid',
                title: 'Another Source',
                url: 'https://example.com/b.mkv',
                addonName: 'Debrid',
              ),
            ],
            onSourcesLoaded: (_) {},
            onPlaySource: (_, __) {},
            onBackToEpisodes: () {},
            onClose: () {},
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'each source row stacks a title, badges and a metadata line '
            'inside a fixed-height container',
      );
    },
  );

  // The settings pages behind the hub -- #69's first remaining item, and the
  // most text-heavy screens in the app. Each is pumped as the real page
  // rather than a card in isolation, because the cards are private and
  // because the page is what a user meets.
  //
  // `settle: false` throughout: several of these kick off a plugin call or a
  // provider status check in `initState`, and a probe that waits for those
  // would either time out or leave a pending timer at teardown. Overflow is
  // raised during layout on the first frame, so a couple of pumps is all
  // this needs.
  for (final (name, page) in <(String, Widget)>[
    ('keyboard shortcuts', const KeyboardShortcutsPage()),
    ('built-in providers', const BuiltinProvidersSettingsPage()),
    ('addons', const AddonsSettingsPage()),
    ('about', const AboutSettingsPage()),
    ('backup', const BackupSettingsPage()),
    ('connect', const SyncSettingsPage()),
    ('debrid', const DebridSettingsPage()),
    ('video player', const VideoPlayerSettingsPage()),
    ('live tv', const LiveTvSettingsPage()),
  ]) {
    testWidgets(
      'the $name settings page does not overflow at 3x text scale',
      (tester) async {
        await pumpAtScale(tester, settle: false, child: page);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the $name page is a column of fixed-height cards whose '
              'titles, subtitles and badges all grow with the scale',
        );
      },
    );
  }

  testWidgets(
    'the episode picker does not overflow at 3x text scale',
    (tester) async {
      // #69's remaining target. The panel is hosted in a Positioned.fill over
      // the player -- see player_screen.dart -- so it gets the whole screen,
      // which is what this reproduces. Long episode titles on purpose: the
      // row is where a translated or verbose title would bite.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              const ColoredBox(color: Colors.black),
              Positioned.fill(
                child: PlayerEpisodesPanel(
                  videos: [
                    for (var i = 1; i <= 12; i++)
                      Video(
                        id: 'tt1:1:$i',
                        title: 'Episode $i - A Rather Long Episode Title',
                        season: 1,
                        episode: i,
                      ),
                  ],
                  onEpisodeSelected: (_) {},
                  onClose: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the episode rows and the season/batch controls above them sit '
            'in fixed-height boxes',
      );
    },
  );

  testWidgets(
    'the cast sheet does not overflow at 3x text scale',
    (tester) async {
      // Shown through showModalBottomSheet in production, which caps the
      // sheet at a fraction of the screen -- pumping it loose would give it
      // unbounded height and prove nothing. CastService.startDiscovery is a
      // no-op off-device (it returns early unless isSupported && _initialized),
      // so initState is safe here.
      await pumpAtScale(
        tester,
        settle: false,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PlayerCastSheet.show(
                  context,
                  title: 'A Film With A Fairly Long Title',
                  streamUrl: 'https://example.invalid/a.mp4',
                ),
                child: const Text('cast'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('cast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.takeException(),
        isNull,
        reason: 'the empty state, the title row and the device rows all sit in '
            'a sheet whose height the modal decides, not their content',
      );
    },
  );

  testWidgets(
    'a credits card stays inside the rail that sizes it, at 3x text scale',
    (tester) async {
      // The gap this closes: the cast rail's clamps were derived from
      // arithmetic -- avatar + 6 + name + 2 + role against a fixed 148 -- and
      // never measured, because `DetailsPage` fetches its own data and the card
      // was a private builder on it. It is a public widget now, so the rail's
      // box can be reproduced exactly rather than reasoned about.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
            height: CreditCard.railHeightOf(context),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                CreditCard(
                  credit: const Credit(
                    name: 'Benedict Cumberbatch',
                    role: 'Doctor Stephen Strange',
                    profileUrl: null,
                  ),
                  onTap: () {},
                ),
                // A credit with no role still has to occupy the same column,
                // which is the reason that line is a fixed 12px box.
                CreditCard(
                  credit: const Credit(name: 'An Uncredited Person'),
                  onTap: () {},
                ),
              ],
            ),
            ),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the rail is a fixed 9.25 rem and the avatar '
            'keeps its size, so the two text lines are what has to give',
      );
    },
  );

  testWidgets(
    'a similar card stays inside its 64px text budget at 3x text scale',
    (tester) async {
      // Same gap, same fix. The poster takes the 2:3, so the title and the
      // year/genre line share a flat 64px however large the text gets.
      const cardWidth = 130.0;
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: SizedBox(
            height: SimilarCard.heightFor(cardWidth, AppUnits.maxScale),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SimilarCard(
                  width: cardWidth,
                  onTap: () {},
                  // Every field is required on BSItem, and the ones this
                  // card never reads are the tag lists and the story.
                  item: BSItem(
                    id: 1,
                    slug: 'a-film',
                    title: 'A Film With A Fairly Long Title',
                    year: 2019,
                    rating: 7.8,
                    voteCount: '67K',
                    thumbUrl: '',
                    similarityPercent: 92,
                    genre: 'Science Fiction, Adventure',
                    country: 'US',
                    duration: '128 min',
                    story: null,
                    styleTags: const [],
                    plotTags: const [],
                    audienceTags: const [],
                    timeTags: const [],
                    placeTags: const [],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'both lines are capped at 1.3 because the card height is set '
            'by the rail and cannot grow with the text',
      );
    },
  );

  // Four more off #69's long tail. The tail is mostly *pages*, which fetch over
  // the network and so cannot be constructed -- these are the widgets in it
  // that can, picked for traffic rather than for being easy: a failed load, a
  // playing video, a subtitle being nudged, and the rail over every source
  // list.

  testWidgets('an error view does not overflow at 3x text scale',
      (tester) async {
      // The most-seen fixed-height box in the app that nobody had probed: every
      // failed catalog load lands here, and its message is a whole sentence.
    await pumpAtScale(
      tester,
      child: ErrorView(
        title: 'Could not load this catalog',
        error: 'SocketException: Failed host lookup: '
            "'v3-cinemeta.strem.io' (OS Error: No address associated with "
            'hostname, errno = 7)',
        onRetry: () {},
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the seek bar does not overflow at 3x text scale',
      (tester) async {
    // A 36px row holding two time labels. It is on screen for the whole of
    // every video, which is what earns it a probe even though its alignment
    // stays physical on purpose.
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: Center(
          child: PlayerSeekBar(
            position: const Duration(hours: 1, minutes: 23, seconds: 45),
            duration: const Duration(hours: 2, minutes: 30),
            buffered: const Duration(hours: 1, minutes: 30),
            onSeek: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the subtitle sync bar does not overflow at 3x text scale',
      (tester) async {
    // A 28px bar of stepper buttons around a signed offset, and the offset is
    // the part that grows: "-12.50s" is wider than "0.00s".
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: Center(
          child: SubSyncBar(
            delaySec: -12.5,
            onDelayChanged: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the Calendar row does not overflow at 3x text scale',
      (tester) async {
    // A 92px card carrying a show title, an SxxExx code and an episode title.
    // Constructible only because it already takes an injected fetcher, which is
    // exactly what the rest of the tail lacks.
    final now = DateTime.now();
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: UpcomingCalendarRow(
          isTraktAuthenticated: () async => true,
          traktCalendar: TraktCalendarService.forTesting(
            fetcher: (start, days) async => [
              TraktCalendarEntry(
                firstAired: now.add(const Duration(days: 1)).toIso8601String(),
                firstAiredLocal: now.add(const Duration(days: 1)),
                showTraktId: 1,
                showTitle: 'A Show With A Name That Keeps Going',
                seasonNumber: 12,
                episodeNumber: 7,
                episodeTitle: 'An Episode Title That Also Keeps Going',
                imdbId: 'tt0000001',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the source filter rail does not overflow at 3x text scale',
      (tester) async {
    // Over every source list. Public for exactly this reason -- the rail cannot
    // be reached through WatchScreen without a network-backed source list, so
    // it was made constructible rather than left unprobed.
    await pumpAtScale(
      tester,
      child: Scaffold(
        body: Center(
          child: FilterPillRail(
            children: [
              for (final label in ['1080p', 'Debrid only', 'English audio'])
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(label),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the player audio menu does not overflow at 3x text scale',
    (tester) async {
      // #69's remaining target, beside the subtitle menu below. The rows
      // are languages in a fixed-width card; a long one has nowhere to go
      // sideways when the text triples.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: PlayerAudioMenu(
                  audioTracks: const [
                    PlayerAudioTrack(index: 1, title: 'English'),
                    PlayerAudioTrack(index: 2, title: 'Spanish (LATAM)'),
                    PlayerAudioTrack(index: 3, title: 'Portuguese (BR)'),
                  ],
                  selectedIndex: 1,
                  onTrackSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the player volume menu does not overflow at 3x text scale',
    (tester) async {
      // A readout, a button and a slider in a fixed-width card, with the
      // TV's hint line under them; the readout is the large text.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: PlayerVolumeMenu(
                  volume: 2.1,
                  isMuted: false,
                  onVolumeChanged: (_) {},
                  onToggleMute: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the player subtitle menu does not overflow at 3x text scale',
    (tester) async {
      // The same #69 target from the reading side. Embedded rows carry a
      // flag, a language and up to two badges; the toggle, tabs and chips
      // above them are all fixed-height rows of their own.
      await pumpAtScale(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              PlayerMenuAnchor(
                child: PlayerSubtitleMenu(
                  embeddedSubtitles: const [
                    PlayerEmbeddedSubtitle(index: 1, title: 'English'),
                    PlayerEmbeddedSubtitle(
                      index: 2,
                      title: 'Spanish (LATAM)',
                      containerTitle: 'Spanish (LATAM) Forced',
                    ),
                    PlayerEmbeddedSubtitle(
                      index: 3,
                      title: 'Portuguese (BR)',
                      containerTitle: 'Portuguese (BR) SDH',
                    ),
                  ],
                  audioLanguage: 'en',
                  isSubtitleEnabled: true,
                  selectedEmbeddedIndex: 1,
                  onSelectVariant: (_) {},
                  onSelectEmbedded: (_) {},
                  onEnable: () {},
                  onDisable: () {},
                  onOpenSyncBar: () {},
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a downloads row does not overflow at 3x text scale',
    (tester) async {
      // #69's remaining target on the Library side. The row is a poster, a
      // text column with a wrapping chip line, and action buttons -- the
      // chip line is the variable-length part, so this probes it with four
      // audio languages and a long title. Determinate progress: an
      // indeterminate bar animates forever and pumpAndSettle would time
      // out rather than report anything about layout.
      SharedPreferences.setMockInitialValues({});
      DownloadService.instance.tasksNotifier.value = [
        DownloadTask(
          id: 't1',
          title: 'The Lord of the Rings: The Return of the King Extended Edition',
          mediaId: 'tt0167260',
          type: 'movie',
          sourceType: DownloadSourceType.p2p,
          sourceName: 'Torrent Galaxy',
          targetFilePath: '/downloads/lotr.mkv',
          quality: '1080p',
          audioLanguages: const ['english', 'spanish', 'german', 'french'],
          status: DownloadStatus.downloading,
          receivedBytes: 1000000000,
          totalBytes: 4000000000,
          createdAt: DateTime(2026),
        ),
      ];
      addTearDown(() => DownloadService.instance.tasksNotifier.value = []);

      await pumpAtScale(
        tester,
        child: const CollectionPage(initialTabIndex: 2),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the search page idle state does not overflow at 3x text scale',
    (tester) async {
      // #69's remaining target on the search side. No query is entered,
      // so nothing fires -- the field row, the scope chips and the empty
      // state are what is probed. Entering text would start the debounce
      // timer and a network search, neither of which belongs in this file.
      SharedPreferences.setMockInitialValues({});
      await pumpAtScale(
        tester,
        child: const SearchPage(),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the library collections tab does not overflow at 3x text scale',
    (tester) async {
      // The shelf cards pair a square tile with a fixed-height label
      // block; the grid sizes that block from the text scale, but only a
      // probe says the arithmetic held.
      SharedPreferences.setMockInitialValues({});
      await pumpAtScale(
        tester,
        child: const CollectionPage(),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the live tv sources page does not overflow at 3x text scale',
    (tester) async {
      // The page is new and its rows pair a fixed tile with wrapping
      // badges; the controller starts empty here, so this probes the
      // section chrome, the add buttons and the empty states rather than
      // rows, which need a real portal behind them.
      await pumpAtScale(
        tester,
        child: const Scaffold(body: IptvSourcesPage()),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
