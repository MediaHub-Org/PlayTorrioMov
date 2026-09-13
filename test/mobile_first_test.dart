import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #15 is a standing policy — design for a phone first, then scale up — and
/// a policy nobody can check is a wish. This is the checkable part of it.
void main() {
  test('no widget declares a width a phone cannot give it', () {
    // 360dp is the narrowest width the app is expected to work at, and a
    // SizedBox with a fixed width larger than that cannot shrink: whatever
    // it holds is painted past the edge of the screen. This caught a
    // settings dialog pinned at 400, which overflowed on exactly the
    // devices the app is mostly used on.
    //
    // A clamped or computed width is fine and is what the fix looks like --
    // only a bare numeric literal is flagged.
    final fixedWidth = RegExp(r'SizedBox\(\s*(?:[^()]*?,\s*)?width:\s*(\d+(?:\.\d+)?)\s*[,)]');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in fixedWidth.allMatches(source)) {
        final width = double.parse(match.group(1)!);
        if (width >= 360) {
          offenders.add('${file.path}: SizedBox(width: $width)');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'clamp against MediaQuery width instead — a phone cannot give '
          'this, so the contents paint off-screen',
    );
  });
}
