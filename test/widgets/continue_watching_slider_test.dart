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
