// test/services/backup_crypto_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/backup_crypto.dart';

const _plain = '{"app":"PlayTorrio","data":{"tmdb_api_key":"SECRET-TMDB-KEY"}}';

void main() {
  test('a sealed backup opens back to exactly the JSON that went in', () async {
    final sealed = await BackupCrypto.seal(_plain, 'correct horse');
    expect(await BackupCrypto.open(sealed, 'correct horse'), _plain);
  });

  test('the sealed file does not show the data it protects', () async {
    final sealed = await BackupCrypto.seal(_plain, 'correct horse');
    expect(sealed, isNot(contains('SECRET-TMDB-KEY')));
    expect(sealed, isNot(contains('tmdb_api_key')));
  });

  test('every seal draws a fresh salt and nonce, so the same input differs', () async {
    final a = await BackupCrypto.seal(_plain, 'correct horse');
    final b = await BackupCrypto.seal(_plain, 'correct horse');
    expect(a, isNot(b));
  });

  test('a wrong passphrase is refused, not restored as garbage', () async {
    final sealed = await BackupCrypto.seal(_plain, 'correct horse');
    await expectLater(
      BackupCrypto.open(sealed, 'battery staple'),
      throwsA(isA<BackupCryptoException>()),
    );
  });

  test('a changed byte is refused', () async {
    final sealed = await BackupCrypto.seal(_plain, 'correct horse');
    final map = jsonDecode(sealed) as Map<String, dynamic>;
    final bytes = base64Decode(map['ciphertext'] as String);
    bytes[0] ^= 0x01;
    map['ciphertext'] = base64Encode(bytes);
    await expectLater(
      BackupCrypto.open(jsonEncode(map), 'correct horse'),
      throwsA(isA<BackupCryptoException>()),
    );
  });

  test('a sealed backup with no passphrase says it needs one', () async {
    final sealed = await BackupCrypto.seal(_plain, 'correct horse');
    await expectLater(
      BackupCrypto.open(sealed, null),
      throwsA(
        isA<BackupCryptoException>().having(
          (e) => e.message,
          'message',
          contains('passphrase'),
        ),
      ),
    );
  });

  test('a plain backup from before encryption opens as it always did', () async {
    expect(await BackupCrypto.open(_plain, null), _plain);
    expect(await BackupCrypto.open(_plain, 'anything'), _plain);
  });
}
