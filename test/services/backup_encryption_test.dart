// test/services/backup_encryption_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/backup_crypto.dart';
import 'package:playtorriomov/services/backup/backup_service.dart';
import 'package:playtorriomov/services/storage/secure_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'tmdb_api_key': 'SECRET-TMDB-KEY'});
    await SecureValueStore.delete(BackupPassphrase.key);
  });

  test('no passphrase, no backup: nothing is built to send', () async {
    await expectLater(
      BackupService.buildOutgoingEnvelope(),
      throwsA(
        isA<BackupCryptoException>().having(
          (e) => e.message,
          'message',
          contains('passphrase'),
        ),
      ),
    );
  });

  test('what leaves the device is sealed, and the passphrase is not in it', () async {
    await BackupPassphrase.save('correct horse');
    final outgoing = await BackupService.buildOutgoingEnvelope();

    expect(outgoing, isNot(contains('SECRET-TMDB-KEY')));
    expect(outgoing, isNot(contains('correct horse')));

    final opened = await BackupCrypto.open(outgoing, 'correct horse');
    final data = (jsonDecode(opened) as Map)['data'] as Map;
    expect(data['tmdb_api_key'], 'SECRET-TMDB-KEY');
    expect(data.containsKey(BackupPassphrase.key), isFalse);
  });

  test('a sealed backup restores on a fresh install with its passphrase', () async {
    await BackupPassphrase.save('correct horse');
    final outgoing = await BackupService.buildOutgoingEnvelope();

    // A new device: nothing stored, the passphrase typed in by hand.
    SharedPreferences.setMockInitialValues({});
    await SecureValueStore.delete(BackupPassphrase.key);
    await BackupPassphrase.save('correct horse');
    await BackupService.applyEnvelopeJson(outgoing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tmdb_api_key'), 'SECRET-TMDB-KEY');
  });

  test('a sealed backup without its passphrase restores nothing', () async {
    await BackupPassphrase.save('correct horse');
    final outgoing = await BackupService.buildOutgoingEnvelope();

    SharedPreferences.setMockInitialValues({});
    await SecureValueStore.delete(BackupPassphrase.key);
    await expectLater(
      BackupService.applyEnvelopeJson(outgoing),
      throwsA(isA<BackupCryptoException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tmdb_api_key'), isNull);
  });
}
