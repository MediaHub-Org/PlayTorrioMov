// test/services/discord_rpc_default_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/discord/discord_rpc_service.dart';

void main() {
  group('Discord Rich Presence', () {
    test('is off until the user turns it on', () {
      // Rich Presence publishes the title of whatever you are watching,
      // reading or listening to, to everyone who can see your Discord
      // profile. Upstream ships this defaulting to on; this fork does not.
      // Pinned by a test because it is a one-word divergence that a future
      // upstream merge would silently revert.
      expect(DiscordRpcService.instance.isEnabled.value, isFalse);
    });

    test('the persisted preference also defaults off', () {
      final source =
          File('lib/services/discord/discord_rpc_service.dart').readAsStringSync();
      expect(
        source.contains('prefs.getBool(_prefKey) ?? false'),
        isTrue,
        reason: 'a stored-preference default of true would re-enable it on '
            'every install that has never touched the toggle',
      );
    });
  });
}
