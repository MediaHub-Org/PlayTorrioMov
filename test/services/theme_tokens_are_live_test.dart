// test/services/theme_tokens_are_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A token read into a variable is read exactly once.
///
/// Dart initialises a top-level or `static` variable lazily, on its first
/// read, and never re-evaluates it. So `static Color accent =
/// AppColors.accent;` captures whichever palette and brightness happened to
/// be active the first time that screen was opened, and keeps them through
/// every later theme change -- a bug that looks like "the theme switch works
/// everywhere except this one screen", and only on screens you happened to
/// open before switching.
///
/// `final` does not help: it is the same lazy-once initialisation. The fix
/// is always the same shape, `Color get x => AppColors.x`, so this rule is
/// mechanical enough to enforce rather than remember.
void main() {
  test('theme tokens are read through getters, never stored in variables', () {
    // A declaration (top-level or static, var or final, typed or inferred)
    // whose initialiser reads AppColors. `=>` is what a getter uses, so the
    // negative lookahead is what separates the correct form from the bug.
    final frozen = RegExp(
      r'^[ \t]*(?:static[ \t]+)?(?:final[ \t]+|const[ \t]+)?'
      r'(?:Color|BoxDecoration|TextStyle|var)?[ \t]*'
      r'[_A-Za-z][A-Za-z0-9_]*[ \t]*=[ \t]*AppColors\.',
      multiLine: true,
    );

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Locals inside a function body are fine -- they are re-evaluated on
        // every build. Only declarations at file or class scope freeze, and
        // those sit at zero or two spaces of indentation.
        final indent = line.length - line.trimLeft().length;
        if (indent > 2) continue;
        if (!frozen.hasMatch(line)) continue;
        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'write `Color get x => AppColors.x` -- a stored token is '
          'initialised once and never follows a theme change',
    );
  });
}
