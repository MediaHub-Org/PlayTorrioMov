// test/units_no_raw_pixels_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files whose sizes come from `AppRem`/`AppType`/`context.rem`, not bare
/// numbers. A file joins this list when it is migrated; from then on a
/// literal size in it fails here, so the migration cannot quietly undo itself.
///
/// The migration is by batches (see the roadmap). A file not listed is simply
/// not migrated yet, and is not checked.
const migratedFiles = <String>[
  'lib/widgets/common/tv_side_menu.dart',
  'lib/widgets/common/hero_action_button.dart',
  'lib/widgets/common/focus_highlight.dart',
  'lib/widgets/common/tv_focus_bridge.dart',
  'lib/widgets/common/top_bar.dart',
  'lib/widgets/common/section_chips.dart',
  'lib/widgets/common/filter_dropdown.dart',
  'lib/widgets/common/header_pill_style.dart',
  'lib/widgets/common/section_header.dart',
];

/// A size written as a number. A line that must keep one -- a hairline border,
/// which is meant to stay one pixel at any text size -- says so with `// px`,
/// and a unitless ratio such as a line height with `// ratio`.
final _rawSize = <RegExp>[
  RegExp(
    r'\b(width|height|minWidth|minHeight|maxWidth|maxHeight|size|fontSize|'
    r'blurRadius|spreadRadius|radius|borderRadius|horizontal|vertical|left|'
    r'right|top|bottom|start|end)\s*:\s*[^,;]*(?<![\w.])[1-9]\d*(\.\d+)?\b',
  ),
  RegExp(r'EdgeInsets\.\w+\([^)]*\d'),
  RegExp(r'Radius\.circular\(\s*\d'),
  RegExp(r'Offset\(\s*[^)]*[1-9]'),
];

void main() {
  for (final path in migratedFiles) {
    test('$path has no bare pixel sizes', () {
      final lines = File(path).readAsLinesSync();
      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.split('//').first;
        if (line.contains('// px') || line.contains('// ratio')) continue;
        if (_rawSize.any((re) => re.hasMatch(code))) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'use context.rem(AppRem.x) for a size and AppType.x for a font '
            'size (lib/services/app_units.dart), or mark a deliberate '
            'hairline with "// px"',
      );
    });
  }
}
