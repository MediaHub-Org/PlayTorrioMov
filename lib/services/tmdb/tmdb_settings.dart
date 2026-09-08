import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_service.dart';

/// The TMDB API key used to enrich cast lists with photos and character
/// names when an addon only supplies plain name strings.
///
/// Two sources, in priority order:
///
///  1. [apiKey] -- a key the user pasted into Settings. Always wins.
///  2. [bundledApiKey] -- a key baked into the build via
///     `--dart-define=TMDB_API_KEY=...` or a `TMDB_API_KEY` line in `.env`.
///     Release builds get it from the `ENV_FILE` repository secret, the
///     same path Trakt's and Simkl's credentials take, so cast photos work
///     on a fresh install with no setup.
///
/// Everything that depends on this no-ops when neither is present.
abstract final class TmdbSettings {
  static const _apiKeyKey = 'tmdb_api_key';

  /// The user's own key, or null if they have not set one. This is *not*
  /// necessarily the key requests use -- see [effectiveApiKey].
  static final ValueNotifier<String?> apiKey = ValueNotifier<String?>(null);

  /// The key this build ships with, if any.
  static String? get bundledApiKey {
    final key = EnvService.tmdbApiKey;
    return key.isEmpty ? null : key;
  }

  /// The key requests actually send: the user's, else the build's, else
  /// none.
  static String? get effectiveApiKey => apiKey.value ?? bundledApiKey;

  /// Whether cast enrichment can run at all.
  static bool get isConfigured => effectiveApiKey != null;

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
