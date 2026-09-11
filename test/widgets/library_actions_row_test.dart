// test/widgets/library_actions_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/services/my_list/my_list_service.dart';
import 'package:playtorriomov/widgets/common/library_actions_row.dart';

MyListItem anime() => MyListItem(
  title: 'Frieren',
  year: 2023,
  type: 'anime',
  addedAt: DateTime(2026),
);

MyListItem movie() => MyListItem(
  title: 'Heat',
  year: 1995,
  type: 'movie',
  imdbId: 'tt0113277',
  addedAt: DateTime(2026),
);

Future<void> pumpRow(
  WidgetTester tester,
  MyListItem Function() builder, {
  void Function(MyListItem?)? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LibraryActionsRow(itemBuilder: builder, onChanged: onChanged),
      ),
    ),
  );
}

MyListItem? stored(MyListItem probe) =>
    LibraryActionsRow.entryFor(MyListService.items.value, probe);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MyListService.items.value = [];
    await MyListService.initialize();
  });

  group('LibraryActionsRow', () {
    testWidgets('offers exactly the three standard actions', (tester) async {
      await pumpRow(tester, movie);

      expect(find.byTooltip('Add to watchlist'), findsOneWidget);
      expect(find.byTooltip('Mark as watched'), findsOneWidget);
    });

    testWidgets('watchlist and watched are mutually exclusive', (tester) async {
      await pumpRow(tester, movie);

      await tester.tap(find.byTooltip('Add to watchlist'));
      await tester.pump();
      expect(stored(movie())?.isWatchlist, isTrue);

      await tester.tap(find.byTooltip('Mark as watched'));
      await tester.pump();
      expect(stored(movie())?.isWatched, isTrue);
      expect(
        stored(movie())?.isWatchlist,
        isFalse,
        reason: 'marking watched must clear the watchlist flag',
      );
    });

    testWidgets('liked is independent of watch state', (tester) async {
      await pumpRow(tester, movie);

      await tester.tap(find.byTooltip('Mark as watched'));
      await tester.pump();
      await tester.tap(find.byTooltip('Add to liked'));
      await tester.pump();

      final entry = stored(movie());
      // Something can be both watched and liked; that is the whole reason
      // Like is a separate toggle rather than a third mutually-exclusive
      // state alongside Watchlist and Watched.
      expect(entry?.isWatched, isTrue);
      expect(entry?.isLiked, isTrue);
    });

    testWidgets('anime saves under type "anime" so the Library tab matches', (
      tester,
    ) async {
      // The Library page filters its Anime tab on `type == 'anime'`. Anime
      // used to write to AnimeLibraryService only, so that tab could never
      // match anything the user had saved.
      await pumpRow(tester, anime);

      await tester.tap(find.byTooltip('Add to watchlist'));
      await tester.pump();

      expect(MyListService.items.value.single.type, 'anime');
      expect(MyListService.items.value.single.title, 'Frieren');
    });

    testWidgets('onChanged reports the new state after a toggle', (
      tester,
    ) async {
      // Anime uses this to mirror the status onto AnimeLibraryService, which
      // owns per-episode progress.
      final seen = <MyListItem?>[];
      await pumpRow(tester, anime, onChanged: seen.add);

      await tester.tap(find.byTooltip('Add to watchlist'));
      await tester.pump();

      expect(seen.length, 1);
      expect(seen.single?.isWatchlist, isTrue);
    });

    testWidgets('reflects state already in the list on first build', (
      tester,
    ) async {
      MyListService.setWatched(movie());
      await pumpRow(tester, movie);

      expect(find.byTooltip('Mark as unwatched'), findsOneWidget);
    });
  });

  group('LibraryActionsRow.entryFor', () {
    test('matches on id, not on object identity', () {
      final saved = movie();
      expect(LibraryActionsRow.entryFor([saved], movie()), isNotNull);
    });

    test('does not match a different title', () {
      expect(LibraryActionsRow.entryFor([movie()], anime()), isNull);
    });
  });
}
