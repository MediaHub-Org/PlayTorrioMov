import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';
import 'cloud_backup_settings.dart';
import 'dropbox_backup_service.dart';

/// "Backup at app open, if enough time has passed" -- there is no
/// background-task runner in this app (see docs/SYNC_AND_BACKUP.md), so an
/// app-open check is the whole mechanism: no scheduling, no platform-specific
/// background work, just a timestamp compared against now the next time
/// someone happens to open the app. A backup from a week ago beats no
/// automatic backup at all, and it is the honest answer to what "auto" can
/// mean without one.
abstract final class AutoBackupSettings {
  static const _enabledKey = 'auto_backup_enabled';
  static const _intervalDaysKey = 'auto_backup_interval_days';
  static const _lastRunKey = 'auto_backup_last_run_ms';

  /// On by default: connecting a destination (Dropbox or WebDAV) is already
  /// an opt-in action, and an "auto-backup" nobody meant to turn on again
  /// after connecting one would be a second step nobody expects, the way
  /// Google Photos backs up once you sign in rather than asking twice.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// Default: weekly. Picked over daily (noisier, and most libraries do not
  /// change that often) and monthly (a crash between backups loses more).
  static final ValueNotifier<int> intervalDays = ValueNotifier<int>(7);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_enabledKey) ?? true;
      intervalDays.value = prefs.getInt(_intervalDaysKey) ?? 7;
    } catch (e) {
      debugPrint('[AutoBackupSettings] Error initializing: $e');
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (e) {
      debugPrint('[AutoBackupSettings] Error saving enabled: $e');
    }
  }

  static Future<void> setIntervalDays(int days) async {
    intervalDays.value = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_intervalDaysKey, days);
    } catch (e) {
      debugPrint('[AutoBackupSettings] Error saving interval: $e');
    }
  }

  static Future<DateTime?> lastRunAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastRunKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> _markRanNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRunKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Whether a backup is due *right now*, given [lastRun] and [now] -- pure,
  /// so the "has it been long enough" rule is testable without the clock,
  /// SharedPreferences, or a network call. Never due with the setting off,
  /// and always due the first time (no previous run to measure from).
  @visibleForTesting
  static bool isDue({
    required bool enabled,
    required int intervalDays,
    required DateTime? lastRun,
    required DateTime now,
  }) {
    if (!enabled) return false;
    if (lastRun == null) return true;
    return now.difference(lastRun) >= Duration(days: intervalDays);
  }
}

/// Runs the due check and, if due, the backup itself -- kept apart from
/// [AutoBackupSettings] so that service stays pure data/preferences, testable
/// without a network, while this is the one place that actually calls out.
abstract final class AutoBackupService {
  /// Call once, after every other backup-adjacent service has initialized
  /// (`CloudBackupSettings`, so a configured WebDAV endpoint is already
  /// loaded) -- see `main.dart`. Never throws: a failed background backup at
  /// startup must not be the reason the app does not open.
  static Future<void> maybeRunAutoBackup() async {
    try {
      final due = AutoBackupSettings.isDue(
        enabled: AutoBackupSettings.enabled.value,
        intervalDays: AutoBackupSettings.intervalDays.value,
        lastRun: await AutoBackupSettings.lastRunAt(),
        now: DateTime.now(),
      );
      if (!due) return;

      // Dropbox first, WebDAV otherwise, when both are connected: one
      // destination, not a race between uploads at startup. Nothing
      // connected is not a failure -- there is simply nowhere to back up
      // to yet.
      if (await DropboxBackupService.isAuthenticated()) {
        await DropboxBackupService.upload();
      } else if (CloudBackupSettings.config.value != null) {
        await BackupService.uploadToCloud(CloudBackupSettings.config.value!);
      } else {
        return;
      }
      await AutoBackupSettings._markRanNow();
    } catch (e) {
      debugPrint('[AutoBackupService] Auto-backup failed: $e');
    }
  }
}
