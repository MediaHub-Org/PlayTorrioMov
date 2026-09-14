// test/release_artifacts_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the shape of the macOS release, which three separate things have to
/// agree on: the workflow that builds it, the names it publishes under, and
/// `AppUpdaterService._findMacOSAsset`, which picks a download by name.
///
/// v1.6.2 shipped four macOS assets that were two copies of the same
/// universal app -- an "Intel" download that was not an Intel build. Nothing
/// caught it because nothing asserted the relationship between the builds and
/// the names. This does.
void main() {
  late String workflow;

  setUpAll(() {
    workflow = File('.github/workflows/build.yml').readAsStringSync();
  });

  group('macOS release artifacts', () {
    test('there is exactly one macOS build job', () {
      // `flutter build macos` emits a universal binary, so a second
      // per-architecture job produces the same two slices at ~14 minutes a
      // release. If one is ever added back, the artifact names below stop
      // describing what is published.
      final macBuilds = RegExp(
        r'flutter build macos --release',
      ).allMatches(workflow).length;

      expect(
        macBuilds,
        1,
        reason: 'expected one macOS build; a second one means the release '
            'publishes two builds of the same universal app',
      );
    });

    test('the macOS artifacts are named universal', () {
      expect(workflow, contains(r'PlayTorrioMov-$APP_VERSION-macOS-universal.dmg'));
      expect(workflow, contains(r'PlayTorrioMov-$APP_VERSION-macOS-universal.zip'));

      // The names the old two-job layout used. Their absence is the point:
      // an asset called "intel" that is a universal build is a promise of a
      // choice that does not exist.
      expect(workflow, isNot(contains('macOS-intel')));
      expect(workflow, isNot(contains('macOS-arm64')));
    });

    test('the build proves the binary really is universal', () {
      // Without this step "universal" is just a filename. With it, a Flutter
      // that stopped emitting both slices fails the build instead of shipping
      // an arm64-only app to Intel Macs under a name that says otherwise.
      expect(workflow, contains('lipo -archs'));
      expect(workflow, contains('macOS build is not universal'));
    });

    test('the release waits on the macOS job', () {
      final needs = RegExp(r'needs: \[(.*?)\]', dotAll: true)
          .allMatches(workflow)
          .map((m) => m.group(1)!)
          .where((n) => n.contains('windows'))
          .single;

      expect(needs, contains('macos'));
      expect(
        needs,
        isNot(contains('macos-intel')),
        reason: 'the release job would wait forever on a job that no longer exists',
      );
    });
  });
}
