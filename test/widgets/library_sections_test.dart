// test/widgets/library_sections_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/library_sections.dart';

/// The one Library page, for the app's single hub.
const _libraryPages = [
  'lib/pages/collection/collection_page.dart',
];

void main() {
  group('LibrarySection', () {
    test('is the three library states, then Downloads', () {
      // History was dropped 2026-09-02, and Continue on 2026-09-13: Continue
      // rendered ContinueWatchingService.activeItems, the identical deduped
      // list the Continue Watching row already shows.
      //
      // The first three are the states LibraryActionsRow writes on every
      // details page, so a tab here means what the button there meant. The
      // generic "Saved" bucket is gone: it needed a generic icon precisely
      // because it held two unlike things at once.
      expect(
        LibrarySection.values.map((s) => s.label).toList(),
        ['Liked', 'Watchlist', 'Watched', 'Downloads'],
      );
    });

    test('only Downloads is not a My List state', () {
      // Downloads reads DownloadService, not MyListService, and is kept
      // because it is the only place an in-app download can be managed.
      expect(
        LibrarySection.values.where((s) => s.isLibraryState).map((s) => s.name),
        ['liked', 'watchlist', 'watched'],
      );
      expect(LibrarySection.downloads.isLibraryState, isFalse);
    });

    test('every label and icon is distinct', () {
      expect(
        LibrarySection.values.map((s) => s.label).toSet().length,
        LibrarySection.values.length,
      );
      expect(
        LibrarySection.values.map((s) => s.icon).toSet().length,
        LibrarySection.values.length,
      );
    });
  });

  group('every hub builds its Library from the shared spec', () {
    // A source check rather than a widget test: two of the three pages need
    // half the app's services initialised before they will pump, and what
    // matters here is only that none of them hand-rolls its own tab list
    // again -- which is exactly how the three drifted to 4/5/5 tabs with
    // different names in the first place.
    for (final path in _libraryPages) {
      test(path, () {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('for (final section in LibrarySection.values)'),
          isTrue,
          reason: '$path should build its tabs by iterating LibrarySection, '
              'not by listing LibraryTab entries by hand',
        );
        for (final section in LibrarySection.values) {
          expect(
            source.contains('LibrarySection.${section.name}'),
            isTrue,
            reason: '$path has no branch for ${section.label}',
          );
        }
      });
    }
  });
}
