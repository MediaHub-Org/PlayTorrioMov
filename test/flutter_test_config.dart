import 'dart:async';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory fake so `flutter_secure_storage` resolves without a real
/// platform channel round-trip during tests -- otherwise every plain
/// `test()` (not `testWidgets()`) that reaches a secure-storage read
/// (e.g. via `TraktService.isAuthenticated()`) fails with "Binding has not
/// yet been initialized" outside a widget-test zone, and even inside one,
/// the extra channel latency is enough to let indeterminate progress
/// indicators (`CircularProgressIndicator`) actually start animating,
/// which `pumpAndSettle()` then never settles past.
class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

/// Applies automatically to every test under `test/` (Flutter's
/// `flutter_test_config.dart` convention) -- no per-file setup needed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
  await testMain();
}
