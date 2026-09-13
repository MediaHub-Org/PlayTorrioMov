import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/scraper/sites/glendale_master_url.dart';

/// These expectations were captured from the three byte-identical copies
/// this module replaced, before they were deleted -- so the test pins the
/// URLs the app actually used to request, not what the consolidated code
/// happens to produce now. Any drift in the transcribed arithmetic shows up
/// here rather than as a site that quietly stops resolving.
void main() {
  const host = 'https://glendale-plumbing.com/c/v1';

  group('glendaleMasterUrl', () {
    test('a film encodes as season 0, episode 0', () {
      expect(
        glendaleMasterUrl(550, null, null),
        '$host/FgBmc7tPzEftN0HnhnyocyGsakmTGay_/master.m3u8',
      );
    });

    test('a series episode encodes its season and episode', () {
      expect(
        glendaleMasterUrl(1399, 1, 1),
        '$host/FwAbxad5LsgqWrjSlGMljRVFsVkgMIF15A/master.m3u8',
      );
      expect(
        glendaleMasterUrl(1399, 10, 24),
        '$host/GQB3IYICb_cZm_wTF23a8N8O8yTeApbeBBY_/master.m3u8',
      );
      expect(
        glendaleMasterUrl(93405, 2, 7),
        '$host/GAC0ChJeuRKM7V1giJEW-0D1YN5TPFTxfaI/master.m3u8',
      );
    });

    test('a half-specified episode is treated as a film', () {
      // Both parts are needed to mean "series"; one alone is ambiguous and
      // the original code fell back to the film encoding.
      expect(glendaleMasterUrl(550, 1, null), glendaleMasterUrl(550, null, null));
      expect(glendaleMasterUrl(550, null, 3), glendaleMasterUrl(550, null, null));
    });

    test('different titles and episodes produce different URLs', () {
      final urls = {
        glendaleMasterUrl(550, null, null),
        glendaleMasterUrl(551, null, null),
        glendaleMasterUrl(1399, 1, 1),
        glendaleMasterUrl(1399, 1, 2),
        glendaleMasterUrl(1399, 2, 1),
      };
      expect(urls.length, 5);
    });

    test('it is deterministic -- the same input always resolves alike', () {
      // There is no nonce or timestamp in the payload, so a cached URL
      // stays valid for as long as the site honours it.
      expect(glendaleMasterUrl(1399, 3, 9), glendaleMasterUrl(1399, 3, 9));
    });

    test('the host and version param are exported for the scrapers', () {
      expect(glendaleHost, 'https://glendale-plumbing.com');
      expect(glendaleVersionParam, '_v=34403446');
      expect(glendaleMasterUrl(550, null, null), startsWith(glendaleHost));
    });
  });
}
