// test/services/favorite_channels_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/iptv/favorite_channels_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FavoriteChannelsService.items.value = [];
  });

  group('FavoriteChannelsService.resolvedChannels', () {
    // This is what the Live TV page's Liked row renders. Liked channels used
    // to appear only in Library, which is the wrong place: you go to Library
    // to manage what you saved, and to Live TV to actually watch.
    test('is empty when nothing is liked', () {
      expect(FavoriteChannelsService.resolvedChannels, isEmpty);
    });

    test('resolves a liked id back to its catalog entry', () async {
      await FavoriteChannelsService.toggle('ufc');

      final resolved = FavoriteChannelsService.resolvedChannels;
      expect(resolved.length, 1);
      expect(resolved.single.id, 'ufc');
      // The row shows the catalog's own name and art, looked up by id --
      // the store persists only the id and a timestamp.
      expect(resolved.single.name, isNotEmpty);
    });

    test('most recently liked comes first', () async {
      await FavoriteChannelsService.toggle('ufc');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await FavoriteChannelsService.toggle('wwe');

      expect(
        FavoriteChannelsService.resolvedChannels.map((c) => c.id).toList(),
        ['wwe', 'ufc'],
      );
    });

    test('un-liking drops it from the row', () async {
      await FavoriteChannelsService.toggle('ufc');
      expect(FavoriteChannelsService.isFavorite('ufc'), isTrue);

      await FavoriteChannelsService.toggle('ufc');

      expect(FavoriteChannelsService.isFavorite('ufc'), isFalse);
      expect(FavoriteChannelsService.resolvedChannels, isEmpty);
    });

    test('an id no longer in the catalog is skipped, not rendered blank', () async {
      // The catalog is static app data that changes between releases, so a
      // stored id can outlive its entry. resolvedChannels drops those rather
      // than emitting a null the row would have to handle.
      await FavoriteChannelsService.toggle('ufc');
      await FavoriteChannelsService.toggle('a-channel-that-no-longer-exists');

      final ids = FavoriteChannelsService.resolvedChannels.map((c) => c.id);
      expect(ids, ['ufc']);
    });
  });
}
