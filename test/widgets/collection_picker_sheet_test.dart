// test/widgets/collection_picker_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/services/collections/media_collections_service.dart';
import 'package:playtorriomov/widgets/collection/collection_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

MyListItem movie() => MyListItem(
  title: 'Heat',
  year: 1995,
  type: 'movie',
  imdbId: 'tt0113277',
  addedAt: DateTime(2026),
);

/// Opens the sheet the way the details page does, through `show`, so the test
/// covers the modal route rather than the bare widget.
Future<void> openSheet(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => CollectionPickerSheet.show(context, movie()),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MediaCollectionsService.resetForTest();
  });

  group('with no collections yet', () {
    testWidgets('says so instead of showing an empty list', (tester) async {
      await openSheet(tester);

      expect(find.textContaining('No collections yet'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);
    });

    testWidgets('creating one from here also files the title in it', (
      tester,
    ) async {
      // The whole reason create lives in this sheet as well as the Library:
      // the moment you most want a new collection is while holding a title
      // that fits none of the existing ones. Leaving to create it and coming
      // back to find the title again is the path this avoids.
      await openSheet(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Weekend');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final made = MediaCollectionsService.collections.value.single;
      expect(made.name, 'Weekend');
      expect(made.contains(movie()), isTrue, reason: 'created and added');
    });

    testWidgets('a blank name creates nothing and keeps the field open', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(MediaCollectionsService.collections.value, isEmpty);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'closing the field would look like it had worked',
      );
    });
  });

  group('with collections', () {
    testWidgets('a tap files the title, and a second tap takes it out', (
      tester,
    ) async {
      // No Save button by design: every row is one reversible toggle, and a
      // confirm step would only add a way to lose the change.
      final c = MediaCollectionsService.create('Weekend')!;
      await openSheet(tester);

      await tester.tap(find.text('Weekend'));
      await tester.pumpAndSettle();
      expect(MediaCollectionsService.byId(c.id)!.contains(movie()), isTrue);

      await tester.tap(find.text('Weekend'));
      await tester.pumpAndSettle();
      expect(MediaCollectionsService.byId(c.id)!.contains(movie()), isFalse);
    });

    testWidgets('the checkbox tracks membership as it changes', (tester) async {
      MediaCollectionsService.create('Weekend');
      await openSheet(tester);

      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);

      await tester.tap(find.text('Weekend'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNothing);
    });

    testWidgets('a title can be filed in several at once', (tester) async {
      // The difference from Watchlist/Watched, which are one state per title.
      MediaCollectionsService.create('Weekend');
      MediaCollectionsService.create('Sci-Fi');
      await openSheet(tester);

      await tester.tap(find.text('Weekend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sci-Fi'));
      await tester.pumpAndSettle();

      expect(MediaCollectionsService.containing(movie()), hasLength(2));
    });

    testWidgets('shows a count per collection', (tester) async {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, movie());
      await openSheet(tester);

      expect(find.text('1 title'), findsOneWidget);
    });

    testWidgets('offers no rename or delete -- those are Library-only', (
      tester,
    ) async {
      // Destructive actions belong where the collection is the subject of the
      // screen and you can see what you are about to destroy, not on a row you
      // opened to tick a box.
      MediaCollectionsService.create('Weekend');
      await openSheet(tester);

      expect(find.byIcon(Icons.delete_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
    });

    testWidgets('a long list scrolls rather than overflowing a phone', (
      tester,
    ) async {
      for (var i = 0; i < 30; i++) {
        MediaCollectionsService.create('Collection $i');
      }

      await openSheet(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long name ellipsizes instead of overflowing', (
      tester,
    ) async {
      MediaCollectionsService.create('A' * 200);

      await openSheet(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });
  });
}
