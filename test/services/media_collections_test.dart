// test/services/media_collections_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/services/collections/media_collections_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

MyListItem item(String title, {String? imdb, String type = 'movie'}) =>
    MyListItem(
      title: title,
      type: type,
      imdbId: imdb,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MediaCollectionsService.resetForTest();
  });

  group('create', () {
    test('makes a collection and returns it', () {
      final made = MediaCollectionsService.create('Weekend');

      expect(made, isNotNull);
      expect(made!.name, 'Weekend');
      expect(made.isEmpty, isTrue);
      expect(MediaCollectionsService.collections.value, hasLength(1));
    });

    test('trims the name, and refuses one that is only spaces', () {
      expect(MediaCollectionsService.create('  Sci-Fi  ')!.name, 'Sci-Fi');
      expect(MediaCollectionsService.create('   '), isNull);
      expect(MediaCollectionsService.create(''), isNull);
      expect(MediaCollectionsService.collections.value, hasLength(1));
    });

    test('allows two collections with the same name', () {
      // Two lists called "Weekend" are the user's business; the id addresses
      // them, not the label.
      final a = MediaCollectionsService.create('Weekend');
      final b = MediaCollectionsService.create('Weekend');

      expect(a!.id, isNot(b!.id));
      expect(MediaCollectionsService.collections.value, hasLength(2));
    });
  });

  group('adding and removing titles', () {
    test('a title goes in once, however many times it is added', () {
      final c = MediaCollectionsService.create('Weekend')!;
      final movie = item('A Movie', imdb: 'tt1');

      expect(MediaCollectionsService.addItem(c.id, movie), isTrue);
      expect(MediaCollectionsService.addItem(c.id, movie), isFalse,
          reason: 'already there');
      expect(MediaCollectionsService.byId(c.id)!.count, 1);
    });

    test('the same title is recognized across providers by its IMDb id', () {
      // Identity comes from MyListItem.uniqueKey, which prefers IMDb over
      // every other id. A title added from a Trakt payload and the same one
      // from a TMDB catalog must not both land in the list.
      final c = MediaCollectionsService.create('Weekend')!;
      final fromOne = MyListItem(
        title: 'A Movie',
        type: 'movie',
        imdbId: 'tt1',
        traktId: 99,
        addedAt: DateTime(2026, 1, 1),
      );
      final fromAnother = MyListItem(
        title: 'A Movie (2019)',
        type: 'movie',
        imdbId: 'tt1',
        tmdbId: 1234,
        addedAt: DateTime(2026, 2, 2),
      );

      MediaCollectionsService.addItem(c.id, fromOne);
      expect(MediaCollectionsService.addItem(c.id, fromAnother), isFalse);
      expect(MediaCollectionsService.byId(c.id)!.count, 1);
    });

    test('a title can be in several collections at once', () {
      // The difference from Liked/Watchlist/Watched, which are one state per
      // title. Here membership is many-to-many.
      final a = MediaCollectionsService.create('Weekend')!;
      final b = MediaCollectionsService.create('Sci-Fi')!;
      final movie = item('A Movie', imdb: 'tt1');

      MediaCollectionsService.addItem(a.id, movie);
      MediaCollectionsService.addItem(b.id, movie);

      expect(MediaCollectionsService.containing(movie), hasLength(2));
    });

    test('movies, series and anime share one collection', () {
      final c = MediaCollectionsService.create('Mixed')!;
      MediaCollectionsService.addItem(c.id, item('A', imdb: 'tt1'));
      MediaCollectionsService.addItem(
        c.id,
        item('B', imdb: 'tt2', type: 'series'),
      );
      MediaCollectionsService.addItem(
        c.id,
        item('C', imdb: 'tt3', type: 'anime'),
      );

      expect(MediaCollectionsService.byId(c.id)!.count, 3);
    });

    test('removing takes it out of that collection only', () {
      final a = MediaCollectionsService.create('Weekend')!;
      final b = MediaCollectionsService.create('Sci-Fi')!;
      final movie = item('A Movie', imdb: 'tt1');
      MediaCollectionsService.addItem(a.id, movie);
      MediaCollectionsService.addItem(b.id, movie);

      expect(MediaCollectionsService.removeItem(a.id, movie), isTrue);

      expect(MediaCollectionsService.byId(a.id)!.isEmpty, isTrue);
      expect(MediaCollectionsService.byId(b.id)!.count, 1);
    });

    test('removeItemEverywhere clears it from all of them', () {
      final a = MediaCollectionsService.create('Weekend')!;
      final b = MediaCollectionsService.create('Sci-Fi')!;
      final movie = item('A Movie', imdb: 'tt1');
      MediaCollectionsService.addItem(a.id, movie);
      MediaCollectionsService.addItem(b.id, movie);

      expect(MediaCollectionsService.removeItemEverywhere(movie), 2);
      expect(MediaCollectionsService.containing(movie), isEmpty);
    });

    test('an unknown collection id is refused, not created', () {
      expect(
        MediaCollectionsService.addItem('nope', item('A', imdb: 'tt1')),
        isFalse,
      );
      expect(MediaCollectionsService.collections.value, isEmpty);
    });
  });

  group('rename and delete', () {
    test('rename trims, and refuses blank', () {
      final c = MediaCollectionsService.create('Weekend')!;

      expect(MediaCollectionsService.rename(c.id, '  Friday  '), isTrue);
      expect(MediaCollectionsService.byId(c.id)!.name, 'Friday');
      expect(MediaCollectionsService.rename(c.id, '  '), isFalse);
      expect(MediaCollectionsService.byId(c.id)!.name, 'Friday');
    });

    test('delete removes only that collection', () {
      final a = MediaCollectionsService.create('Weekend')!;
      final b = MediaCollectionsService.create('Sci-Fi')!;

      expect(MediaCollectionsService.delete(a.id), isTrue);
      expect(MediaCollectionsService.byId(a.id), isNull);
      expect(MediaCollectionsService.byId(b.id), isNotNull);
    });

    test('deleting an unknown id changes nothing', () {
      MediaCollectionsService.create('Weekend');
      expect(MediaCollectionsService.delete('nope'), isFalse);
      expect(MediaCollectionsService.collections.value, hasLength(1));
    });
  });

  group('reorder', () {
    test('moves an entry and keeps the rest in order', () {
      final c = MediaCollectionsService.create('Weekend')!;
      for (var i = 1; i <= 3; i++) {
        MediaCollectionsService.addItem(c.id, item('M$i', imdb: 'tt$i'));
      }

      expect(MediaCollectionsService.reorder(c.id, 2, 0), isTrue);

      expect(
        MediaCollectionsService.byId(c.id)!.items.map((i) => i.title),
        ['M3', 'M1', 'M2'],
      );
    });

    test('a drag that ends outside the list is a no-op, not a crash', () {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, item('M1', imdb: 'tt1'));

      expect(MediaCollectionsService.reorder(c.id, 0, 5), isFalse);
      expect(MediaCollectionsService.reorder(c.id, -1, 0), isFalse);
      expect(MediaCollectionsService.reorder(c.id, 0, 0), isFalse);
      expect(MediaCollectionsService.byId(c.id)!.count, 1);
    });
  });

  group('ordering and cover art', () {
    test('the most recently touched collection comes first', () {
      // What the Library grid wants, and why every mutation moves updatedAt.
      MediaCollectionsService.create('First');
      final second = MediaCollectionsService.create('Second')!;
      MediaCollectionsService.create('Third');

      MediaCollectionsService.rename(second.id, 'Second again');

      expect(
        MediaCollectionsService.collections.value.first.name,
        'Second again',
      );
    });

    test('the cover is the first entry that actually has a poster', () {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, item('No art', imdb: 'tt1'));
      MediaCollectionsService.addItem(
        c.id,
        MyListItem(
          title: 'Has art',
          type: 'movie',
          imdbId: 'tt2',
          poster: 'https://x/p.jpg',
          addedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(MediaCollectionsService.byId(c.id)!.coverPoster, 'https://x/p.jpg');
    });

    test('an empty collection has no cover and is not hidden', () {
      final c = MediaCollectionsService.create('Weekend')!;
      expect(MediaCollectionsService.byId(c.id)!.coverPoster, isNull);
      expect(MediaCollectionsService.byId(c.id)!.mosaicPosters, isEmpty);
    });
  });

  group('stored shape', () {
    test('survives a round trip through JSON', () {
      final c = MediaCollectionsService.create('Weekend')!;
      MediaCollectionsService.addItem(c.id, item('A Movie', imdb: 'tt1'));

      final restored = MediaCollectionsService.decode(
        MediaCollectionsService.encode(MediaCollectionsService.collections.value),
      );

      expect(restored, hasLength(1));
      expect(restored.single.name, 'Weekend');
      expect(restored.single.items.single.title, 'A Movie');
      expect(restored.single.id, c.id);
    });

    test('a corrupt blob yields no collections rather than throwing', () {
      expect(MediaCollectionsService.decode('not json'), isEmpty);
      expect(MediaCollectionsService.decode(''), isEmpty);
      expect(MediaCollectionsService.decode('{}'), isEmpty);
      expect(MediaCollectionsService.decode('[1,2,3]'), isEmpty);
    });

    test('one unreadable collection does not discard the others', () {
      final good = MediaCollectionsService.create('Keep me')!;
      final encoded = MediaCollectionsService.encode([good]);
      // Splice a junk entry in beside the real one.
      final spliced = '[${'{"id":""}'},${encoded.substring(1)}';

      final restored = MediaCollectionsService.decode(spliced);

      expect(restored, hasLength(1), reason: 'the id-less entry is dropped');
      expect(restored.single.name, 'Keep me');
    });

    test('a collection with an unparseable date still loads', () {
      final restored = MediaCollectionsService.decode(
        '[{"id":"x","name":"Weekend","createdAt":"nonsense",'
        '"updatedAt":"nonsense","items":[]}]',
      );

      expect(restored, hasLength(1));
      expect(restored.single.name, 'Weekend');
    });

    test('an entry that will not parse is skipped, not the whole list', () {
      final restored = MediaCollectionsService.decode(
        '[{"id":"x","name":"Weekend","createdAt":"2026-01-01T00:00:00.000",'
        '"updatedAt":"2026-01-01T00:00:00.000","items":["not an object"]}]',
      );

      expect(restored, hasLength(1));
      expect(restored.single.isEmpty, isTrue);
    });
  });
}
