// test/units_no_raw_pixels_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every UI file under `lib/pages` and `lib/widgets` takes its sizes from
/// `AppRem`/`AppType`/`context.rem`, not bare numbers, and this fails on one
/// that does not -- so the migration (see the roadmap) cannot quietly undo
/// itself. A file that must keep pixels goes in [exemptFiles] with the reason.
///
/// `lib/services` is not scanned: a number there is data or an engine
/// parameter (an image size asked of a cast receiver, a subtitle shadow), not
/// the size of something on screen.
const exemptFiles = <String, String>{};

List<String> _uiFiles() {
  final files = <String>[];
  for (final dir in ['lib/pages', 'lib/widgets']) {
    for (final e in Directory(dir).listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart')) files.add(e.path);
    }
  }
  files.removeWhere(exemptFiles.containsKey);
  files.sort();
  return files;
}

/// A size written as a number. A line that must keep one -- a hairline border,
/// which is meant to stay one pixel at any text size -- says so with `// px`,
/// and a unitless ratio such as a line height with `// ratio`.
final _rawSize = <RegExp>[
  RegExp(
    r'\b(width|height|minWidth|minHeight|maxWidth|maxHeight|size|fontSize|'
    r'blurRadius|spreadRadius|radius|borderRadius|horizontal|vertical|left|'
    r'right|top|bottom|start|end)\s*:\s*[^,;]*(?<![\w.])[1-9]\d*(\.\d+)?\b',
  ),
  RegExp(r'EdgeInsets\.\w+\([^)]*(?<![\w.])[1-9]'),
  RegExp(r'Radius\.circular\(\s*\d'),
  RegExp(r'(?<![\w.])Offset\(\s*[^)]*(?<![\w.])[1-9]'),
];

/// [code] with every `context.rem(...)` call (balanced, so a nested call is
/// fine) replaced by a placeholder: what is inside is already in rem.
String _withoutRem(String code) {
  const open = 'context.rem(';
  var out = code;
  var at = out.indexOf(open);
  while (at >= 0) {
    var depth = 1;
    var i = at + open.length;
    while (i < out.length && depth > 0) {
      if (out[i] == '(') depth++;
      if (out[i] == ')') depth--;
      i++;
    }
    out = '${out.substring(0, at)}R${out.substring(i)}';
    at = out.indexOf(open);
  }
  return out;
}

void main() {
  for (final path in _uiFiles()) {
    test('$path has no bare pixel sizes', () {
      final lines = File(path).readAsLinesSync();
      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A rem literal is the unit, not a bare number: `context.rem(1.25)`.
        final code = _withoutRem(line.split('//').first);
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
