import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Wyzie subtitle key the user pasted into Settings.
///
/// Wyzie's quota is per key. Every install of a build that ships a key draws
/// on the same daily allowance, which ran out for everyone on 2026-10-18 and
/// again the next day. A key of the user's own has its own allowance, so it
/// takes precedence over the build's key.
abstract final class WyzieSettings {
  static const _apiKeyKey = 'wyzie_api_key';

  /// The user's own key, or null if they have not set one.
  static final ValueNotifier<String?> apiKey = ValueNotifier<String?>(null);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_apiKeyKey);
    apiKey.value = (stored != null && stored.isNotEmpty) ? stored : null;
  }

  static Future<void> setApiKey(String? value) async {
    final trimmed = value?.trim();
    final normalized = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    if (apiKey.value == normalized) return;
    apiKey.value = normalized;
    final preferences = await SharedPreferences.getInstance();
    if (normalized == null) {
      await preferences.remove(_apiKeyKey);
    } else {
      await preferences.setString(_apiKeyKey, normalized);
    }
  }
}
