// A source scan that keeps TV focus visible, in the project's usual style
// (see mobile_first_test.dart, units_no_raw_pixels_test.dart).
//
// An `InkWell` over an opaque `Container` hides its own focus tint, hover and
// splash: the ink is painted on the Material underneath, and the container's
// fill covers it. A remote moving through such a list showed nothing at all
// (#80), and the cure each time was `FocusFill`. 38 call sites had been
// written since without it, so the rule is enforced here rather than
// remembered.
//
// A site that is correct without the wrapper says why with a
// `// focus-ok: <reason>` comment within the lines above it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How far above a widget its wrapper or note may sit.
const _lookBack = 13;

List<File> libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('app_localizations'))
    .toList();

/// The [_lookBack] lines above line [index] (0-based), joined.
String above(List<String> lines, int index) =>
    lines.sublist(index < _lookBack ? 0 : index - _lookBack, index).join('\n');

int matching(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final c = text[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

void main() {
  test('every InkWell is wrapped so its focus and hover can be seen', () {
    final wrapper = RegExp(
      r'FocusFill\(|FocusHighlight\(|HoverButton\(|FocusRing\(|focus-ok',
    );
    final bare = <String>[];
    for (final file in libFiles()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'\bInkWell\(').hasMatch(lines[i])) continue;
        if (wrapper.hasMatch(above(lines, i))) continue;
        bare.add('${file.path}:${i + 1}');
      }
    }
    expect(
      bare,
      isEmpty,
      reason:
          'Wrap in FocusFill(radius: ..., child: InkWell(...)), or say why '
          'with // focus-ok: <reason>',
    );
  });

  test('a PopupMenuButton with its own child is wrapped in FocusHighlight', () {
    // With a custom child the button is a pill the Material focus tint cannot
    // reach through; with an icon it is an IconButton and the theme covers it.
    final bare = <String>[];
    for (final file in libFiles()) {
      final text = file.readAsStringSync();
      final lines = text.split('\n');
      for (final m in RegExp(r'PopupMenuButton<[^>]*>\(').allMatches(text)) {
        final close = matching(text, m.end - 1);
        final block = text.substring(m.start, close + 1).split('\n');
        if (block.length < 2) continue;
        final indent = block[1].length - block[1].trimLeft().length;
        final ownChild = block
            .skip(1)
            .any((l) => RegExp('^ {$indent}child:').hasMatch(l));
        if (!ownChild) continue;
        final line = text.substring(0, m.start).split('\n').length - 1;
        final from = line < 4 ? 0 : line - 4;
        final context = lines.sublist(from, line).join('\n');
        if (RegExp(r'FocusHighlight\(|focus-ok').hasMatch(context)) continue;
        bare.add('${file.path}:${line + 1}');
      }
    }
    expect(bare, isEmpty);
  });

  test('the watch screen keeps its pills and cards by identity', () {
    final source = File('lib/pages/player/watch_screen.dart').readAsStringSync();

    // Every filter pill names itself, so one appearing earlier in the row
    // cannot move focus from another.
    final calls = RegExp(r'_buildFilterDropdownButton\(').allMatches(source);
    final keyed = RegExp(r'pillKey:').allMatches(source);
    // The definition matches the call pattern once and passes no pillKey.
    expect(keyed.length, calls.length - 1,
        reason: 'every call passes pillKey');

    // And the source cards, which are re-sorted as add-ons answer.
    expect(source, contains('key: _sourceCardKey(filtered, index)'));
  });

  test('the keys that press a control are declared once', () {
    // Seventeen files each carried their own copy, and they drifted. The one
    // set lives in widgets/common/activate_keys.dart.
    final copies = <String>[];
    for (final file in libFiles()) {
      if (file.path.endsWith('activate_keys.dart')) continue;
      final text = file.readAsStringSync();
      if (RegExp(r'final\s+_\w*[aA]ctivators\s*=').hasMatch(text)) {
        copies.add(file.path);
      }
    }
    expect(copies, isEmpty, reason: 'use kActivateKeys');
  });
}
