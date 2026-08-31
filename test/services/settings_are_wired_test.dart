// test/services/settings_are_wired_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Settings services whose every persisted value should reach something.
const _settingsFiles = [
  'lib/services/music/music_settings.dart',
  'lib/services/audiobook/audiobook_settings.dart',
  'lib/services/iptv/iptv_settings.dart',
  'lib/services/manga/manga_settings.dart',
  'lib/services/player/player_settings.dart',
];

/// Settings that are deliberately read only by their own file — applied to a
/// player, or feeding another value in the same service — plus the notifiers
/// that exist to signal change rather than carry a setting.
const _appliedInOwnFile = {
  'changeNotifier',
  'audioDelayDefault', // applied in PlayerSettings.applyPreOpenProperties
  'hardwareAudioClock', // ditto, since 2026-08-31
};

List<String> _notifierNames(String source) => RegExp(
      r'static final ValueNotifier<[^>]+> (\w+)\s*=',
    ).allMatches(source).map((m) => m.group(1)!).toList();

void main() {
  group('persisted settings are actually used', () {
    // Three settings services had copy-pasted ambient-light, card-density and
    // player-chrome settings with no UI writing them and nothing reading them
    // -- 184 lines of pref keys, notifiers, loaders and setters that did
    // nothing. This catches the next one before it lands.
    for (final path in _settingsFiles) {
      test(path, () {
        final source = File(path).readAsStringSync();
        final unused = <String>[];

        for (final name in _notifierNames(source)) {
          if (_appliedInOwnFile.contains(name)) continue;

          // Read by any file other than the service that declares it?
          final referenced = Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart') && f.path != path)
              .any((f) => f.readAsStringSync().contains('.$name'));

          if (!referenced) unused.add(name);
        }

        expect(
          unused,
          isEmpty,
          reason: 'these settings are persisted but nothing outside '
              '$path reads them. Either wire them up, add them to '
              '_appliedInOwnFile with a note saying where they are applied, '
              'or delete them.',
        );
      });
    }
  });
}
