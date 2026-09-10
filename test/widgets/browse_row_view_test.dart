// test/widgets/browse_row_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';
import 'package:playtorriomov/widgets/anime/anime_slider_section.dart';
import 'package:playtorriomov/widgets/common/browse_row_view.dart';
import 'package:playtorriomov/widgets/iptv/iptv_slider_section.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('BrowseRowView', () {
    testWidgets('an empty row renders nothing at all', (tester) async {
      // Not even the heading: a row whose catalog returned nothing should
      // leave no trace, rather than a title floating over blank space.
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(BrowseRowView<String>(
        title: 'Trending',
        items: const [],
        itemBuilder: (_, item) => Text(item),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Trending'), findsNothing);
    });

    testWidgets('renders the heading, subtitle and items', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(BrowseRowView<String>(
        title: 'Trending',
        subtitle: 'Top popular series',
        items: const ['one', 'two'],
        itemBuilder: (_, item) => Text(item),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Top popular series'), findsOneWidget);
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('sizingOf overrides the default poster width', (tester) async {
      // Live TV's channel cards are a logo/banner shape, not a poster
      // shape -- this is what lets IptvSliderSection reuse the row without
      // forcing every card through MovieCardSizing's aspect ratio.
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(BrowseRowView<String>(
        title: 'Channels',
        items: const ['one'],
        sizingOf: (_) => const RowCardSizing(
          cardWidth: 77,
          totalHeight: 140,
          spacing: 16,
          sidePadding: 18,
        ),
        itemBuilder: (_, item) => Text(item),
      )));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 77),
        findsOneWidget,
      );
    });
  });

  group('AnimeSliderSection', () {
    // It is now a thin wrapper over BrowseRowView rather than a second copy
    // of the row. This is what stops the Anime page and the anime search
    // page drifting apart on card size, spacing or arrow behaviour.
    testWidgets('delegates to the shared row', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(AnimeSliderSection(
        title: 'Trending Anime',
        subtitle: 'Top popular and trending series',
        animeList: const [
          AnimeMedia(id: 1, titleEnglish: 'Show One', titleRomaji: 'Show One'),
          AnimeMedia(id: 2, titleEnglish: 'Show Two', titleRomaji: 'Show Two'),
        ],
        onAnimeTap: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.byType(BrowseRowView<AnimeMedia>), findsOneWidget);
      expect(find.text('Trending Anime'), findsOneWidget);
      expect(find.text('Top popular and trending series'), findsOneWidget);
    });

    testWidgets('an empty anime list renders nothing', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AnimeSliderSection(
        title: 'Trending Anime',
        animeList: [],
        onAnimeTap: _noop,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Trending Anime'), findsNothing);
    });
  });

  group('IptvSliderSection', () {
    // Also a thin wrapper over BrowseRowView -- but with its own sizing
    // (IptvCardSizing, a logo/banner shape) instead of the row's default
    // poster shape, via BrowseRowView.sizingOf.
    testWidgets('delegates to the shared row with channel-card sizing', (
      tester,
    ) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(IptvSliderSection(
        title: 'Sports',
        subtitle: 'Live sports channels',
        channels: const [_channel],
        onChannelTap: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.byType(BrowseRowView<HardcodedChannel>), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Live sports channels'), findsOneWidget);
      final expectedWidth = IptvCardSizing.fromWidth(1200).cardWidth;
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == expectedWidth,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty channel list renders nothing', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(IptvSliderSection(
        title: 'Sports',
        channels: const [],
        onChannelTap: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Sports'), findsNothing);
    });
  });
}

const _channel = HardcodedChannel(
  id: 'test',
  name: 'Test Channel',
  short: 'TC',
  category: 'News',
  keywords: ['test'],
  gradient: [Colors.blue, Colors.purple],
);

void _noop(AnimeMedia _) {}
