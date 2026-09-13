import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/scraper/sites/enc_dec_embed_scraper.dart';
import 'package:playtorriomov/services/scraper/sites/vidfast.dart';
import 'package:playtorriomov/services/scraper/sites/vidup.dart';

/// The pipeline itself needs the network, so it is covered by the existing
/// tagged smoke tests. What is worth pinning without a network is the part
/// that used to be duplicated: the per-site strings, and the fact that both
/// sites still run the same code.
void main() {
  group('EncDecEmbedScraper subclasses', () {
    test('both sites share one implementation', () {
      // They were two ~200-line files differing in three strings. If one is
      // ever forked back out, this is what notices.
      expect(VidFastScraper(), isA<EncDecEmbedScraper>());
      expect(VidUpScraper(), isA<EncDecEmbedScraper>());
    });

    test('each supplies its own host, slug and label', () {
      final fast = VidFastScraper();
      expect(fast.domain, 'https://vidfast.vc');
      expect(fast.encDecSlug, 'vidfast');
      expect(fast.displayName, 'VidFast');

      final up = VidUpScraper();
      expect(up.domain, 'https://vidup.to');
      expect(up.encDecSlug, 'vidup');
      expect(up.displayName, 'VidUp');
    });

    test('the three strings actually differ between the two', () {
      // A copy-paste subclass that forgot to change the slug would resolve
      // one site's tokens against the other's endpoint and quietly return
      // nothing.
      final fast = VidFastScraper();
      final up = VidUpScraper();
      expect(fast.domain, isNot(up.domain));
      expect(fast.encDecSlug, isNot(up.encDecSlug));
      expect(fast.displayName, isNot(up.displayName));
    });

    test('both report the shared addon name the picker groups by', () {
      expect(VidFastScraper().name, 'PlayTorrioHTTP');
      expect(VidUpScraper().name, 'PlayTorrioHTTP');
    });

    test('every host is https', () {
      for (final s in [VidFastScraper(), VidUpScraper()]) {
        expect(s.domain, startsWith('https://'));
      }
    });
  });
}
