import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/services/continue_watching/continue_watching_service.dart';
import 'package:playtorriomov/widgets/home/continue_watching_slider.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ContinueWatchingItem item({
  required String id,
  required String type,
  required String title,
}) {
  return ContinueWatchingItem(
    id: id,
    title: title,
    type: type,
    positionSeconds: 30,
    totalDurationSeconds: 100,
    lastWatchedAt: DateTime(2026, 1, 1),
    isTorrent: false,
  );
}

void main() {
  group('ContinueWatchingSlider.bandHeight', () {
    setUp(() {
      ContinueWatchingService.activeItems.value = [];
    });

    /// BrowseScaffold sizes its hero to `viewport - bandHeight` so that the
    /// hero and this row fill the screen exactly. That arithmetic is only as
    /// good as the constant, and the constant is declared next to a `build`
    /// that could quietly grow a line. So measure the rendered widget and
    /// hold the two to each other.
    Future<void> expectBandMatchesRender(
      WidgetTester tester, {
      required double screenWidth,
      required bool withHistory,
    }) async {
      tester.view.physicalSize = Size(screenWidth, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      ContinueWatchingService.activeItems.value = [
        item(id: 'tt1', type: 'movie', title: 'A Movie'),
      ];
      // "See all" is the tallest thing in the header, and it only appears
      // once something has been watched to the end. A band that changed
      // height when it did would move the hero above it.
      ContinueWatchingService.historyItems.value = withHistory
          ? [item(id: 'tt9', type: 'movie', title: 'Finished')]
          : [];
      addTearDown(() => ContinueWatchingService.historyItems.value = []);

      await tester.pumpWidget(
        // Unbounded height, as the SliverToBoxAdapter it really lives in
        // gives it -- under a bounded parent the Column would stretch and
        // measure the window instead of itself.
        wrap(
          const SingleChildScrollView(
            child: ContinueWatchingSlider(typeFilter: 'movie'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(ContinueWatchingSlider)).height,
        closeTo(ContinueWatchingSlider.bandHeight(screenWidth), 0.5),
      );
    }

    for (final width in <double>[420, 780, 1400]) {
      testWidgets('matches the rendered height at ${width}px wide', (
        tester,
      ) async {
        await expectBandMatchesRender(
          tester,
          screenWidth: width,
          withHistory: false,
        );
      });

      testWidgets('is unchanged by the See all button at ${width}px wide', (
        tester,
      ) async {
        await expectBandMatchesRender(
          tester,
          screenWidth: width,
          withHistory: true,
        );
      });
    }

    test('grows with the card size, one step per width tier', () {
      // Three tiers, each strictly taller than the last -- if the card
      // formula ever collapses to a constant this catches it.
      final phone = ContinueWatchingSlider.bandHeight(420);
      final tablet = ContinueWatchingSlider.bandHeight(780);
      final desktop = ContinueWatchingSlider.bandHeight(1400);

      expect(phone, lessThan(tablet));
      expect(tablet, lessThan(desktop));
    });
  });

  group('ContinueWatchingSlider typeFilter', () {
    setUp(() {
      // Every test starts from a clean slate; the notifier is a shared
      // static, so a leftover item from one test would leak into the next.
      ContinueWatchingService.activeItems.value = [];
    });

    testWidgets("'movie' shows only movie items, not series", (tester) async {
      ContinueWatchingService.activeItems.value = [
        item(id: 'tt1', type: 'movie', title: 'A Movie'),
        item(id: 'tt2', type: 'series', title: 'A Series'),
      ];

      await tester.pumpWidget(
        wrap(const ContinueWatchingSlider(typeFilter: 'movie')),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Movie'), findsOneWidget);
      expect(find.text('A Series'), findsNothing);
    });

    testWidgets("'series' shows only series items, not movies", (tester) async {
      ContinueWatchingService.activeItems.value = [
        item(id: 'tt1', type: 'movie', title: 'A Movie'),
        item(id: 'tt2', type: 'series', title: 'A Series'),
      ];

      await tester.pumpWidget(
        wrap(const ContinueWatchingSlider(typeFilter: 'series')),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Series'), findsOneWidget);
      expect(find.text('A Movie'), findsNothing);
    });

    testWidgets('renders nothing when the filtered list is empty', (
      tester,
    ) async {
      ContinueWatchingService.activeItems.value = [
        item(id: 'tt2', type: 'series', title: 'A Series'),
      ];

      await tester.pumpWidget(
        wrap(const ContinueWatchingSlider(typeFilter: 'movie')),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Series'), findsNothing);
      expect(find.byType(ContinueWatchingSlider), findsOneWidget);
    });
  });
}
