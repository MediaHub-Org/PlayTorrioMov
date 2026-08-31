// test/services/breakpoint_consistency_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_breakpoints.dart';

/// A width compared against 700, 750 or 800 — the values that drifted away
/// from [AppBreakpoints]. 900 and 600 are the canonical cutoffs, so a grid
/// that ramps its column count at those is consistent, not a violation: a
/// grid legitimately has more breakpoints than the three nav tiers.
final _driftedCutoff = RegExp(r'width\s*[<>]=?\s*(700|750|800)\b');

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

// No full-screen takeover pages currently exist in this app; kept as a
// set so a future one can be added here without touching the test logic.
const _fullScreenPlayers = <String>{};

void main() {
  group('AppBreakpoints', () {
    test('maps widths to tiers at the documented cutoffs', () {
      expect(AppBreakpoints.tierForWidth(599), ScreenTier.mobile);
      expect(AppBreakpoints.tierForWidth(600), ScreenTier.tablet);
      expect(AppBreakpoints.tierForWidth(899), ScreenTier.tablet);
      expect(AppBreakpoints.tierForWidth(900), ScreenTier.desktop);
    });

    test('820px is one tier everywhere, not two', () {
      // The bug this guards: pages using >= 800 rendered desktop layouts at
      // 820px while the nav chrome, on 900, rendered tablet — a visible split
      // down the middle of one screen.
      const width = 820.0;
      expect(AppBreakpoints.tierForWidth(width), ScreenTier.tablet);

      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        final path = file.path;
        if (_fullScreenPlayers.contains(path)) continue;
        for (final line in file.readAsLinesSync()) {
          if (_driftedCutoff.hasMatch(line)) offenders.add('$path: ${line.trim()}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these compare a width against a tier cutoff directly instead '
            'of asking AppBreakpoints, which is how they drifted to '
            '700/750/800 in the first place',
      );
    });
  });
}
