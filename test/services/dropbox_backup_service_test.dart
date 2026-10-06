// test/services/dropbox_backup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/backup/dropbox_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('beginAuthorization', () {
    test('builds a PKCE authorize URL with no redirect_uri', () async {
      final url = await DropboxBackupService.beginAuthorization();
      final uri = Uri.parse(url);

      expect(uri.host, 'www.dropbox.com');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(uri.queryParameters['token_access_type'], 'offline');
      expect(uri.queryParameters['code_challenge'], isNotEmpty);
      // No redirect_uri at all -- that absence is what makes Dropbox show
      // the code on screen instead of trying to redirect anywhere.
      expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
    });

    test('a fresh challenge every call -- the verifier is not reused', () async {
      final first = Uri.parse(await DropboxBackupService.beginAuthorization());
      final second = Uri.parse(await DropboxBackupService.beginAuthorization());
      expect(
        first.queryParameters['code_challenge'],
        isNot(second.queryParameters['code_challenge']),
      );
    });
  });

  group('connectWithCode', () {
    test('an empty/blank code is rejected before any network call', () async {
      await DropboxBackupService.beginAuthorization();
      expect(
        () => DropboxBackupService.connectWithCode('   '),
        throwsA(isA<Exception>()),
      );
    });

    test('no prior beginAuthorization means no pending verifier to match',
        () async {
      // A fresh install's SharedPreferences, never having called
      // beginAuthorization in this process.
      expect(
        () => DropboxBackupService.connectWithCode('some-code'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('isAuthenticated / logout', () {
    test('not connected by default, and stays that way after a no-op logout',
        () async {
      expect(await DropboxBackupService.isAuthenticated(), isFalse);
      await DropboxBackupService.logout();
      expect(await DropboxBackupService.isAuthenticated(), isFalse);
    });
  });
}
