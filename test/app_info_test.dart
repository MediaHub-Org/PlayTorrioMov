// test/app_info_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/app_info.dart';

/// Reads `version: 1.2.3+4` out of pubspec.yaml without pulling in a YAML
/// parser -- the one line is unambiguous and this keeps the test dependency
/// free.
({String version, String build}) _pubspecVersion() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'));
  final value = line.substring('version:'.length).trim();
  final parts = value.split('+');
  return (version: parts.first, build: parts.length > 1 ? parts[1] : '');
}

void main() {
  group('AppInfo', () {
    test('fallback version matches pubspec.yaml', () {
      // The fallbacks are what Settings, Updates and About display when
      // package_info_plus cannot read the platform bundle. Before this test
      // they said 1.0.6 while the app shipped 1.1.2, so a user with no
      // package info saw a version from six releases earlier.
      final pubspec = _pubspecVersion();
      expect(AppInfo.fallbackVersion, pubspec.version);
      expect(AppInfo.fallbackBuildNumber, pubspec.build);
    });

    test('versionLabel appends the channel marker', () {
      expect(AppInfo.versionLabel('9.9.9'), '9.9.9 (${AppInfo.channel})');
    });

    test('versionLabel falls back when package info is missing', () {
      expect(AppInfo.versionLabel(null), contains(AppInfo.fallbackVersion));
      expect(AppInfo.versionLabel(''), contains(AppInfo.fallbackVersion));
    });

    test('isPrerelease tracks the channel', () {
      expect(AppInfo.isPrerelease, AppInfo.channel.isNotEmpty);
    });
  });
}
