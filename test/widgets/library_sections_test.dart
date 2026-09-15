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
    test('is Collections, Continue, Downloads', () {
      // The three library states used to be three of four tabs. They are
      // cards inside Collections now: with user collections added, one tab
      // each would have meant a scrolling pill row nobody reads to the end
      // of. What is left is the three genuinely different questions a
      // Library answers -- what I saved, what I was part-way through, what
      // is on the device.
      expect(
        LibrarySection.values.map((s) => s.label).toList(),
        ['Collections', 'Continue', 'Downloads'],
      );
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

  group('LibraryShelf', () {
    test('is the three states LibraryActionsRow writes', () {
      // A card here has to mean exactly what the button on a details page
      // meant, or the Library stops being where saved things went.
      expect(
        LibraryShelf.values.map((s) => s.name).toList(),
        ['liked', 'watchlist', 'watched'],
      );
    });

    test('every label, icon and colour is distinct', () {
      // The colour is what tells them apart in a grid of same-shaped cards,
      // so two sharing one would undo the point of tinting them at all.
      for (final read in [
        LibraryShelf.values.map((s) => s.label),
        LibraryShelf.values.map((s) => s.icon),
        LibraryShelf.values.map((s) => s.color),
      ]) {
        expect(read.toSet().length, LibraryShelf.values.length);
      }
    });

    test('each carries its own empty-state wording', () {
      // "Nothing here" three times over would leave the user unable to tell
      // which shelf they are looking at.
      for (final shelf in LibraryShelf.values) {
        expect(shelf.emptyTitle, isNotEmpty);
        expect(shelf.emptySubtitle, isNotEmpty);
      }
      expect(
        LibraryShelf.values.map((s) => s.emptyTitle).toSet().length,
        LibraryShelf.values.length,
      );
    });
  });

  group('the Library builds its tabs from the shared spec', () {
    // A source check rather than a widget test: the page needs half the
    // app's services initialised before it will pump, and what matters here
    // is only that it does not hand-roll its own tab list again -- which is
    // exactly how three hubs drifted to 4/5/5 tabs with different names.
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

    test('and draws a card for every built-in shelf', () {
      final source = File(_libraryPages.first).readAsStringSync();
      expect(
        source.contains('for (final shelf in LibraryShelf.values)'),
        isTrue,
        reason: 'a shelf added to the enum must appear in the grid without '
            'the page needing to be edited',
      );
    });
  });
}
