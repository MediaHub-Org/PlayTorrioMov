import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';
import 'package:playtorriomov/widgets/anime/anime_card.dart';
import 'package:playtorriomov/widgets/iptv/iptv_channel_card.dart';
import 'package:playtorriomov/widgets/movie/movie_card.dart';
import 'package:playtorriomov/services/continue_watching/continue_watching_service.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorriomov/widgets/common/pill_tab_row.dart';
import 'package:playtorriomov/widgets/home/continue_watching_slider.dart';

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
    await tester.pumpAndSettle();
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

  /// The catalogue grids are all `SliverGridDelegateWithFixedCrossAxisCount`
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

  testWidgets('MovieCard does not overflow its catalogue cell at 3x text scale',
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

  testWidgets('AnimeCard does not overflow its catalogue cell at 3x text scale',
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
}
