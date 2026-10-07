// test/services/backup_cross_provider_compatibility_test.dart
//
// Dropbox and Google Drive are two independently-coded transports; nothing
// in the type system stops one from drifting to its own file name or
// quietly mangling the envelope in transit. This locks in the one thing
// that makes a backup made on either restorable from the other: both write
// the exact same file identity, and neither transforms the envelope's
// content on the way through.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/backup/backup_service.dart';
import 'package:playtorriomov/services/backup/dropbox_backup_service.dart';
import 'package:playtorriomov/services/backup/google_drive_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dropbox and Google Drive agree on one backup file name', () {
    // Drive has no path separator (files are named, not pathed); Dropbox's
    // is rooted at the app folder. Stripped of that, they must be the same
    // name -- a backup made on one and found by a person browsing the other
    // service's web UI should be recognizably the same file.
    expect(
      DropboxBackupService.backupPath,
      '/${GoogleDriveBackupService.backupName}',
    );
  });

  test('Drive\'s multipart upload carries the envelope through unchanged',
      () async {
    SharedPreferences.setMockInitialValues({'a_string': 'hello', 'an_int': 42});
    final envelope = await BackupService.buildEnvelopeJson();

    final body = GoogleDriveBackupService.buildUploadMultipart(
      envelopeJson: envelope,
      boundary: 'test-boundary',
    );
    final text = utf8.decode(body);

    // The envelope's own JSON sits between the second part's headers and
    // the closing boundary, byte for byte -- not re-encoded, not escaped a
    // second time as a string inside the multipart wrapper.
    const secondPartHeader = 'Content-Type: application/json\r\n\r\n';
    final secondPartStart = text.indexOf(secondPartHeader) + secondPartHeader.length;
    final secondPartEnd = text.indexOf('\r\n--test-boundary--');
    final extracted = text.substring(secondPartStart, secondPartEnd);
    expect(extracted, envelope);

    // What a download would hand BackupService.applyEnvelopeJson restores
    // identically to applying the original -- Drive's wrapping is purely
    // transport, never content.
    SharedPreferences.setMockInitialValues({});
    final restored = await BackupService.applyEnvelopeJson(extracted);
    expect(restored, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('a_string'), 'hello');
    expect(prefs.getInt('an_int'), 42);
  });
}
