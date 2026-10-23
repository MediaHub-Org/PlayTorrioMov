import 'dart:convert';

import 'backup_crypto.dart';

/// What a sync decided: the merged profile, and the keys both sides had
/// changed since they last agreed. For those the cloud copy was kept.
class ProfileMergePlan {
  final Map<String, Object?> merged;
  final List<String> conflicts;

  const ProfileMergePlan({required this.merged, required this.conflicts});
}

/// Three-way merge of the synced profile, key by key.
///
/// Three copies take part: the snapshot both sides last agreed on (`base`),
/// this device's keys (`local`) and the cloud copy (`remote`). A key that only
/// one side changed takes that side's value. A key both sides changed to
/// different values is a conflict, and the cloud copy wins it; the caller keeps
/// a snapshot of the local profile before it overwrites anything.
abstract final class ProfileMerge {
  /// Whether a key belongs to the synced profile. Everything else is this
  /// device's own bookkeeping, and syncing it would leak one device's state
  /// (a token's expiry, a schedule's last run) into the others.
  static bool isSynced(String key) {
    if (key.startsWith('profile_sync_')) return false;
    if (key.startsWith('auto_backup_')) return false;
    if (key.startsWith('dropbox_')) return false;
    if (key == 'trakt_token_expiry_ms') return false;
    if (key == 'backup_passphrase') return false;
    return true;
  }

  static ProfileMergePlan merge({
    required Map<String, Object?> base,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
  }) {
    final merged = <String, Object?>{};
    final conflicts = <String>[];

    final keys = {...base.keys, ...local.keys, ...remote.keys};
    for (final key in keys) {
      final localChanged = !_same(base, local, key);
      final remoteChanged = !_same(base, remote, key);

      if (!localChanged && !remoteChanged) {
        if (base.containsKey(key)) merged[key] = base[key];
      } else if (localChanged && !remoteChanged) {
        if (local.containsKey(key)) merged[key] = local[key];
      } else if (!localChanged && remoteChanged) {
        if (remote.containsKey(key)) merged[key] = remote[key];
      } else if (_same(local, remote, key)) {
        if (remote.containsKey(key)) merged[key] = remote[key];
      } else {
        conflicts.add(key);
        if (remote.containsKey(key)) merged[key] = remote[key];
      }
    }
    return ProfileMergePlan(merged: merged, conflicts: conflicts);
  }

  /// Whether two maps hold the same value for [key], absence included: a key
  /// missing from one side and present on the other is a change.
  static bool _same(
    Map<String, Object?> a,
    Map<String, Object?> b,
    String key,
  ) {
    if (a.containsKey(key) != b.containsKey(key)) return false;
    if (!a.containsKey(key)) return true;
    return jsonEncode(a[key]) == jsonEncode(b[key]);
  }

  /// The plain text a snapshot of the profile is stored as, sorted so two
  /// snapshots of the same profile are byte-for-byte equal.
  static String encodeData(Map<String, Object?> data) {
    final sorted = Map.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sorted);
  }

  /// Decodes what [encodeData] produced, or what a backup envelope carries as
  /// its `data`. Anything not a plain value is dropped, as a restore would.
  static Map<String, Object?> decodeData(Object? raw) {
    if (raw is! Map) return <String, Object?>{};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && _isPlainValue(entry.value))
          entry.key as String: entry.value,
    };
  }

  static bool _isPlainValue(Object? value) =>
      value is String ||
      value is bool ||
      value is int ||
      value is double ||
      (value is List && value.every((e) => e is String));

  /// Opens a sealed cloud copy and returns its profile data.
  static Future<Map<String, Object?>> openRemote(
    String sealed,
    String passphrase,
  ) async {
    final plain = await BackupCrypto.open(sealed, passphrase);
    final envelope = jsonDecode(plain);
    if (envelope is! Map) {
      throw const FormatException('The cloud copy is not a PlayTorrio backup.');
    }
    return decodeData(envelope['data']);
  }
}
