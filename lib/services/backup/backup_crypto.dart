import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

import '../config/env_service.dart';
import '../storage/secure_value_store.dart';

/// Keeps the passphrase that seals backups. It lives in the secure store and
/// never in the envelope itself: a passphrase inside the backup would sit next
/// to the ciphertext it protects, and [BackupService] leaves it out for that.
abstract final class BackupPassphrase {
  static const key = 'backup_passphrase';

  /// The passphrase on this device: the one the person set, or else the build's
  /// own (a private build carries it so a new install opens the cloud copy
  /// without asking).
  static Future<String?> read() async {
    final value = await SecureValueStore.read(key);
    if (value != null && value.isNotEmpty) return value;
    final bundled = EnvService.backupPassphrase;
    return bundled.isEmpty ? null : bundled;
  }

  static Future<void> save(String passphrase) => SecureValueStore.write(key, passphrase);
}

/// Something a backup cannot do, with a message fit to show the user as it is.
class BackupCryptoException implements Exception {
  final String message;
  const BackupCryptoException(this.message);

  @override
  String toString() => message;
}

/// Seals the backup envelope with a passphrase, so a copy in someone else's
/// cloud (Dropbox, a WebDAV server) is unreadable without it.
///
/// PBKDF2-HMAC-SHA256 stretches the passphrase into a 256-bit key. AES-256-GCM
/// seals the JSON under a fresh random salt and nonce, with the format name
/// bound in as associated data. GCM authenticates the ciphertext, so a wrong
/// passphrase or a damaged file is refused rather than restored as garbage.
///
/// Both directions run in an isolate: the key derivation is a few hundred
/// thousand HMAC rounds, which would otherwise freeze the screen on a phone.
abstract final class BackupCrypto {
  static const String _format = 'playtorrio-backup';
  static const int _version = 2;
  static const int _iterations = 200000;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;
  static const int _keyBytes = 32;
  static final Uint8List _aad = Uint8List.fromList(utf8.encode('$_format/v$_version'));

  /// The sealed envelope for [plaintext], the JSON a plain backup would hold.
  static Future<String> seal(String plaintext, String passphrase) =>
      Isolate.run(() => _seal(plaintext, passphrase));

  /// The plain JSON inside [raw]. A plain backup comes back unchanged. A sealed
  /// one needs [passphrase]; a wrong one, or a damaged file, throws.
  static Future<String> open(String raw, String? passphrase) async {
    final fields = _sealedFields(raw);
    if (fields == null) return raw;
    if (passphrase == null) {
      throw const BackupCryptoException(
        'This backup is encrypted. Set its passphrase in Backup settings first.',
      );
    }
    return Isolate.run(() => _open(fields, passphrase));
  }

  static String _seal(String plaintext, String passphrase) {
    final random = Random.secure();
    final salt = _randomBytes(random, _saltBytes);
    final nonce = _randomBytes(random, _nonceBytes);
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters(
          pc.KeyParameter(_deriveKey(passphrase, salt, _iterations)),
          128,
          nonce,
          _aad,
        ),
      );
    final ciphertext = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    return const JsonEncoder.withIndent('  ').convert({
      'format': _format,
      'version': _version,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
    });
  }

  static String _open(Map<String, dynamic> fields, String passphrase) {
    final salt = base64Decode(fields['salt'] as String);
    final nonce = base64Decode(fields['nonce'] as String);
    final ciphertext = base64Decode(fields['ciphertext'] as String);
    final iterations = fields['iterations'] as int;
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters(
          pc.KeyParameter(_deriveKey(passphrase, salt, iterations)),
          128,
          nonce,
          _aad,
        ),
      );
    try {
      return utf8.decode(cipher.process(ciphertext));
    } on Exception {
      // GCM's tag check failed: the key is wrong or the bytes were changed.
      throw const BackupCryptoException('Wrong passphrase, or the backup is damaged.');
    }
  }

  /// The envelope's fields when [raw] is a sealed backup, otherwise null. A
  /// plain backup has no `format` field; the JSON parse failing is left to the
  /// restore that follows, which reports it the same way it always has.
  static Map<String, dynamic>? _sealedFields(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['format'] != _format) return null;
    return decoded.cast<String, dynamic>();
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt, int iterations) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, iterations, _keyBytes));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Uint8List _randomBytes(Random random, int length) =>
      Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}
