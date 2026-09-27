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

  test('every icon-only GestureDetector or InkWell carries a label', () {
    // The other half of the same invariant. A `GestureDetector` wrapped around
    // a bare `Icon` is a button to a user and nothing at all to a screen
    // reader: no name, and no announcement that it is pressable. 13 of these
    // were unlabelled when this was written.
    //
    // "Icon and no Text" is what makes a control icon-only. A control with a
    // label beside the icon already reads, so it is not what this is for.
    final control = RegExp(r'(?<![A-Za-z0-9_$.])(GestureDetector|InkWell)\(');
    final icon = RegExp(r'(?<![A-Za-z0-9_$.])Icon\(');
    final text = RegExp(r'(?<![A-Za-z0-9_$.])Text\(');
    final labeller =
        RegExp(r'(?<![A-Za-z0-9_$.])(Tooltip|Semantics|ArrowTooltip)\(');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.startsWith('lib/l10n/app_localizations')) continue;
      final source = file.readAsStringSync();

      for (final match in control.allMatches(source)) {
        final open = match.end - 1;
        final close = _closeOf(source, open);
        final body = source.substring(open, close + 1);

        if (!body.contains('onTap')) continue;
        if (!icon.hasMatch(body)) continue;
        if (text.hasMatch(body)) continue;
        if (labeller.hasMatch(body) || body.contains('semanticLabel')) continue;

        // A label on any enclosing widget does the job just as well, and
        // eleven of these turned out to have one -- which is why the raw count
        // of "unlabelled" controls was almost twice the real number.
        if (_hasLabellingAncestor(source, labeller, match.start, close)) {
          continue;
        }

        // The other shape that labels a control: bind its tree to a local and
        // wrap that local at the `return`. Five widgets do this, because
        // wrapping a deep tree in place means reindenting all of it, and a
        // diff that reindents fifty lines to add one hides what it changed.
        // The wrapper is then *after* the control in source order, so the walk
        // above cannot see it -- this looks for it by name instead.
        if (_wrappedAtReturn(source, labeller, match.start)) continue;

        final line = source.substring(0, match.start).split('\n').length;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'wrap it in a Tooltip, or in ArrowTooltip when it is an arrow '
          '-- an Icon in a GestureDetector has no accessible name',
    );
  });
}

/// The index of the `)` matching the `(` at [open].
int _closeOf(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return source.length - 1;
}

/// Whether some `Tooltip`/`Semantics` in this file encloses [start]–[end].
bool _hasLabellingAncestor(
  String source,
  RegExp labeller,
  int start,
  int end,
) {
  for (final match in labeller.allMatches(source)) {
    final open = match.end - 1;
    if (open >= start) break;
    if (_closeOf(source, open) > end) return true;
  }
  return false;
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

/// Whether the tree at [start] is assigned to a local that some `Tooltip` or
/// `ArrowTooltip` later in the file passes as its `child`.
bool _wrappedAtReturn(String source, RegExp labeller, int start) {
  final statement = source.lastIndexOf('final ', start);
  if (statement < 0) return false;
  final assigned = RegExp(r'final\s+(\w+)\s*=')
      .matchAsPrefix(source.substring(statement));
  if (assigned == null) return false;
  final name = assigned.group(1)!;

  for (final match in labeller.allMatches(source)) {
    if (match.end < start) continue;
    final body = _argumentList(source, match.end - 1);
    if (RegExp('child:\\s*$name[,)]').hasMatch(body)) return true;
  }
  return false;
}
