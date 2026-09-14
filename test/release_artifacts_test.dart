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

    test('the macOS artifacts are named arm64', () {
      expect(workflow, contains(r'PlayTorrioMov-$APP_VERSION-macOS-arm64.dmg'));
      expect(workflow, contains(r'PlayTorrioMov-$APP_VERSION-macOS-arm64.zip'));

      // `intel` must not come back as a *name*. It came back once already,
      // labelling a universal build, which is how v1.6.2 shipped two
      // identical downloads under names promising a choice. Intel is now not
      // built at all, so the name has nothing left to describe.
      expect(workflow, isNot(contains('macOS-intel')));
      expect(workflow, isNot(contains('macOS-universal')));
    });

    test('the build proves the binary really is arm64 only', () {
      // Two halves, and both matter. Thinning without verifying would ship
      // whatever lipo happened to leave; verifying without thinning would
      // fail every build, since Flutter emits universal. The guard used to
      // require BOTH slices and now requires only arm64 -- it is the same
      // check inverted, which is the honest way to change this decision.
      expect(workflow, contains('lipo -thin arm64'));
      expect(workflow, contains('lipo -archs'));
      expect(workflow, contains('macOS build is not arm64-only'));

      // Thinning nothing means Flutter stopped emitting universal output, or
      // the bundle moved. Either way it is not something to publish through.
      expect(workflow, contains('Nothing to thin'));
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
