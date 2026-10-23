// The snapshots taken before a sync or a restore overwrites the profile.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({'likes': '[1,2]'});
    dir = Directory.systemTemp.createTempSync('playtorrio_snapshot_test_');
    BackupService.snapshotDirectoryOverride = () async => dir;
  });

  tearDown(() {
    BackupService.snapshotDirectoryOverride = null;
  });

  Future<List<File>> snapshots() async => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith('profile-'))
      .toList();

  test('a snapshot holds this device profile', () async {
    await BackupService.writeSnapshot();

    final files = await snapshots();
    expect(files, hasLength(1));
    expect(await files.single.readAsString(), contains('"likes"'));
  });

  test('only the last five snapshots are kept', () async {
    for (var i = 0; i < 7; i++) {
      await BackupService.writeSnapshot();
      // Snapshot names carry the time to the millisecond.
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }

    expect(await snapshots(), hasLength(5));
  });
}
