// test/widgets/library_shelf_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/pages/collection/library_shelf_page.dart';
import 'package:playtorriomov/services/collections/media_collections_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Poster-less on purpose: a title with artwork renders a CachedNetworkImage,
/// which would put a real fetch and a plugin-backed cache inside the test.
MyListItem item(String title, String id) => MyListItem(
  title: title,
  type: 'movie',
  imdbId: id,
  addedAt: DateTime(2026),
);

Future<void> pumpCollection(WidgetTester tester, String id) async {
  await tester.pumpWidget(
    MaterialApp(home: LibraryShelfPage.collection(id)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MediaCollectionsService.resetForTest();
  });

  group('reorderTarget', () {
    test('a downward move loses the row it left behind', () {
      // ReorderableListView numbers the destination against the list before
      // the dragged row is removed; the service removes first, then inserts.
      expect(LibraryShelfPage.reorderTarget(0, 3), 2);
      expect(LibraryShelfPage.reorderTarget(1, 2), 1);
    });

    test('an upward move is already right', () {
      expect(LibraryShelfPage.reorderTarget(3, 0), 0);
      expect(LibraryShelfPage.reorderTarget(2, 1), 1);
    });

    test('dropping a row back where it started is a no-op index', () {
      expect(LibraryShelfPage.reorderTarget(2, 2), 2);
    });
  });

  group('a collection shelf', () {
    testWidgets('is titled with the collection name', (tester) async {
      final c = MediaCollectionsService.create('Weekend')!;
      await pumpCollection(tester, c.id);

      expect(find.text('Weekend'), findsOneWidget);
    });

    testWidgets('picks up a rename made while it is open', (tester) async {
      // Addressed by id rather than by value for exactly this: the page is a
      // view of the service, not a snapshot taken when it opened.
      final c = MediaCollectionsService.create('Weekend')!;
      await pumpCollection(tester, c.id);

      MediaCollectionsService.rename(c.id, 'Friday');
      await tester.pumpAndSettle();

      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('Weekend'), findsNothing);
    });

    testWidgets('says how to fill an empty one', (tester) async {
      final c = MediaCollectionsService.create('Weekend')!;
      await pumpCollection(tester, c.id);

      expect(find.text('Nothing in here yet'), findsOneWidget);
      expect(find.textContaining('Add to collection'), findsOneWidget);
    });

    testWidgets('survives being deleted from under itself', (tester) async {
      // Deleting from a second window, or from the Library behind this page.
      // An empty frame beats a crash.
      final c = MediaCollectionsService.create('Weekend')!;
      await pumpCollection(tester, c.id);

      MediaCollectionsService.delete(c.id);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Collection gone'), findsOneWidget);
    });

    testWidgets('offers reorder only once there is something to reorder', (
      tester,
    ) async {
      final c = MediaCollectionsService.create('Weekend')!;
      await pumpCollection(tester, c.id);
      expect(find.byTooltip('Reorder'), findsNothing);

      MediaCollectionsService.addItem(c.id, item('One', 'tt1'));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Reorder'),
        findsNothing,
        reason: 'one title has no order',
      );

      MediaCollectionsService.addItem(c.id, item('Two', 'tt2'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reorder'), findsOneWidget);
    });

    testWidgets('reorder mode swaps the grid for a draggable list', (
      tester,
    ) async {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, item('One', 'tt1'));
      MediaCollectionsService.addItem(c.id, item('Two', 'tt2'));
      await pumpCollection(tester, c.id);

      await tester.tap(find.byTooltip('Reorder'));
      await tester.pumpAndSettle();

      // Browsing is a grid; arranging is a list with drag handles, which is
      // the affordance Flutter ships and phone users already know.
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
      expect(find.byTooltip('Done'), findsOneWidget);
    });

    testWidgets('keeps the user order rather than sorting it', (tester) async {
      // A built-in shelf has no inherent order and offers sort. A collection's
      // order is the thing the user arranged, so sorting it would throw that
      // away -- there is no sort control here at all.
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, item('Zulu', 'tt1'));
      MediaCollectionsService.addItem(c.id, item('Alpha', 'tt2'));
      await pumpCollection(tester, c.id);

      expect(find.byTooltip('Sort by'), findsNothing);
      expect(
        MediaCollectionsService.byId(c.id)!.items.map((i) => i.title),
        ['Zulu', 'Alpha'],
      );
    });
  });
}
