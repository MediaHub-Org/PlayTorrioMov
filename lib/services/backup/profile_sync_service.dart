import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_backup_service.dart';
import 'backup_crypto.dart';
import 'backup_service.dart';
import 'gist_sync.dart';
import 'profile_merge.dart';

/// How a sync ended. A sync never throws: a failed one is logged and reported
/// here, so the timer and the app-pause hook have nothing to catch.
enum ProfileSyncResult { notConnected, busy, failed, synced }

/// Keeps this device's profile and the cloud copy in step.
///
/// Runs when the app opens, every ten minutes while it is open, and when it
/// goes to the background. Each run is a three-way merge (see [ProfileMerge]):
/// it takes what the other side changed, keeps what this device changed, and
/// sends the result back up. Before a local value is overwritten or removed, a
/// snapshot of the local profile is written under the app's support folder, so
/// a bad merge can be read back by hand.
///
/// The cloud copy is one secret gist in the person's own GitHub account (see
/// [GistSync]). Active only where there is a token and a backup passphrase;
/// without both, the app-open auto backup runs as it always did.
abstract final class ProfileSyncService {
  static const _baseKey = 'profile_sync_base';
  static const _interval = Duration(minutes: 10);

  static bool _running = false;
  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;

  /// Whether this device syncs its profile: it carries a GitHub token and has a
  /// passphrase to seal the cloud copy with.
  static Future<bool> isActive() async {
    if (!GistSync.isConfigured) return false;
    return await BackupPassphrase.read() != null;
  }

  /// Called once at startup. Syncs now and keeps syncing, or runs the app-open
  /// auto backup when this device does not sync.
  static Future<void> start() async {
    if (!await isActive()) {
      await AutoBackupService.maybeRunAutoBackup();
      return;
    }
    _timer ??= Timer.periodic(_interval, (_) => unawaited(syncNow()));
    _lifecycle ??= AppLifecycleListener(onPause: () => unawaited(syncNow()));
    await syncNow();
  }

  static Future<ProfileSyncResult> syncNow() async {
    if (_running) return ProfileSyncResult.busy;
    if (!await isActive()) return ProfileSyncResult.notConnected;
    _running = true;
    try {
      await _sync();
      return ProfileSyncResult.synced;
    } catch (e) {
      debugPrint('[ProfileSync] Sync failed, nothing was changed: $e');
      return ProfileSyncResult.failed;
    } finally {
      _running = false;
    }
  }

  static Future<void> _sync() async {
    final passphrase = (await BackupPassphrase.read())!;
    final local = await _localProfile();
    final base = await _readBase();
    final sealed = await GistSync.download();
    final remote = sealed == null
        ? <String, Object?>{}
        : _synced(await ProfileMerge.openRemote(sealed, passphrase));

    final plan = ProfileMerge.merge(base: base, local: local, remote: remote);
    final merged = plan.merged;

    // An empty profile here means the local store did not load, not that the
    // person removed everything. Never send that over a cloud copy with content.
    if (merged.isEmpty && remote.isNotEmpty) {
      debugPrint('[ProfileSync] Local profile is empty; keeping the cloud copy.');
      return;
    }

    final overwritten = _differing(local, merged);
    if (overwritten.any(local.containsKey)) {
      await BackupService.writeSnapshot();
    }
    await _applyLocal(merged, local);

    if (!_identical(merged, remote)) {
      await GistSync.upload(
        await BackupService.sealProfile(merged),
      );
    }
    await _writeBase(merged);

    if (plan.conflicts.isNotEmpty) {
      debugPrint(
        '[ProfileSync] Changed on both sides, kept the cloud copy for: '
        '${plan.conflicts.join(', ')}',
      );
    }
  }

  /// This device's synced keys, read from its own store.
  static Future<Map<String, Object?>> _localProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in prefs.getKeys())
        if (ProfileMerge.isSynced(key)) key: prefs.get(key),
    };
  }

  static Map<String, Object?> _synced(Map<String, Object?> data) => {
        for (final entry in data.entries)
          if (ProfileMerge.isSynced(entry.key)) entry.key: entry.value,
      };

  /// The snapshot both sides last agreed on. Empty before the first sync, which
  /// makes every key on either side count as changed on that side.
  static Future<Map<String, Object?>> _readBase() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_baseKey);
    if (raw == null) return <String, Object?>{};
    return _synced(ProfileMerge.decodeData(jsonDecode(raw)));
  }

  static Future<void> _writeBase(Map<String, Object?> merged) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, ProfileMerge.encodeData(merged));
  }

  /// Writes the merged profile into this device's store: only the synced keys,
  /// and only the ones that differ.
  static Future<void> _applyLocal(
    Map<String, Object?> merged,
    Map<String, Object?> local,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in {...local.keys, ...merged.keys}) {
      if (!ProfileMerge.isSynced(key)) continue;
      if (!merged.containsKey(key)) {
        await prefs.remove(key);
        continue;
      }
      final value = merged[key];
      if (local.containsKey(key) &&
          jsonEncode(local[key]) == jsonEncode(value)) {
        continue;
      }
      await _write(prefs, key, value);
    }
  }

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.cast<String>().toList());
    }
  }

  /// Keys whose value or presence differs between [a] and [b].
  static Set<String> _differing(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    return {
      for (final key in {...a.keys, ...b.keys})
        if (!a.containsKey(key) ||
            !b.containsKey(key) ||
            jsonEncode(a[key]) != jsonEncode(b[key]))
          key,
    };
  }

  static bool _identical(Map<String, Object?> a, Map<String, Object?> b) =>
      ProfileMerge.encodeData(a) == ProfileMerge.encodeData(b);
}
