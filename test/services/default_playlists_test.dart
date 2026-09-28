import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/iptv/iptv_controller.dart';
import 'package:playtorriomov/services/iptv/iptv_settings.dart';

void main() {
  group('bundled playlists', () {
    test('six unique iptv-org lists with names', () {
      // A typo in one of these is a dead default nobody notices until a
      // user reports an empty shelf, so the exact set is pinned.
      expect(IptvController.defaultPlaylists.length, 6);
      final urls = IptvController.defaultPlaylists.values.toList();
      expect(urls.toSet().length, 6);
      for (final entry in IptvController.defaultPlaylists.entries) {
        expect(entry.key.trim(), isNotEmpty);
        expect(
          entry.value.startsWith('https://iptv-org.github.io/iptv/'),
          isTrue,
          reason: '${entry.value} is not an iptv-org list',
        );
        expect(entry.value.endsWith('.m3u'), isTrue);
      }
    });

    test('the seeded flag starts unset on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      IptvSettings.defaultPlaylistsSeeded = true;
      await IptvSettings.initialize();

      expect(IptvSettings.defaultPlaylistsSeeded, isFalse);
    });
  });
}
