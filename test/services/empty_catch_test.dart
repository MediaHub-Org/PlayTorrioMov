// test/services/empty_catch_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An empty `catch` is a decision: this error is not worth reporting, because
/// the caller already has a fallback, or the thing that failed was tidy-up, or
/// the loop simply moves to the next candidate. Every one of those is
/// reasonable. What is not reasonable is being unable to tell them apart from
/// an error that was genuinely lost.
///
/// The 2026-09-13 audit counted 126 of them and left them, on the grounds that
/// separating the two needs case-by-case reading rather than a sweep. That
/// reading has now happened: five turned out to be losing something a user
/// would notice and now say so through `debugPrint`, and the rest carry the
/// reason they swallow. This test is what stops the count climbing back:
/// writing `catch (_) {}` is still allowed, but not in silence.
void main() {
  // `catch (...) { ... }` where the body holds no nested braces -- which is
  // exactly the shape an empty or comment-only catch has. A catch with real
  // code in it is not what this test is about and is skipped below.
  final catchBlock = RegExp(r'catch\s*\([^)]*\)\s*\{([^{}]*)\}', dotAll: true);
  final comment = RegExp(r'//[^\n]*');

  test('every empty catch block says why it is empty', () {
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    // A guard that silently matched nothing would pass forever.
    expect(files, isNotEmpty, reason: 'no Dart sources found under lib/');

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in catchBlock.allMatches(source)) {
        final body = match.group(1)!;
        if (body.replaceAll(comment, '').trim().isNotEmpty) continue;
        if (body.contains('//')) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These catch blocks swallow an error without saying why.\n'
          'Add a comment giving the reason -- what the caller falls back to, '
          'or why the failure does not matter here. If the error is actually '
          'worth knowing about, debugPrint it instead.\n'
          '${offenders.join('\n')}',
    );
  });
}
