import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/scraper/stream_scraper.dart';

void main() {
  // Most built-in scrapers stamp every source with the same delivery label,
  // so cards and download rows resolve the site through the roster instead.
  const registered = ['HindMoviez', 'VixSrc', 'TorrentGalaxy'];

  group('ScraperManager.resolveProviderName', () {
    test('matches the site head of a source name', () {
      expect(
        ScraperManager.resolveProviderName(
          'PlayTorrioHTTP',
          'HindMoviez • 1080p • MULTI',
          registered,
        ),
        'HindMoviez',
      );
    });

    test('falls back to the add-on name', () {
      // A Stremio release title matches no registered site; the manifest
      // name already is the provider there.
      expect(
        ScraperManager.resolveProviderName(
          'Torrentio',
          'Movie.2024.1080p.WEB-DL',
          registered,
        ),
        'Torrentio',
      );
    });

    test('a numeric head is not a site', () {
      expect(
        ScraperManager.resolveProviderName(
          'PlayTorrioHTTP',
          '111477',
          registered,
        ),
        'PlayTorrioHTTP',
      );
    });

    test('normalizes a known name to the registered casing', () {
      expect(
        ScraperManager.resolveProviderName('vixsrc', null, registered),
        'VixSrc',
      );
    });

    test('empty everything yields Unknown rather than blank', () {
      expect(ScraperManager.resolveProviderName('', null, registered), 'Unknown');
    });
  });
}
