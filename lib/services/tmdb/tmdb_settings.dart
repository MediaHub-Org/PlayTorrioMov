import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's own TMDB API key (free, instant signup, no billing), used to
/// enrich cast lists with photos/character names when an addon only
/// supplies plain name strings. Everything that depends on this no-ops
/// when no key is set.
abstract final class TmdbSettings {
  static const _apiKeyKey = 'tmdb_api_key';

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
