// test/widgets/library_actions_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/services/collections/media_collections_service.dart';
import 'package:playtorriomov/services/my_list/my_list_service.dart';
import 'package:playtorriomov/widgets/collection/collection_picker_sheet.dart';
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
  bool expanded = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LibraryActionsRow(
          itemBuilder: builder,
          onChanged: onChanged,
          expanded: expanded,
        ),
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
    MediaCollectionsService.resetForTest();
    await MyListService.initialize();
  });

  group('LibraryActionsRow', () {
    testWidgets('offers the four standard actions', (tester) async {
      await pumpRow(tester, movie);

      expect(find.byTooltip('Add to watchlist'), findsOneWidget);
      expect(find.byTooltip('Mark as watched'), findsOneWidget);
      expect(find.byTooltip('Add to liked'), findsOneWidget);
      expect(find.byTooltip('Add to collection'), findsOneWidget);
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

  group('the collections action', () {
    testWidgets('opens the picker rather than toggling a state', (
      tester,
    ) async {
      // The other three flip one flag. This one cannot: a title can be in any
      // number of collections, so the tap has to ask which.
      await pumpRow(tester, movie);

      await tester.tap(find.byTooltip('Add to collection'));
      await tester.pumpAndSettle();

      expect(find.byType(CollectionPickerSheet), findsOneWidget);
      expect(
        MyListService.items.value,
        isEmpty,
        reason: 'opening the picker must not save anything by itself',
      );
    });

    testWidgets('reads as active once the title is filed somewhere', (
      tester,
    ) async {
      await pumpRow(tester, movie);
      expect(find.byTooltip('In a collection'), findsNothing);

      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, movie());
      await tester.pump();

      // The row answers "is this filed anywhere?" without being tapped.
      expect(find.byTooltip('In a collection'), findsOneWidget);
      expect(find.byTooltip('Add to collection'), findsNothing);
    });

    testWidgets('goes back to inactive when the last collection drops it', (
      tester,
    ) async {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, movie());
      await pumpRow(tester, movie);
      expect(find.byTooltip('In a collection'), findsOneWidget);

      MediaCollectionsService.removeItem(c.id, movie());
      await tester.pump();

      expect(find.byTooltip('Add to collection'), findsOneWidget);
    });

    testWidgets('deleting the collection clears the active state too', (
      tester,
    ) async {
      // Membership is derived, not stored on the title, so a deleted
      // collection must not leave the button lit with nothing behind it.
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, movie());
      await pumpRow(tester, movie);

      MediaCollectionsService.delete(c.id);
      await tester.pump();

      expect(find.byTooltip('Add to collection'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('four buttons fit a 320px phone without overflowing', (
      tester,
    ) async {
      // The narrowest screen this app supports, and the reason Play moved off
      // this line: a fourth button had nowhere to go while Play shared it.
      // Two overflow bugs have already shipped in this codebase from a Row
      // that was only ever looked at on a wide window.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpRow(tester, movie, expanded: true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Add to collection'), findsOneWidget);
    });

    testWidgets('expanded shares the width, clustered does not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpRow(tester, movie, expanded: true);
      await tester.pumpAndSettle();
      final spread = tester.getRect(find.byTooltip('Add to collection'));

      await pumpRow(tester, movie);
      await tester.pumpAndSettle();
      final clustered = tester.getRect(find.byTooltip('Add to collection'));

      // Roughly 92px each here against ~42px clustered. The point of the
      // stacked layout is that the buttons got bigger, not smaller.
      expect(spread.width, greaterThan(clustered.width));
      expect(
        spread.width,
        greaterThanOrEqualTo(48.0),
        reason: 'below the platform minimum tap target',
      );
    });

    testWidgets('clustered still fits a 320px phone', (tester) async {
      // The Arabic anime page lays these out in a Wrap, which cannot take an
      // Expanded child, so the clustered form has to survive a phone too.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpRow(tester, movie);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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
