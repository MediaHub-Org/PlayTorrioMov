// The device-code request once omitted `scope`, and Simkl answered with a
// read-only token instead of an error -- so Connect succeeded and every
// write after it (scrobble, watchlist, ratings) failed silently. The scope
// string is the whole fix, and this pins it without standing up the
// network the real request needs.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/simkl/simkl_service.dart';

void main() {
  group('SimklService.deviceRequestBody', () {
    test('asks for read and write together', () {
      final body = SimklService.deviceRequestBody();
      expect(body['scope'], 'media:read media:write');
    });

    test('carries the client id key', () {
      // The value is empty in tests (no .env) and filled at call time in
      // the app. What matters here is the key the token endpoint reads.
      expect(SimklService.deviceRequestBody(), contains('client_id'));
    });
  });
}
