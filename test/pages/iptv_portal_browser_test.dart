import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/iptv/m3u_models.dart';
import 'package:playtorriomov/pages/iptv/iptv_portal_browser_page.dart';

M3uPlaylist playlist(List<M3uChannel> channels) => M3uPlaylist(
      id: 'pl',
      name: 'Test',
      sourceUrl: 'https://example.com/list.m3u',
      addedAt: 0,
      updatedAt: 0,
      channels: channels,
    );

M3uChannel channel(String name, String group) =>
    M3uChannel(name: name, url: 'https://example.com/$name', group: group);

void main() {
  group('expandM3uGroups', () {
    test('a ;-joined group becomes one shelf per group', () {
      final entries = expandM3uGroups(
        playlist([channel('Feed', 'News;Public')]),
      );

      expect(entries.map((e) => e.$1).toList(), ['News', 'Public']);
      // The same channel under both, the way a TV guide lists it twice.
      expect(entries.map((e) => e.$2.name).toList(), ['Feed', 'Feed']);
      expect(entries.map((e) => e.$2.categoryId).toList(), ['News', 'Public']);
    });

    test('whitespace around groups does not leak into names', () {
      final entries = expandM3uGroups(
        playlist([channel('Feed', '  Sports ; Live  ')]),
      );

      expect(entries.map((e) => e.$1).toList(), ['Sports', 'Live']);
    });

    test('an ungrouped channel pools under General, as before', () {
      final entries = expandM3uGroups(playlist([channel('Feed', '')]));

      expect(entries.map((e) => e.$1).toList(), ['General']);
    });
  });

  group('regionPrefixOf', () {
    test('reads the region off prefixed shelves', () {
      expect(regionPrefixOf('AR | Sports'), 'AR');
      expect(regionPrefixOf('UK: News'), 'UK');
      expect(regionPrefixOf('us - Movies'), 'US');
    });

    test('plain names are regionless', () {
      expect(regionPrefixOf('Sports'), isNull);
      expect(regionPrefixOf('beIN Sports'), isNull);
      expect(regionPrefixOf('24/7 News'), isNull);
      expect(regionPrefixOf(''), isNull);
    });
  });
}
