import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_value_store.dart';

class StorageService {
  static const _kTraktAccessToken = 'trakt_access_token';
  static const _kTraktRefreshToken = 'trakt_refresh_token';
  static const _kTraktTokenExpiry = 'trakt_token_expiry_ms';
  static const _kTraktUsername = 'trakt_username';

  static const _kSimklAccessToken = 'simkl_access_token';
  static const _kSimklUsername = 'simkl_username';

  static final ValueNotifier<int> movieFinishedRevision = ValueNotifier<int>(0);

  // ── Trakt ─────────────────────────────────────────────────────────────────
  // Access/refresh tokens are secrets and live in secure storage (Keychain/
  // Keystore/Credential Locker), not plaintext SharedPreferences.
  static Future<String?> getTraktAccessToken() {
    return SecureValueStore.read(_kTraktAccessToken);
  }

  static Future<void> setTraktAccessToken(String token) {
    return SecureValueStore.write(_kTraktAccessToken, token);
  }

  static Future<String?> getTraktRefreshToken() {
    return SecureValueStore.read(_kTraktRefreshToken);
  }

  static Future<void> setTraktRefreshToken(String token) {
    return SecureValueStore.write(_kTraktRefreshToken, token);
  }

  static Future<int?> getTraktTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTraktTokenExpiry);
  }

  static Future<void> setTraktTokenExpiry(int expiryMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTraktTokenExpiry, expiryMs);
  }

  static Future<String?> getTraktUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTraktUsername);
  }

  static Future<void> setTraktUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTraktUsername, username);
  }

  static Future<bool> clearTraktAuth() async {
    await SecureValueStore.delete(_kTraktAccessToken);
    await SecureValueStore.delete(_kTraktRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTraktTokenExpiry);
    await prefs.remove(_kTraktUsername);
    return true;
  }

  // ── Simkl ─────────────────────────────────────────────────────────────────
  static Future<String?> getSimklAccessToken() {
    return SecureValueStore.read(_kSimklAccessToken);
  }

  static Future<void> setSimklAccessToken(String token) {
    return SecureValueStore.write(_kSimklAccessToken, token);
  }

  static Future<String?> getSimklUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSimklUsername);
  }

  static Future<void> setSimklUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSimklUsername, username);
  }

  static Future<void> clearSimklAuth() async {
    await SecureValueStore.delete(_kSimklAccessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSimklUsername);
  }
}
