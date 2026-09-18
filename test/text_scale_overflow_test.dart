import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/pages/anime/anime_details_page.dart';
import 'package:playtorriomov/pages/settings/settings_page.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';
import 'package:playtorriomov/widgets/anime/anime_card.dart';
import 'package:playtorriomov/widgets/iptv/iptv_channel_card.dart';
import 'package:playtorriomov/widgets/movie/movie_card.dart';
import 'package:playtorriomov/services/continue_watching/continue_watching_service.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorriomov/widgets/common/pill_tab_row.dart';
import 'package:playtorriomov/widgets/common/section_header.dart';
import 'package:playtorriomov/widgets/home/continue_watching_slider.dart';
import 'package:playtorriomov/widgets/player/player_aspect_menu.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_sources_panel.dart';
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
      final cardWidth = ContinueWatchingSlider.cardWidthFor(screenWidth);
      final cardHeight = ContinueWatchingSlider.cardHeightFor(screenWidth);

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
      // under that. 'Live TV' and 'Library' are HubController's longest
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
}
