import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/backup_service.dart';

void main() {
  group('BackupService.suggestedFileName', () {
    test('is dated, so one export does not overwrite the last', () {
      // A backup you can only ever have one of is a backup you overwrite
      // before you have checked the previous one.
      final name = BackupService.suggestedFileName(DateTime(2026, 9, 13));
      expect(name, 'playtorrio-backup-2026-09-13.json');
    });

    test('zero-pads, so names sort chronologically in a file manager', () {
      final name = BackupService.suggestedFileName(DateTime(2026, 1, 5));
      expect(name, 'playtorrio-backup-2026-01-05.json');
    });

    test('ends in .json, which is the extension the picker filters on', () {
      expect(BackupService.suggestedFileName(), endsWith('.json'));
    });

    test('carries no path separators -- it is a name, not a location', () {
      // Where the file goes is the user's choice in the save dialog. A
      // suggested name containing a separator would be rejected by the
      // platform dialog on at least Windows.
      final name = BackupService.suggestedFileName();
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('\\')));
    });
  });

  group('isPrivateOrLoopbackHost', () {
    // Unchanged by this work, but it guards the one place the backup
    // envelope is allowed to travel over plaintext HTTP.
    test('accepts loopback and private ranges', () {
      expect(isPrivateOrLoopbackHost('localhost'), isTrue);
      expect(isPrivateOrLoopbackHost('127.0.0.1'), isTrue);
      expect(isPrivateOrLoopbackHost('192.168.1.50'), isTrue);
      expect(isPrivateOrLoopbackHost('10.0.0.4'), isTrue);
      expect(isPrivateOrLoopbackHost('nas.local'), isTrue);
    });

    test('rejects a real remote host', () {
      expect(isPrivateOrLoopbackHost('example.com'), isFalse);
      expect(isPrivateOrLoopbackHost('203.0.113.9'), isFalse);
    });
  });
}
