// test/no_hardcoded_text_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #68 ships Spanish, Arabic and Portuguese, and the way it regresses is not a
/// broken translation -- it is a new `Text('Something')` that nobody notices,
/// because a missing key does not crash. `flutter gen-l10n` emits the English
/// string, so the app looks fine and one row is quietly untranslated.
///
/// The roadmap's own note said a scan "no longer finds" the remaining tail,
/// and that was true of a line-based grep: what is left is interpolated and
/// spread over adjacent literals. So this reads the argument instead. A
/// literal first argument to `Text(` with a run of three letters *outside* an
/// interpolation is prose, and prose belongs in an ARB file.
///
/// Three letters is the whole heuristic, and it is what makes the scan usable:
/// `'S${season}E${episode}'`, `'${n} px'`, `'+${offset}s'` and `'${pct}%'` are
/// codes, units and numbers, not sentences, and none of them trip it.
void main() {
  /// The literals a file may keep, spelled out in full, with the reason.
  ///
  /// An entry here is a decision that the string is not prose -- a unit, an
  /// identifier, a command someone pastes into a terminal. It is not a way to
  /// defer translating something.
  const allowed = <String, Set<String>>{
    // A packet count's unit, beside a ms one that is already short enough to
    // pass. "pkts" is the abbreviation an mpv option uses.
    'lib/pages/settings/video_player_settings_page.dart': {
      '\${PlayerSettings.customBufferCount.value} pkts',
    },
    // A shell command the user copies and runs. Translating it would break it.
    'lib/widgets/updater/update_dialog.dart': {
      'flatpak install --user --reinstall "\$filePath"',
    },
  };

  test('no user-facing Text() holds a hardcoded English sentence', () {
    final call = RegExp(r'(?<![A-Za-z0-9_$.])(Text|SelectableText)\(\s*');

    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Forward slashes everywhere: on Windows listSync reports
      // backslashes, and without this the allowlist below misses -- green
      // on Linux CI, red on a Windows checkout.
      final path = file.path.replaceAll(r'\', '/');
      // Generated from the ARB files; nothing here is hand-written.
      if (path.startsWith('lib/l10n/app_localizations')) continue;

      final source = file.readAsStringSync();
      final exempt = allowed[path] ?? const <String>{};

      for (final match in call.allMatches(source)) {
        if (match.end >= source.length || source[match.end] != "'") continue;

        final literal = _literalRun(source, match.end);
        if (literal == null) continue;
        if (exempt.contains(literal.raw)) continue;
        if (!_isProse(literal.stripped)) continue;

        final line = source.substring(0, match.start).split('\n').length;
        offenders.add('$path:$line: \'${literal.raw}\'');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'add a key to all four ARB files and read it with context.l10n '
          '-- see the Localization section of docs/CONVENTIONS.md',
    );
  });
}

/// A run of adjacent single-quoted literals -- Dart concatenates
/// `'one '\n'two'` into one string, and the prose is as often in the second
/// part as the first.
class _Literal {
  /// As written, interpolations included, the parts joined.
  final String raw;

  /// The same text with every `$name` and `${...}` removed, which is what a
  /// prose check has to look at: `'${count} Episodes'` is prose, and
  /// `'S${season}E${episode}'` is a code.
  final String stripped;

  const _Literal(this.raw, this.stripped);
}

/// Reads the adjacent single-quoted literals starting at [start] (an opening
/// quote), or null if the first one is not a plain literal.
_Literal? _literalRun(String source, int start) {
  final raw = StringBuffer();
  final stripped = StringBuffer();
  var i = start;
  var parts = 0;

  while (i < source.length && source[i] == "'") {
    i++; // past the opening quote
    var closed = false;
    while (i < source.length) {
      final c = source[i];
      if (c == '\n') return parts == 0 ? null : _done(raw, stripped);
      if (c == r'\') {
        raw.write(source.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (c == "'") {
        i++;
        closed = true;
        break;
      }
      if (c == r'$') {
        final skipped = _skipInterpolation(source, i);
        if (skipped == null) return parts == 0 ? null : _done(raw, stripped);
        raw.write(source.substring(i, skipped));
        i = skipped;
        continue;
      }
      raw.write(c);
      stripped.write(c);
      i++;
    }
    if (!closed) return parts == 0 ? null : _done(raw, stripped);
    parts++;

    // Another literal on the next line continues this string.
    final next = _nextNonSpace(source, i);
    if (next == null || source[next] != "'") break;
    i = next;
  }

  return parts == 0 ? null : _done(raw, stripped);
}

_Literal _done(StringBuffer raw, StringBuffer stripped) =>
    _Literal(raw.toString(), stripped.toString());

/// The index just past the `$name` or `${...}` beginning at [i], or null if
/// what follows is neither -- which means the scan cannot read this literal and
/// should give up rather than guess.
int? _skipInterpolation(String source, int i) {
  if (i + 1 >= source.length) return null;
  if (source[i + 1] == '{') {
    var depth = 0;
    for (var j = i + 1; j < source.length; j++) {
      if (source[j] == '{') depth++;
      if (source[j] == '}') {
        depth--;
        if (depth == 0) return j + 1;
      }
    }
    return null;
  }
  final ident = RegExp(r'^\$[A-Za-z_][A-Za-z0-9_]*').firstMatch(
    source.substring(i),
  );
  return ident == null ? null : i + ident.end;
}

int? _nextNonSpace(String source, int from) {
  for (var j = from; j < source.length; j++) {
    if (!RegExp(r'\s').hasMatch(source[j])) return j;
  }
  return null;
}

bool _isProse(String stripped) => RegExp(r'[A-Za-z]{3}').hasMatch(stripped);
