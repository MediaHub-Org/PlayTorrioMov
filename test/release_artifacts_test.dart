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

  group('the workflows do not use a retired action runtime', () {
    // GitHub is retiring the Node 20 Actions runtime. An action still on it
    // keeps working -- GitHub forces it onto Node 24 and prints a warning --
    // so nothing fails and nothing is red. The warning is the only signal,
    // and it scrolls past in a green build: that is exactly how
    // `action-gh-release@v2` sat here after v3 shipped.
    //
    // This is a source check rather than a live one because resolving an
    // action's `runs.using` needs the network, and a test that reaches
    // GitHub would fail on a fork, offline, or when the API rate-limits.
    // The list below is the actions this repo actually uses, pinned to the
    // first major that moved to Node 24.
    const node24Floor = {
      'actions/checkout': 5,
      'actions/cache': 5,
      'actions/upload-artifact': 6,
      'actions/download-artifact': 7,
      'actions/setup-java': 5,
      'softprops/action-gh-release': 3,
      'flatpak/flatpak-github-actions/flatpak-builder': 6,
    };

    /// Actions with no Node runtime at all, so there is no floor to check.
    /// `subosito/flutter-action` is a composite action -- it runs shell steps
    /// and never loads `dist/index.js`, so it is unaffected by the runtime
    /// retirement however old the tag is.
    const composite = {'subosito/flutter-action'};

    for (final file in [
      '.github/workflows/build.yml',
      '.github/workflows/pr-checks.yml',
    ]) {
      test(file, () {
        final source = File(file).readAsStringSync();
        final uses = RegExp(r'uses:\s*([\w.-]+/[\w.-]+(?:/[\w.-]+)?)@v(\d+)')
            .allMatches(source);

        for (final m in uses) {
          final action = m.group(1)!;
          final major = int.parse(m.group(2)!);
          final floor = node24Floor[action];
          if (floor == null) continue; // composite or local action
          expect(
            major,
            greaterThanOrEqualTo(floor),
            reason: '$action@v$major in $file is below v$floor, which is the '
                'first line on the Node 24 runtime. It still runs, but GitHub '
                'forces it and warns on every build.',
          );
        }
      });
    }

    test('every action the workflows use is in the list above', () {
      // Otherwise a new action could be added on a Node 20 line and this
      // whole group would silently skip it -- the check would pass by not
      // looking, which is worse than not having it.
      final seen = <String>{};
      for (final file in [
        '.github/workflows/build.yml',
        '.github/workflows/pr-checks.yml',
      ]) {
        final source = File(file).readAsStringSync();
        for (final m in RegExp(r'uses:\s*([\w.-]+/[\w.-]+(?:/[\w.-]+)?)@')
            .allMatches(source)) {
          seen.add(m.group(1)!);
        }
      }

      expect(
        seen.difference(node24Floor.keys.toSet()).difference(composite),
        isEmpty,
        reason: 'a new action was added to a workflow. Check which Node '
            'runtime it targets and add it to node24Floor (or to composite, '
            'if it has no Node runtime), or this guard will not cover it.',
      );
    });
  });
}
