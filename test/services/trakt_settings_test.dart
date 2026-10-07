import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/trakt/trakt_constants.dart';
import 'package:playtorriomov/services/trakt/trakt_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These assertions describe a build with no Trakt credentials compiled in,
/// which is every published build -- the ENV_FILE secret is not set. A
/// developer who exports TRAKT_CLIENT_ID locally would see the other
/// branch, so the few assertions that depend on it skip rather than fail
/// there.
final String? _skipIfBundled = TraktSettings.bundledClientId == null
    ? null
    : 'TRAKT_CLIENT_ID is set in this environment; this covers builds without one';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TraktSettings.resetForTest();
  });

  group('TraktSettings credentials', () {
    test('a build with no .env has nothing to sign in with', () {
      // Which is every published build: the ENV_FILE secret is not set, so
      // Connect could only ever fail. This is the state the card has to
      // explain rather than retry.
      expect(TraktSettings.bundledClientId, isNull);
      expect(TraktSettings.bundledClientSecret, isNull);
      expect(TraktSettings.isConfigured, isFalse);
      expect(TraktSettings.needsUserCredentials, isTrue);
    }, skip: _skipIfBundled);

    test("the user's own credentials make Trakt available", () async {
      await TraktSettings.setClientId('user-id-0123456789abcdef');
      await TraktSettings.setClientSecret('user-secret-0123456789abcdef');

      expect(
        TraktSettings.effectiveClientId,
        'user-id-0123456789abcdef',
      );
      expect(
        TraktSettings.effectiveClientSecret,
        'user-secret-0123456789abcdef',
      );
      expect(TraktSettings.isConfigured, isTrue);
      expect(TraktSettings.needsUserCredentials, isFalse);
      // And they are what requests actually carry.
      expect(kTraktClientId, 'user-id-0123456789abcdef');
      expect(kTraktClientSecret, 'user-secret-0123456789abcdef');
    });

    test('an ID without a secret is still unconfigured', () async {
      // The device-token poll sends both, so half a pair configures
      // nothing -- the card must keep asking instead of failing at Connect.
      await TraktSettings.setClientId('user-id-0123456789abcdef');
      expect(TraktSettings.isConfigured, isFalse);
    });

    test('empty or blank values count as unset', () async {
      await TraktSettings.setClientId('   ');
      await TraktSettings.setClientSecret('');
      expect(TraktSettings.clientId.value, isNull);
      expect(TraktSettings.clientSecret.value, isNull);
      expect(TraktSettings.isConfigured, isFalse);
    }, skip: _skipIfBundled);

    test('values are trimmed, because pasting picks up whitespace', () async {
      await TraktSettings.setClientId('  user-id-0123456789abcdef\n');
      await TraktSettings.setClientSecret('\tuser-secret-0123456789abcdef  ');
      expect(
        TraktSettings.effectiveClientId,
        'user-id-0123456789abcdef',
      );
      expect(
        TraktSettings.effectiveClientSecret,
        'user-secret-0123456789abcdef',
      );
    });

    test('clearing both goes back to unconfigured', () async {
      await TraktSettings.setClientId('user-id-0123456789abcdef');
      await TraktSettings.setClientSecret('user-secret-0123456789abcdef');
      await TraktSettings.setClientId(null);
      await TraktSettings.setClientSecret(null);

      expect(TraktSettings.isConfigured, isFalse);
    });
  });

  group('TraktSettings.looksLikeCredential', () {
    test('rejects URLs, sentences and short fragments', () {
      expect(
        TraktSettings.looksLikeCredential(
          'https://trakt.tv/oauth/applications',
        ),
        isFalse,
      );
      expect(TraktSettings.looksLikeCredential('my secret'), isFalse);
      expect(TraktSettings.looksLikeCredential('abc123'), isFalse);
    });

    test('accepts a real-shaped credential', () {
      expect(
        TraktSettings.looksLikeCredential(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        isTrue,
      );
    });
  });
}
