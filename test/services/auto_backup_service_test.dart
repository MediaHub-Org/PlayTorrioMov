// test/services/auto_backup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/auto_backup_service.dart';

void main() {
  group('AutoBackupSettings.isDue', () {
    final now = DateTime(2026, 1, 8);

    test('off is never due, however long it has been', () {
      expect(
        AutoBackupSettings.isDue(
          enabled: false,
          intervalDays: 1,
          lastRun: DateTime(2000),
          now: now,
        ),
        isFalse,
      );
    });

    test('no previous run is always due -- nothing to measure from', () {
      expect(
        AutoBackupSettings.isDue(
          enabled: true,
          intervalDays: 30,
          lastRun: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('exactly at the interval counts as due', () {
      expect(
        AutoBackupSettings.isDue(
          enabled: true,
          intervalDays: 7,
          lastRun: DateTime(2026, 1, 1),
          now: now,
        ),
        isTrue,
      );
    });

    test('a day short of the interval is not due yet', () {
      expect(
        AutoBackupSettings.isDue(
          enabled: true,
          intervalDays: 7,
          lastRun: DateTime(2026, 1, 2),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
