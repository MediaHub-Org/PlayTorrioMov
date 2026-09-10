// test/services/builtin_providers_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/scraper/builtin_providers_service.dart';
import 'package:playtorriomov/services/scraper/stream_scraper.dart';

/// Two stand-ins for real scrapers. What matters is that they are distinct
/// classes with the same `name` -- which is exactly how the real ones are
/// shaped, and why `id` cannot be `name`.
class AlphaScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';
}

class BetaScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrioHTTP';
}

class SwarmScraper extends StreamScraper {
  @override
  String get name => 'PlayTorrio';

  @override
  bool get isTorrent => true;
}

void main() {
  group('StreamScraper identity', () {
    test('id distinguishes scrapers that share a source label', () {
      // All 46 HTTP scrapers report name 'PlayTorrioHTTP', so keying
      // preferences on `name` would switch all of them off at once.
      expect(AlphaScraper().name, BetaScraper().name);
      expect(AlphaScraper().id, isNot(BetaScraper().id));
    });

    test('displayName drops the Scraper suffix', () {
      expect(AlphaScraper().displayName, 'Alpha');
      expect(SwarmScraper().displayName, 'Swarm');
    });

    test('only torrent scrapers declare themselves torrent', () {
      expect(AlphaScraper().isTorrent, isFalse);
      expect(SwarmScraper().isTorrent, isTrue);
    });
  });

  group('BuiltinProvidersService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      BuiltinProvidersService.resetForTest();
      await BuiltinProvidersService.initialize();
    });

    test('a provider it has never heard of is enabled', () {
      // The store holds exceptions, not a roster: this is what lets a newly
      // ported scraper go live without a preferences migration.
      expect(BuiltinProvidersService.isEnabled('SomeBrandNewScraper'), isTrue);
    });

    test('disabling one provider leaves the others alone', () async {
      await BuiltinProvidersService.setEnabled('AlphaScraper', false);

      expect(BuiltinProvidersService.isEnabled('AlphaScraper'), isFalse);
      expect(BuiltinProvidersService.isEnabled('BetaScraper'), isTrue);
    });

    test('re-enabling clears the exception', () async {
      await BuiltinProvidersService.setEnabled('AlphaScraper', false);
      await BuiltinProvidersService.setEnabled('AlphaScraper', true);

      expect(BuiltinProvidersService.isEnabled('AlphaScraper'), isTrue);
    });

    test('the choice survives a restart', () async {
      await BuiltinProvidersService.setEnabled('AlphaScraper', false);

      // Same on-disk store, fresh in-memory state.
      BuiltinProvidersService.resetForTest();
      expect(BuiltinProvidersService.isEnabled('AlphaScraper'), isTrue);
      await BuiltinProvidersService.initialize();

      expect(BuiltinProvidersService.isEnabled('AlphaScraper'), isFalse);
    });

    test('enableAll only touches the ids it is given', () async {
      await BuiltinProvidersService.disableAll(['AlphaScraper', 'GoneScraper']);
      await BuiltinProvidersService.enableAll(['AlphaScraper']);

      expect(BuiltinProvidersService.isEnabled('AlphaScraper'), isTrue);
      expect(BuiltinProvidersService.isEnabled('GoneScraper'), isFalse);
    });

    test('counts how many of a set are off, for the settings badge', () async {
      await BuiltinProvidersService.setEnabled('AlphaScraper', false);

      expect(
        BuiltinProvidersService.disabledCountAmong([
          'AlphaScraper',
          'BetaScraper',
        ]),
        1,
      );
    });

    test('revision advances on every change so the UI can rebuild', () async {
      final before = BuiltinProvidersService.revision.value;
      await BuiltinProvidersService.setEnabled('AlphaScraper', false);

      expect(BuiltinProvidersService.revision.value, greaterThan(before));
    });
  });

  group('ScraperManager', () {
    test('exposes the scrapers it actually registered', () {
      final manager = ScraperManager.instance;
      manager.registerScraper(AlphaScraper());
      manager.registerScraper(BetaScraper());
      // Registration de-duplicates on runtime type, so a second call from a
      // second stream fetch does not double the settings list.
      manager.registerScraper(AlphaScraper());

      final ids = manager.scrapers.map((s) => s.id).toList();
      expect(ids.where((id) => id == 'AlphaScraper').length, 1);
      expect(ids, contains('BetaScraper'));
    });

    test('the exposed list cannot be mutated by its callers', () {
      expect(
        () => ScraperManager.instance.scrapers.add(AlphaScraper()),
        throwsUnsupportedError,
      );
    });
  });
}
