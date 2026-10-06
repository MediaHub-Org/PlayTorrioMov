// test/services/google_drive_backup_service_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/backup/google_drive_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('authorizeUrl', () {
    test('points at Google with a loopback redirect and offline PKCE', () {
      final url = GoogleDriveBackupService.authorizeUrl(
        clientId: 'test-id',
        redirectUri: 'http://127.0.0.1:51234',
        challenge: 'test-challenge',
      );
      final uri = Uri.parse(url);

      expect(uri.host, 'accounts.google.com');
      expect(uri.queryParameters['client_id'], 'test-id');
      expect(uri.queryParameters['response_type'], 'code');
      // Loopback, so no redirect URI ever needs pre-registering.
      expect(uri.queryParameters['redirect_uri'], 'http://127.0.0.1:51234');
      expect(
        uri.queryParameters['scope'],
        'https://www.googleapis.com/auth/drive.file',
      );
      expect(uri.queryParameters['access_type'], 'offline');
      expect(uri.queryParameters['prompt'], 'consent');
      expect(uri.queryParameters['code_challenge'], 'test-challenge');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
    });
  });

  group('findBackupFileId', () {
    test('returns the first file id', () {
      expect(
        GoogleDriveBackupService.findBackupFileId({
          'files': [
            {'id': 'abc123', 'name': 'playtorrio-backup.json'},
          ],
        }),
        'abc123',
      );
    });

    test('no file, or an unexpected shape, means not found -- never a crash',
        () {
      expect(GoogleDriveBackupService.findBackupFileId({'files': []}), isNull);
      expect(GoogleDriveBackupService.findBackupFileId({}), isNull);
      expect(GoogleDriveBackupService.findBackupFileId(null), isNull);
      expect(
        GoogleDriveBackupService.findBackupFileId('garbage'),
        isNull,
      );
      expect(
        GoogleDriveBackupService.findBackupFileId({
          'files': [
            {'id': ''},
          ],
        }),
        isNull,
      );
      expect(
        GoogleDriveBackupService.findBackupFileId({
          'files': ['not-a-file-object'],
        }),
        isNull,
      );
    });
  });

  group('buildUploadMultipart', () {
    test('metadata, then the envelope verbatim, inside the boundary', () {
      const envelope = '{"v":1,"keys":{"nick":"Jürgen 🎬"}}';
      final body = GoogleDriveBackupService.buildUploadMultipart(
        envelopeJson: envelope,
        boundary: 'test-boundary',
      );

      expect(body, isA<Uint8List>());
      // Decoded as UTF-8, the way the download path reads it back: byte
      // values are not characters, so `fromCharCodes` would mojibake every
      // non-ASCII library name here and lie about the corruption.
      final text = utf8.decode(body);
      expect(text.indexOf('--test-boundary'), 0);
      expect(text, contains('"name": "playtorrio-backup.json"'));
      // Verbatim, including non-ASCII: the envelope is decoded as UTF-8 on
      // the way back, so any mangling here corrupts library names.
      expect(text, contains(envelope));
      expect(text.trimRight(), endsWith('--test-boundary--'));
    });
  });

  group('begin/cancelAuthorization', () {
    test('cancel with nothing pending is a no-op', () async {
      await GoogleDriveBackupService.cancelAuthorization();
    });

    test('begin binds a loopback server; cancel closes it', () async {
      final url = await GoogleDriveBackupService.beginAuthorization();
      try {
        final uri = Uri.parse(url);
        expect(
          uri.queryParameters['redirect_uri'],
          startsWith('http://127.0.0.1:'),
        );
      } finally {
        await GoogleDriveBackupService.cancelAuthorization();
      }
    });
  });

  group('isAuthenticated / logout', () {
    test('not connected by default, and stays that way after a no-op logout',
        () async {
      expect(await GoogleDriveBackupService.isAuthenticated(), isFalse);
      await GoogleDriveBackupService.logout();
      expect(await GoogleDriveBackupService.isAuthenticated(), isFalse);
    });
  });
}
