import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/secure_value_store.dart';

/// A WebDAV endpoint the user points at their own server (Nextcloud, a
/// self-hosted WebDAV server, etc.) to store the same JSON envelope
/// [BackupService.export] already writes locally. No vendor lock-in, no
/// request-signing dependency to add -- plain HTTP PUT/GET with Basic Auth.
class CloudBackupConfig {
  final String url;
  final String username;
  final String password;

  const CloudBackupConfig({
    required this.url,
    required this.username,
    required this.password,
  });
}

abstract final class CloudBackupSettings {
  static const _urlKey = 'cloud_backup_webdav_url';
  static const _userKey = 'cloud_backup_webdav_user';
  static const _passKey = 'cloud_backup_webdav_pass';

  static final ValueNotifier<CloudBackupConfig?> config = ValueNotifier<CloudBackupConfig?>(null);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final user = prefs.getString(_userKey);
    final pass = await SecureValueStore.read(_passKey);
    if (url != null && url.isNotEmpty) {
      config.value = CloudBackupConfig(url: url, username: user ?? '', password: pass ?? '');
    }
  }

  static Future<void> setConfig(CloudBackupConfig? value) async {
    config.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_urlKey);
      await prefs.remove(_userKey);
      await SecureValueStore.delete(_passKey);
    } else {
      await prefs.setString(_urlKey, value.url);
      await prefs.setString(_userKey, value.username);
      await SecureValueStore.write(_passKey, value.password);
    }
  }
}
