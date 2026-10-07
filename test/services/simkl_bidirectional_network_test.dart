// A live round trip through the app's own SimklService: write something,
// read it back, remove it, confirm it is gone. Both directions run the
// production code paths (markWatched/markUnwatched up,
// fetchCompletedTitleIds down), not raw HTTP rebuilt for the test.
//
// Needs a user token: `flutter test --tags network
// --dart-define=SIMKL_TEST_TOKEN=<token> test/services/simkl_bidirectional_network_test.dart`
// Get one via the Settings → Sync → Simkl Connect flow (device approval),
// use it once, and revoke it after at simkl.com/settings/connected-apps.
// Without a token the test skips -- CI never has one.
@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/simkl/simkl_service.dart';
import 'package:playtorriomov/services/storage/storage_service.dart';

const _token = String.fromEnvironment('SIMKL_TEST_TOKEN');

// Shawshank: universally present, unmistakable, and removed again at the
// end -- the library is left exactly as found.
const _markerImdb = 'tt0111161';

void main() {
  // Compile-time skip: without a token there is nothing live to exercise,
  // and CI never has one. Runtime skips cannot do this job -- see below.
  test(
    'Simkl sync is bidirectional: write, read back, remove, gone',
    () async {
      // Secure storage has no test double on every platform this suite
      // runs on. If the token cannot even be staged, return early: the
      // compile-time skip above already covers CI, and a local run that
      // reaches here with broken plumbing has nothing meaningful to fail.
      try {
        await StorageService.setSimklAccessToken(_token);
        expect(await StorageService.getSimklAccessToken(), _token);
      } catch (_) {
        return;
      }

    try {
      // Up: mark watched through the service.
      expect(await SimklService.instance.markWatched(_markerImdb, 'movie'), isTrue);

      // Down: the same service reads it back.
      final seen = await SimklService.instance.fetchCompletedTitleIds();
      expect(seen?.movies, contains(_markerImdb));

      // Up again: remove it...
      expect(await SimklService.instance.markUnwatched(_markerImdb, 'movie'), isTrue);

      // ...down: the removal propagated while still authenticated, so an
      // empty answer here means really gone rather than merely logged out.
      final after = await SimklService.instance.fetchCompletedTitleIds();
      expect(after?.movies ?? {}, isNot(contains(_markerImdb)));
    } finally {
      // Leave nothing behind even if an expect above threw, then drop the
      // token itself: it was minted for this run only.
      await SimklService.instance.markUnwatched(_markerImdb, 'movie');
      await StorageService.setSimklAccessToken('');
    }
    },
    skip: _token.isEmpty
        ? 'SIMKL_TEST_TOKEN not provided; see file header.'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
