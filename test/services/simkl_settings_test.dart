import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/simkl/simkl_constants.dart';
import 'package:playtorriomov/services/simkl/simkl_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These assertions describe a build with no Simkl id compiled in, which is
/// every published build -- the ENV_FILE secret is not set. A developer who
/// exports SIMKL_CLIENT_ID locally would see the other branch, so the few
/// assertions that depend on it skip rather than fail there.
final String? _skipIfBundled = SimklSettings.bundledClientId == null
    ? null
    : 'SIMKL_CLIENT_ID is set in this environment; this covers builds without one';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SimklSettings.resetForTest();
  });

  group('SimklSettings client id', () {
    test('a build with no .env has nothing to sign in with', () {
      // Which is every published build: the ENV_FILE secret is not set, so
      // Connect could only ever fail. This is the state the card has to
      // explain rather than retry.
      expect(SimklSettings.bundledClientId, isNull);
      expect(SimklSettings.isConfigured, isFalse);
      expect(SimklSettings.needsUserClientId, isTrue);
    }, skip: _skipIfBundled);

    test("the user's own id makes Simkl available", () async {
      await SimklSettings.setClientId('abc123');

      expect(SimklSettings.effectiveClientId, 'abc123');
      expect(SimklSettings.isConfigured, isTrue);
      expect(SimklSettings.needsUserClientId, isFalse);
      // And it is what requests actually carry.
      expect(kSimklClientId, 'abc123');
    });

    test('an empty or blank id counts as no id', () async {
      await SimklSettings.setClientId('   ');
      expect(SimklSettings.clientId.value, isNull);

      await SimklSettings.setClientId('');
      expect(SimklSettings.clientId.value, isNull);
      expect(SimklSettings.isConfigured, isFalse);
    }, skip: _skipIfBundled);

    test('an id is trimmed, because pasting picks up whitespace', () async {
      await SimklSettings.setClientId('  abc123\n');
      expect(SimklSettings.effectiveClientId, 'abc123');
    });

    test('clearing it goes back to unconfigured', () async {
      await SimklSettings.setClientId('abc123');
      await SimklSettings.setClientId(null);

      expect(SimklSettings.isConfigured, isFalse);
      expect(kSimklClientId, '');
    }, skip: _skipIfBundled);

    test('it survives a restart', () async {
      await SimklSettings.setClientId('abc123');

      SimklSettings.resetForTest();
      expect(SimklSettings.clientId.value, isNull);

      await SimklSettings.initialize();
      expect(SimklSettings.clientId.value, 'abc123');
    });

    test('kSimklClientId is empty, not null, when nothing is set', () {
      // Callers interpolate it into a query string, so it has to be a
      // String. The guard against sending it is isConfigured, not a null
      // check at the call site.
      expect(kSimklClientId, '');
    }, skip: _skipIfBundled);
  });

  group('SimklSettings.describeStatus', () {
    test('a rejected id names the thing the user can change', () {
      for (final code in [401, 403]) {
        final message = SimklSettings.describeStatus(code);
        expect(message, contains('$code'));
        expect(message, contains('client ID'));
        expect(message, contains('simkl.com/settings/developer'));
      }
    });

    test('rate limiting reads as temporary, not as a broken id', () {
      final message = SimklSettings.describeStatus(429);
      expect(message, contains('429'));
      expect(message, contains('again'));
      expect(message, isNot(contains('client ID')));
    });

    test('an unrecognised code still says something concrete', () {
      expect(SimklSettings.describeStatus(503), contains('503'));
    });
  });

  group('SimklSettings.lastStatus', () {
    test('starts empty, so the card shows nothing before an attempt', () {
      expect(SimklSettings.lastStatus.value, isNull);
    });

    test('notifies listeners, because the card rebuilds on it', () {
      var notifications = 0;
      void listener() => notifications++;
      SimklSettings.lastStatus.addListener(listener);
      addTearDown(() => SimklSettings.lastStatus.removeListener(listener));

      SimklSettings.note('something happened');

      expect(notifications, 1);
      expect(SimklSettings.lastStatus.value, 'something happened');
    });
  });
}
