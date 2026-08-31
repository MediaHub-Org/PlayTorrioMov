// test/widgets/library_sections_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/widgets/common/library_sections.dart';

/// The three Library pages, one per hub.
const _libraryPages = [
  'lib/pages/collection/collection_page.dart',
  'lib/pages/collection/books_library_page.dart',
  'lib/pages/music/music_page.dart',
];

void main() {
  group('LibrarySection', () {
    test('is exactly four tabs, in a fixed order', () {
      // The mobile bottom bar gives every hub four sections; the Library
      // inside each hub matches, so moving between hubs does not mean
      // relearning where things are.
      expect(LibrarySection.values.length, 4);
      expect(
        LibrarySection.values.map((s) => s.label).toList(),
        ['Saved', 'Continue', 'History', 'Downloads'],
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
