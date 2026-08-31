import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorrio/services/backup/backup_service.dart';
import 'package:playtorrio/services/backup/cloud_backup_settings.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempDir);
  final Directory tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playtorrio_backup_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues({
      'a_string': 'hello',
      'a_bool': true,
      'an_int': 42,
      'a_double': 3.14,
      'a_list': ['x', 'y', 'z'],
    });
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export writes a JSON file and import round-trips every value type', () async {
    final path = await BackupService.export();
    expect(File(path).existsSync(), isTrue);

    // Simulate a fresh install / different device: clear prefs, then import.
    SharedPreferences.setMockInitialValues({});
    final restored = await BackupService.import();
    expect(restored, 5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a_string'), 'hello');
    expect(prefs.getBool('a_bool'), true);
    expect(prefs.getInt('an_int'), 42);
    expect(prefs.getDouble('a_double'), 3.14);
    expect(prefs.getStringList('a_list'), ['x', 'y', 'z']);
  });

  test('import throws when no backup file exists', () async {
    expect(BackupService.import(), throwsException);
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
