// test/icon_button_tooltip_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An icon-only button has no visible text, so its `tooltip` is the only
/// label it has -- and `Tooltip` is what Material turns into the semantics a
/// screen reader reads. Without one, TalkBack and VoiceOver announce "button"
/// and nothing else.
///
/// #69 wired 46 of these by hand; two thirds were one of two actions (Close
/// and Back), which is why `commonClose` and `commonBack` exist. This holds
/// that line: the next `IconButton` someone adds without a tooltip fails here
/// rather than shipping unlabelled.
///
/// Scanning source rather than pumping widgets is deliberate. A rendered
/// probe can only reach the buttons a test can construct, and the ones that
/// went unlabelled longest live on pages that fetch over the network -- the
/// portals modal, the channel sheet -- which nothing constructs. The pattern
/// is exact enough not to need the renderer: `IconButton(` is a call, and a
/// call either has `tooltip:` in its argument list or it does not.
void main() {
  // `PlayerIconButton` is the player's own icon-only button and takes a
  // nullable tooltip, so it needs the same check as Material's.
  for (final name in ['IconButton', 'PlayerIconButton']) {
    test('every $name call carries a tooltip', () {
      // The lookbehind is what keeps this honest. Without it the pattern also
      // matches `SettingsIconButton(`, `HeaderPillIconButton(` and
      // `IconButton.styleFrom(` -- a style helper, not a button, and two
      // wrappers that require their own tooltip at the type level.
      final call = RegExp(r'(?<![A-Za-z0-9_$.])' + name + r'\(');

      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // Forward slashes everywhere: on Windows listSync reports
        // backslashes, and without this the generated-output skip below
        // misses -- green on Linux CI, red on a Windows checkout.
        final path = file.path.replaceAll(r'\', '/');
        // Generated from the ARB files; nothing here is hand-written.
        if (path.startsWith('lib/l10n/app_localizations')) continue;

        final source = file.readAsStringSync();
        for (final match in call.allMatches(source)) {
          // `IconButton({` with a brace is the constructor *declaration* of a
          // wrapper class, not a call -- a call never opens with `({`.
          if (source.startsWith('({', match.end - 1)) continue;

          final body = _argumentList(source, match.end - 1);
          if (body.contains('tooltip:')) continue;

          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('$path:$line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'an icon-only button with no tooltip has no accessible label '
            '-- give it one, reusing commonClose/commonBack where it is a '
            'Close or a Back',
      );
    });
  }
}

/// The source of the argument list opening at [open], parens balanced, so a
/// nested `Icon(...)` or a ternary inside it does not end the scan early.
String _argumentList(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  return source.substring(open);
}
