@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/audiobook/audiobookbay_scraper.dart';

void main() {
  test('AudiobookBayScraper parses real genre categories from search results', () async {
    final results = await AudiobookBayScraper.search('history');
    expect(results, isNotEmpty);

    // At least one result should have real category data -- this is what
    // powers the genre filter in audiobooks_page.dart, parsed straight out
    // of AudiobookBay's own listing HTML (no external source needed).
    final withCategories = results.where((b) => b.categories.isNotEmpty);
    expect(withCategories, isNotEmpty, reason: 'expected at least one result with parsed categories');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
