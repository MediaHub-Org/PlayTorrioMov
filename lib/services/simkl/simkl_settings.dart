import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_service.dart';

/// The Simkl client ID the app signs in with.
///
/// Two sources, in priority order:
///
///  1. [clientId] -- an ID the user registered themselves and pasted into
///     Settings. Always wins.
///  2. [bundledClientId] -- the ID baked into the build from `.env`, via
///     the `ENV_FILE` repository secret.
///
/// The second one is empty in every published build, because that secret
/// is not set. Connect therefore failed with "Failed to request Simkl PIN
/// code" and no way to do anything about it. Registering a Simkl app is
/// free and takes a minute, so this makes the user's own ID a first-class
/// source rather than a developer-only one.
///
/// Only an ID, no secret: Simkl's PIN flow authenticates with `client_id`
/// alone -- `/oauth/pin`, the poll, and every API call after it. The old
/// `kSimklClientSecret` constant was never read by anything.
abstract final class SimklSettings {
  static const _clientIdKey = 'simkl_client_id';

  /// The user's own client ID, or null if they have not set one. This is
  /// *not* necessarily the ID requests use -- see [effectiveClientId].
  static final ValueNotifier<String?> clientId = ValueNotifier<String?>(null);

  /// The ID this build ships with, or null when `.env` carried none.
  static String? get bundledClientId {
    final id = EnvService.simklClientId;
    return id.isEmpty ? null : id;
  }

  /// The ID requests actually send: the user's, else the build's, else
  /// none at all.
  static String? get effectiveClientId => clientId.value ?? bundledClientId;

  /// Whether Simkl can be connected to at all.
  static bool get isConfigured => effectiveClientId != null;

  /// True when the only reason Simkl is unavailable is that this build
  /// shipped without an ID -- which the user can fix themselves.
  static bool get needsUserClientId => !isConfigured;

  /// Whether [value] is worth saving as a client ID: one run of letters,
  /// digits, `-` or `_`, long enough to be real. It cannot say the ID is
  /// *valid* -- only Simkl can -- but it catches the common paste mistakes (a
  /// URL, a sentence, a trailing newline's worth of spaces) before they turn
  /// into a confusing 401.
  static bool looksLikeClientId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(value.trim());

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_clientIdKey);
    clientId.value = (stored != null && stored.isNotEmpty) ? stored : null;
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

  /// What happened on the most recent Simkl auth request, for the Settings
  /// card to show.
  ///
  /// Connect used to fail with one generic line whatever went wrong -- a
  /// missing ID, an ID Simkl rejected, and a dead network all read the
  /// same. Only the first two are things the user can act on, and they
  /// need different actions.
  static final ValueNotifier<String?> lastStatus = ValueNotifier<String?>(null);

  static void note(String message) => lastStatus.value = message;

  static String describeStatus(int code) => switch (code) {
    401 || 403 => 'Simkl rejected the client ID ($code). Check that you copied '
        'the whole Client ID from your app at simkl.com/settings/developer.',
    404 => 'Simkl did not recognize that PIN request (404).',
    429 => 'Simkl rate-limited this device (429). Try again shortly.',
    _ => 'Simkl returned HTTP $code.',
  };

  @visibleForTesting
  static void resetForTest() {
    clientId.value = null;
    lastStatus.value = null;
  }
}
