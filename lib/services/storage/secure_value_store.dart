import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [FlutterSecureStorage] (Keychain/Keystore/Credential
/// Locker, depending on platform) that transparently migrates a value
/// previously stored in plaintext [SharedPreferences] under the same key --
/// so existing installs don't lose saved Trakt/Simkl/WebDAV credentials on
/// upgrade, and the plaintext copy is deleted once migrated.
abstract final class SecureValueStore {
  static const _storage = FlutterSecureStorage();

  static Future<String?> read(String key) async {
    String? secureValue;
    try {
      secureValue = await _storage.read(key: key);
    } catch (_) {
      // No platform implementation available (e.g. a desktop target
      // missing its keychain backend). Fall through to the legacy
      // plaintext value below rather than losing the credential.
    }
    if (secureValue != null) return secureValue;

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue != null) {
      try {
        await _storage.write(key: key, value: legacyValue);
        await prefs.remove(key);
      } catch (_) {
        // Couldn't migrate -- leave the legacy plaintext value in place.
      }
      return legacyValue;
    }
    return null;
  }

  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Secure storage unavailable -- fall back to plaintext rather than
      // silently dropping the write.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
