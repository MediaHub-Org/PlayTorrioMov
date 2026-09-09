// test/app_info_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/app_info.dart';

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
      final expected = AppInfo.channel.isEmpty
          ? '9.9.9'
          : '9.9.9 (${AppInfo.channel})';
      expect(AppInfo.versionLabel('9.9.9'), expected);
    });

    test('versionLabel falls back when package info is missing', () {
      expect(AppInfo.versionLabel(null), contains(AppInfo.fallbackVersion));
      expect(AppInfo.versionLabel(''), contains(AppInfo.fallbackVersion));
    });

    test('isPrerelease tracks the channel', () {
      expect(AppInfo.isPrerelease, AppInfo.channel.isNotEmpty);
    });

    test('the channel comes from the build, not a hand-edited constant', () {
      // These three assertions are all self-consistent -- they hold whatever
      // channel says -- so none of them would notice the channel being
      // hardcoded, which is exactly how dev_build dispatches came to publish
      // binaries reporting themselves as verified releases. This pins the
      // wiring instead: unset (a plain `flutter test`) must be empty, and
      // build.yml must pass APP_CHANNEL to every platform build.
      expect(
        AppInfo.channel,
        '',
        reason: 'no --dart-define=APP_CHANNEL was given, so it must be empty',
      );

      final workflow = File('.github/workflows/build.yml').readAsStringSync();
      final buildCommands = RegExp(
        r'flutter build \w+ --release',
      ).allMatches(workflow).length;
      final channelDefines = RegExp(
        r'--dart-define=APP_CHANNEL=',
      ).allMatches(workflow).length;

      expect(
        channelDefines,
        greaterThanOrEqualTo(buildCommands),
        reason:
            'every `flutter build` in build.yml must pass APP_CHANNEL, or '
            'that platform ships without the dev marker',
      );
    });
  });
}
