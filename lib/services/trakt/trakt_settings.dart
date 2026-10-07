import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_service.dart';

/// The Trakt API credentials the app signs in with.
///
/// Two sources per value, in priority order:
///
///  1. [clientId] / [clientSecret] -- an app the user registered themselves
///     and pasted into Settings. Always wins.
///  2. The values baked into the build from `.env`, via the `ENV_FILE`
///     repository secret.
///
/// The second source is empty in every published build, because that secret
/// is not set -- and unlike Simkl, a Trakt user cannot always register their
/// own app either, since Trakt gates new API apps behind VIP. An app
/// registered before that gate still works, so this makes the user's own
/// credentials a first-class source rather than a developer-only one: the
/// card explains the VIP gate, and anyone holding working credentials --
/// theirs or the maintainer's -- can paste them in with no rebuild.
///
/// Both live in SharedPreferences, the way the Simkl client ID and the TMDB
/// key do: they identify an installed app rather than a user, and the
/// user's own Trakt tokens stay in `SecureValueStore` where they belong.
abstract final class TraktSettings {
  static const _clientIdKey = 'trakt_client_id';
  static const _clientSecretKey = 'trakt_client_secret';

  /// The user's own credentials, or null when not set. These are *not*
  /// necessarily what requests use -- see [effectiveClientId] and
  /// [effectiveClientSecret].
  static final ValueNotifier<String?> clientId = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> clientSecret =
      ValueNotifier<String?>(null);

  /// What this build ships with, or null when `.env` carried none.
  static String? get bundledClientId {
    final id = EnvService.traktClientId;
    return id.isEmpty ? null : id;
  }

  static String? get bundledClientSecret {
    final secret = EnvService.traktClientSecret;
    return secret.isEmpty ? null : secret;
  }

  /// What requests actually send: the user's, else the build's, else none.
  static String? get effectiveClientId => clientId.value ?? bundledClientId;

  static String? get effectiveClientSecret =>
      clientSecret.value ?? bundledClientSecret;

  /// Whether Trakt can be connected to at all: an ID *and* a secret, from
  /// either source. The device-token poll sends both, so one without the
  /// other is not a configuration, it is half of one.
  static bool get isConfigured =>
      effectiveClientId != null && effectiveClientSecret != null;

  /// True when the only reason Trakt is unavailable is missing credentials
  /// -- which the user can fix themselves if they hold any.
  static bool get needsUserCredentials => !isConfigured;

  /// Whether [value] is worth saving as a credential: one run of letters
  /// and digits, long enough to be real. It cannot say the value is
  /// *valid* -- only Trakt can -- but it catches the common paste mistakes
  /// (a URL, a sentence, a trailing newline's worth of spaces) before they
  /// turn into a confusing 401.
  static bool looksLikeCredential(String value) =>
      RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(value.trim());

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final storedId = preferences.getString(_clientIdKey);
    clientId.value = (storedId != null && storedId.isNotEmpty) ? storedId : null;
    final storedSecret = preferences.getString(_clientSecretKey);
    clientSecret.value =
        (storedSecret != null && storedSecret.isNotEmpty) ? storedSecret : null;
  }

  static Future<void> setClientId(String? value) async {
    final trimmed = value?.trim();
    final normalized = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    if (clientId.value == normalized) return;
    clientId.value = normalized;
    final preferences = await SharedPreferences.getInstance();
    if (normalized == null) {
      await preferences.remove(_clientIdKey);
    } else {
      await preferences.setString(_clientIdKey, normalized);
    }
  }

  static Future<void> setClientSecret(String? value) async {
    final trimmed = value?.trim();
    final normalized = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    if (clientSecret.value == normalized) return;
    clientSecret.value = normalized;
    final preferences = await SharedPreferences.getInstance();
    if (normalized == null) {
      await preferences.remove(_clientSecretKey);
    } else {
      await preferences.setString(_clientSecretKey, normalized);
    }
  }

  /// What happened on the most recent Trakt auth request, for the Settings
  /// card to show. Connect used to fail with one generic line whatever went
  /// wrong -- missing credentials, rejected credentials, and a dead network
  /// all read the same. Only the first two are things the user can act on,
  /// and they need different actions.
  static final ValueNotifier<String?> lastStatus = ValueNotifier<String?>(null);

  static void note(String message) => lastStatus.value = message;

  static String describeStatus(int code) => switch (code) {
    401 || 403 => 'Trakt rejected the credentials ($code). Check that you '
        'copied the whole Client ID and Client Secret from your app at '
        'trakt.tv/oauth/applications.',
    404 => 'Trakt did not recognize that pairing request (404).',
    429 => 'Trakt rate-limited this device (429). Try again shortly.',
    _ => 'Trakt returned HTTP $code.',
  };

  @visibleForTesting
  static void resetForTest() {
    clientId.value = null;
    clientSecret.value = null;
    lastStatus.value = null;
  }
}
