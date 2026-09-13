import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/iptv/custom_channels_service.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CustomChannelsService.initialize();
  });

  group('building a channel from a stream', () {
    test('the stream name becomes the name and the keyword', () async {
      // A channel tile is a saved search, not a bookmark: it finds that
      // stream again, and any other stream named like it, across portals.
      final channel = await CustomChannelsService.addFromStream(
        streamName: 'FR: CANAL+ FOOTBALL HD',
      );

      expect(channel, isNotNull);
      expect(channel!.name, 'FR: CANAL+ FOOTBALL HD');
      expect(channel.keywords, ['fr: canal+ football hd']);
      expect(channel.id.startsWith(CustomChannelsService.idPrefix), isTrue);
    });

    test('it lands in the registry, so a lookup by id finds it', () async {
      // Everything downstream resolves a channel by id -- its Liked entry
      // included. A custom channel the registry does not know about would
      // resolve to null and silently vanish from Library.
      final channel = await CustomChannelsService.addFromStream(
        streamName: 'My Local Sports',
      );

      expect(HardcodedChannels.byId(channel!.id), isNotNull);
      expect(HardcodedChannels.byId(channel.id)!.name, 'My Local Sports');
      expect(HardcodedChannels.everything, contains(channel));
    });

    test('built-ins are still there alongside', () async {
      await CustomChannelsService.addFromStream(streamName: 'Mine');

      expect(HardcodedChannels.byId('ufc'), isNotNull);
      expect(
        HardcodedChannels.everything.length,
        HardcodedChannels.all.length + 1,
      );
    });

    test('the same stream twice is one tile, not two', () async {
      final first = await CustomChannelsService.addFromStream(
        streamName: 'Sky Sports Main Event',
      );
      final second = await CustomChannelsService.addFromStream(
        streamName: 'Sky Sports Main Event',
      );

      expect(CustomChannelsService.items.value, hasLength(1));
      expect(second!.id, first!.id);
    });

    test('names differing only by case or punctuation are one channel', () {
      // To a viewer these are the same channel, so they get the same id and
      // the second one does not make a duplicate.
      expect(
        CustomChannelsService.slugForTest('Sky Sports!'),
        CustomChannelsService.slugForTest('sky   sports'),
      );
      expect(CustomChannelsService.slugForTest('  '), 'channel');
      expect(CustomChannelsService.slugForTest('ESPN 2'), 'espn_2');
    });

    test('an empty name is refused rather than making a blank tile', () async {
      expect(await CustomChannelsService.addFromStream(streamName: '   '), isNull);
      expect(CustomChannelsService.items.value, isEmpty);
    });

    test('the category carries over, defaulting when blank', () async {
      final filed = await CustomChannelsService.addFromStream(
        streamName: 'A',
        category: 'Sports',
      );
      final unfiled = await CustomChannelsService.addFromStream(
        streamName: 'B',
        category: '   ',
      );

      expect(filed!.category, 'Sports');
      expect(unfiled!.category, 'Custom');
      expect(CustomChannelsService.categories, ['Sports', 'Custom']);
    });
  });

  group('persistence', () {
    test('channels survive a restart', () async {
      await CustomChannelsService.addFromStream(streamName: 'Kept Channel');

      // A fresh load off the same store, as a restart would do.
      await CustomChannelsService.initialize();

      expect(CustomChannelsService.items.value, hasLength(1));
      expect(CustomChannelsService.items.value.single.name, 'Kept Channel');
      expect(HardcodedChannels.custom, hasLength(1));
    });

    test('a corrupt store loses the custom channels, not the page', () async {
      SharedPreferences.setMockInitialValues({
        'pt_custom_channels_v1': 'not json at all',
      });

      await CustomChannelsService.initialize();

      expect(CustomChannelsService.items.value, isEmpty);
      expect(HardcodedChannels.byId('ufc'), isNotNull);
    });

    test('a stored channel with no keywords falls back to its name', () async {
      // A channel with no keywords matches no stream at all, which is a
      // tile that can never do anything.
      SharedPreferences.setMockInitialValues({
        'pt_custom_channels_v1':
            '[{"id":"custom:x","name":"Some Channel","keywords":[]}]',
      });

      await CustomChannelsService.initialize();

      expect(CustomChannelsService.items.value.single.keywords, [
        'some channel',
      ]);
    });

    test('a nameless stored entry is dropped', () async {
      SharedPreferences.setMockInitialValues({
        'pt_custom_channels_v1': '[{"id":"custom:x"},{"name":"No id"}]',
      });

      await CustomChannelsService.initialize();

      expect(CustomChannelsService.items.value, isEmpty);
    });
  });

  group('removal', () {
    test('removing takes it out of the registry too', () async {
      final channel = await CustomChannelsService.addFromStream(
        streamName: 'Temporary',
      );

      await CustomChannelsService.remove(channel!.id);

      expect(CustomChannelsService.items.value, isEmpty);
      expect(HardcodedChannels.byId(channel.id), isNull);
      expect(HardcodedChannels.byId('ufc'), isNotNull);
    });

    test('removing something that is not there changes nothing', () async {
      await CustomChannelsService.addFromStream(streamName: 'Kept');

      await CustomChannelsService.remove('custom:not_here');

      expect(CustomChannelsService.items.value, hasLength(1));
    });

    test('isCustom tells the two kinds apart', () {
      expect(CustomChannelsService.isCustom('custom:anything'), isTrue);
      expect(CustomChannelsService.isCustom('ufc'), isFalse);
    });
  });

  group('matching', () {
    test('a custom channel matches the stream it was built from', () async {
      final channel = await CustomChannelsService.addFromStream(
        streamName: 'BT Sport 1',
      );

      // The same matcher the built-in channels use -- that is the point of
      // a custom channel being the same record.
      expect(
        HardcodedChannels.matches('UK: BT SPORT 1 FHD', channel!.keywords),
        isTrue,
      );
      expect(
        HardcodedChannels.matches('UK: SKY SPORTS F1', channel.keywords),
        isFalse,
      );
    });
  });
}
