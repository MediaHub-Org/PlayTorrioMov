import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/backup/backup_service.dart';
import 'package:playtorriomov/services/backup/cloud_backup_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'a_string': 'hello',
      'a_bool': true,
      'an_int': 42,
      'a_double': 3.14,
      'a_list': ['x', 'y', 'z'],
    });
  });

  // Export and import now go through the system save/open dialogs, which a
  // unit test cannot drive. The part worth covering did not move: the
  // envelope is still what gets written and read, whether the destination
  // is a picked file or a WebDAV endpoint.
  test('the envelope round-trips every value type', () async {
    final json = await BackupService.buildEnvelopeJson();

    // A fresh install / different device: clear prefs, then restore.
    SharedPreferences.setMockInitialValues({});
    final restored = await BackupService.applyEnvelopeJson(json);
    expect(restored, 5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a_string'), 'hello');
    expect(prefs.getBool('a_bool'), true);
    expect(prefs.getInt('an_int'), 42);
    expect(prefs.getDouble('a_double'), 3.14);
    expect(prefs.getStringList('a_list'), ['x', 'y', 'z']);
  });

  test('the envelope is versioned and names the app that wrote it', () async {
    final envelope =
        jsonDecode(await BackupService.buildEnvelopeJson()) as Map;

    expect(envelope['version'], 1);
    expect(envelope['app'], isNotEmpty);
    expect(envelope['exportedAt'], isNotEmpty);
    expect(envelope['data'], isA<Map>());
  });

  test('a file that is not a backup is refused, not half-applied', () async {
    // Now that the user picks the file themselves, they can pick the wrong
    // one -- so the shape check matters more than it did when the path was
    // fixed.
    expect(
      BackupService.applyEnvelopeJson('not json at all'),
      throwsA(isA<FormatException>()),
    );
    expect(
      BackupService.applyEnvelopeJson('{"app":"x","version":1}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      BackupService.applyEnvelopeJson('[]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('keys absent from the backup are left alone', () async {
    final json = await BackupService.buildEnvelopeJson();

    SharedPreferences.setMockInitialValues({'kept': 'yes'});
    await BackupService.applyEnvelopeJson(json);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kept'), 'yes');
    expect(prefs.getString('a_string'), 'hello');
  });

  group('isPrivateOrLoopbackHost', () {
    test('accepts localhost and loopback', () {
      expect(isPrivateOrLoopbackHost('localhost'), isTrue);
      expect(isPrivateOrLoopbackHost('127.0.0.1'), isTrue);
    });

    test('accepts RFC1918 private ranges', () {
      expect(isPrivateOrLoopbackHost('192.168.1.50'), isTrue);
      expect(isPrivateOrLoopbackHost('10.0.0.5'), isTrue);
      expect(isPrivateOrLoopbackHost('172.16.0.1'), isTrue);
      expect(isPrivateOrLoopbackHost('172.31.255.255'), isTrue);
    });

    test('accepts .local mDNS hostnames', () {
      expect(isPrivateOrLoopbackHost('nas.local'), isTrue);
    });

    test('rejects a public IP or real hostname', () {
      expect(isPrivateOrLoopbackHost('8.8.8.8'), isFalse);
      expect(isPrivateOrLoopbackHost('cloud.example.com'), isFalse);
    });

    test('rejects an out-of-range 172.x address (not the /12 private block)', () {
      expect(isPrivateOrLoopbackHost('172.32.0.1'), isFalse);
      expect(isPrivateOrLoopbackHost('172.15.0.1'), isFalse);
    });
  });

  group('secure-URL enforcement (cloud backup)', () {
    test('uploadToCloud rejects plain http to a public host', () {
      expect(
        BackupService.uploadToCloud(
          const CloudBackupConfig(url: 'http://cloud.example.com/backup.json', username: 'u', password: 'p'),
        ),
        throwsException,
      );
    });

    test('downloadFromCloud rejects plain http to a public host', () {
      expect(
        BackupService.downloadFromCloud(
          const CloudBackupConfig(url: 'http://cloud.example.com/backup.json', username: 'u', password: 'p'),
        ),
        throwsException,
      );
    });
  });
}
