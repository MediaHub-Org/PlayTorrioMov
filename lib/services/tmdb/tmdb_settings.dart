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
/// There is deliberately no third source. A hardcoded fallback key used to
/// sit here, and it was dead: a TMDB key committed to a public repository
/// gets found and revoked, which is what 401s on v1.6.2 were. Its cost was
/// not the failure but the story the failure told -- the settings card said
/// "Using this build's included key", so a user with no key was told they
/// had a working one, and only the red status line underneath disagreed.
/// With no key at all the card says to add one, which is both true and the
/// thing to do. If a build should ship a key, put it in `ENV_FILE`, where
/// rotating it does not mean shipping a new binary.
abstract final class TmdbSettings {
  static const _apiKeyKey = 'tmdb_api_key';

  /// The user's own key, or null if they have not set one. This is *not*
  /// necessarily the key requests use -- see [effectiveApiKey].
  static final ValueNotifier<String?> apiKey = ValueNotifier<String?>(null);

  /// The key this build ships with, or null if it ships without one.
  static String? get bundledApiKey {
    final key = EnvService.tmdbApiKey;
    return key.isNotEmpty ? key : null;
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
