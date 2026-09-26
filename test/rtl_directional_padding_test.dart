// test/rtl_directional_padding_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #68 ships Arabic, so every layout in `lib/` is rendered right-to-left for
/// some users. `Row`, `ListView` and the Material widgets flip themselves
/// under `Directionality`. Physical padding does not: `EdgeInsets.only(left:)`
/// is still the left edge in Arabic, so a leading inset becomes a trailing one
/// and the content hugs the wrong side of the screen.
///
/// This is the half of an RTL audit a test can hold. The other half —
/// whether an icon or a custom painter points the right way — needs eyes on a
/// device, and is recorded in the roadmap rather than pretended at here.
///
/// Unlike the `height:` scan #69 tried and abandoned, this pattern is exact:
/// `EdgeInsets.only(left:` names one physical edge and nothing else, so there
/// is no nesting to confuse it and no false positives to triage.
void main() {
  test('no padding names a physical edge instead of a direction', () {
    // `EdgeInsetsDirectional.only(start:/end:)` is the fix, and it is a drop-in
    // — `padding` and `margin` take `EdgeInsetsGeometry`, which both satisfy.
    final physical = RegExp(r'EdgeInsets\.only\(\s*(?:[^()]*?,\s*)?(left|right):');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (physical.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use EdgeInsetsDirectional.only(start:/end:) — a physical edge '
          'does not flip for Arabic, so this inset lands on the wrong side',
    );
  });
}
