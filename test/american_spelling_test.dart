// test/american_spelling_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AGENTS.md`: American spelling everywhere, comments and docs included.
///
/// The reason is a search, not a style preference: `colour` in one file and
/// `color` in the next means a grep for either finds half the places, which is
/// how a rename misses a caller. Comments count because comments are how the
/// decisions in this codebase are recorded, and a decision nobody can find is
/// not recorded.
///
/// Two kinds of word are deliberately *not* checked.
///
/// An external API's own spelling stays as the API spells it -- AniList's
/// `favourites` field and its `CANCELLED` status -- so those files allow that
/// one word and nothing else. `Colors.grey` is the same idea, which is why
/// `grey` is absent from the list altogether: it is Flutter's name.
///
/// Doubled-consonant forms (`cancelled`, `labelled`, `travelled`) are left
/// out as well. Both spellings are current in American English, Flutter's own
/// API uses the doubled ones, and a guard that fights the framework is a
/// guard someone turns off.
///
/// The scan covers `lib/`, `test/` and `docs/` -- source and the living docs,
/// `.arb` message files included. It found nothing in `lib/` on its first run
/// and CI still failed, because `flutter gen-l10n` copies an ARB
/// `@description` into a doc comment: the one British spelling left was in
/// `app_en.arb`, which a `.dart`-and-`.md` scan could not see. Generated
/// output is skipped for the same reason it is gitignored -- it is not a file
/// anyone edits.
///
/// `CHANGELOG.md` is outside it on purpose: a released entry is a record of
/// what shipped and when, not a document that gets corrected afterwards.
void main() {
  /// British spelling to the American one this codebase uses.
  const spellings = <String, String>{
    'favourite': 'favorite',
    'favourited': 'favorited',
    'favourites': 'favorites',
    'favouriting': 'favoriting',
    'colour': 'color',
    'colours': 'colors',
    'coloured': 'colored',
    'colouring': 'coloring',
    'behaviour': 'behavior',
    'behaviours': 'behaviors',
    'catalogue': 'catalog',
    'catalogues': 'catalogs',
    'centre': 'center',
    'centres': 'centers',
    'centred': 'centered',
    'centring': 'centering',
    'licence': 'license',
    'defence': 'defense',
    'offence': 'offense',
    'organise': 'organize',
    'organised': 'organized',
    'organisation': 'organization',
    'initialise': 'initialize',
    'initialised': 'initialized',
    'initialises': 'initializes',
    'initialisation': 'initialization',
    'initialiser': 'initializer',
    'analyse': 'analyze',
    'analysed': 'analyzed',
    'analysing': 'analyzing',
    'normalise': 'normalize',
    'normalised': 'normalized',
    'normalisation': 'normalization',
    'serialise': 'serialize',
    'serialised': 'serialized',
    'serialisation': 'serialization',
  };

  /// The words a given file is allowed to keep, and why.
  const allowed = <String, Set<String>>{
    // AniList's field name, in the model that parses it and the GraphQL query
    // that asks for it. Renaming it would stop the JSON matching.
    'lib/models/anime/anime_media.dart': {'favourites'},
    'lib/services/anime/anilist_service.dart': {'favourites'},
    // The spelling rule quotes the spellings it rules out.
    'docs/CONVENTIONS.md': {'colour', 'favourites'},
  };

  final pattern = RegExp(
    r'\b(' + spellings.keys.join('|') + r')\b',
    caseSensitive: false,
  );

  test('every comment, string and doc uses the American spelling', () {
    final offenders = <String>[];
    for (final root in ['lib', 'test', 'docs']) {
      for (final file in Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') ||
              f.path.endsWith('.md') ||
              f.path.endsWith('.arb'))) {
        // Forward slashes everywhere: on Windows listSync reports
        // backslashes, and without this every lookup below misses -- the
        // allowlist, the generated-output skip, and the self-skip, which is
        // why this was green on Linux CI and red on a Windows checkout.
        final path = file.path.replaceAll(r'\', '/');
        // `flutter gen-l10n` writes these from the ARB files; correcting a
        // copy would only hide the original.
        if (path.startsWith('lib/l10n/app_localizations')) continue;
        // This file's own list is the list; skipping it whole rather than
        // word by word, since every entry would need allowing.
        if (path == 'test/american_spelling_test.dart') continue;

        final exempt = allowed[path] ?? const <String>{};
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final match in pattern.allMatches(lines[i])) {
            final word = match.group(0)!.toLowerCase();
            if (exempt.contains(word)) continue;
            offenders.add(
              '$path:${i + 1}: "${match.group(0)}" '
              '-- write "${spellings[word]}"',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'AGENTS.md asks for American spelling everywhere, comments '
          'included, so a search for one spelling finds every site',
    );
  });
}
