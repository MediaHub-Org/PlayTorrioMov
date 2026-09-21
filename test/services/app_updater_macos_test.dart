// test/services/app_updater_macos_test.dart
import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/updater/app_updater_service.dart';

Map<String, String> asset(String name) =>
    {'name': name, 'browser_download_url': 'https://example.test/$name'};

void main() {
  final service = AppUpdaterService();

  group('findMacOSAsset', () {
    final both = [
      asset('PlayTorrioMov-1.9.0-macOS-arm64.zip'),
      asset('PlayTorrioMov-1.9.0-macOS-arm64.dmg'),
      asset('PlayTorrioMov-1.9.0-macOS-x86_64.zip'),
      asset('PlayTorrioMov-1.9.0-macOS-x86_64.dmg'),
      asset('PlayTorrioMov-1.9.0-Windows-x64-Setup.exe'),
    ];

    test('an Apple Silicon Mac gets the arm64 disk image', () {
      expect(
        service.findMacOSAsset(both, Abi.macosArm64),
        endsWith('macOS-arm64.dmg'),
      );
    });

    test('an Intel Mac gets the x86_64 disk image', () {
      expect(
        service.findMacOSAsset(both, Abi.macosX64),
        endsWith('macOS-x86_64.dmg'),
        reason: 'the arm64 build cannot run on an Intel Mac at all',
      );
    });

    test('falls back to the zip when there is no disk image', () {
      final zipsOnly = [
        asset('PlayTorrioMov-1.9.0-macOS-arm64.zip'),
        asset('PlayTorrioMov-1.9.0-macOS-x86_64.zip'),
      ];
      expect(service.findMacOSAsset(zipsOnly, Abi.macosX64),
          endsWith('macOS-x86_64.zip'));
    });

    test('an unknown architecture is treated as Apple Silicon', () {
      expect(service.findMacOSAsset(both, null), endsWith('macOS-arm64.dmg'));
    });

    test('an older release with arm64 only is still offered to an Intel Mac',
        () {
      // v1.6.3 to v1.8.7 published arm64 only. Nothing better exists there,
      // and returning null would make the updater say there is no download.
      final armOnly = [
        asset('PlayTorrioMov-1.8.7-macOS-arm64.dmg'),
        asset('PlayTorrioMov-1.8.7-macOS-arm64.zip'),
      ];
      expect(service.findMacOSAsset(armOnly, Abi.macosX64),
          endsWith('macOS-arm64.dmg'));
    });

    test('is null when the release has no macOS asset', () {
      expect(
        service.findMacOSAsset(
            [asset('PlayTorrioMov-1.9.0-Windows-x64-Setup.exe')], Abi.macosArm64),
        isNull,
      );
    });
  });
}
