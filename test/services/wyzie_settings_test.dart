import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/subtitles/providers/wyzie_provider.dart';
import 'package:playtorriomov/services/subtitles/wyzie_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WyzieSettings.setApiKey(null);
  });

  test('no key until the user pastes one', () {
    expect(WyzieSettings.apiKey.value, isNull);
  });

  test('a pasted key is trimmed and kept', () async {
    await WyzieSettings.setApiKey('  wyzie-abc  ');
    expect(WyzieSettings.apiKey.value, 'wyzie-abc');
  });

  test('a blank key clears it rather than sending an empty one', () async {
    await WyzieSettings.setApiKey('wyzie-abc');
    await WyzieSettings.setApiKey('   ');
    expect(WyzieSettings.apiKey.value, isNull);
  });

  test('the key survives a restart', () async {
    await WyzieSettings.setApiKey('wyzie-abc');
    WyzieSettings.apiKey.value = null;
    await WyzieSettings.initialize();
    expect(WyzieSettings.apiKey.value, 'wyzie-abc');
  });

  group('WyzieProvider key', () {
    test('with no key of any kind it sends nothing and finds nothing', () async {
      expect(WyzieProvider.activeApiKey, isNull);
      expect(await WyzieProvider().search('Dune'), isEmpty);
    });

    test('a key the user pasted is the one a search would use', () async {
      await WyzieSettings.setApiKey('wyzie-mine');
      expect(WyzieProvider.activeApiKey, 'wyzie-mine');
    });
  });

  group('WyzieProvider search', () {
    setUp(() async {
      await WyzieSettings.setApiKey('wyzie-mine');
    });

    test('asks by IMDb id with the key, season and episode', () async {
      Uri? asked;
      Map<String, String>? headers;
      await http.runWithClient(
        () => WyzieProvider().search('Dune', imdbId: '0944947', season: 1, episode: 3),
        () => MockClient((req) async {
          asked = req.url;
          headers = req.headers;
          return http.Response('[]', 200);
        }),
      );

      expect(asked!.queryParameters['id'], 'tt0944947');
      expect(asked!.queryParameters['key'], 'wyzie-mine');
      expect(asked!.queryParameters['season'], '1');
      expect(asked!.queryParameters['episode'], '3');
      expect(asked!.queryParameters.containsKey('query'), isFalse);
      expect(headers!['x-api-key'], 'wyzie-mine');
    });

    test('without an IMDb id it searches by title', () async {
      Uri? asked;
      await http.runWithClient(
        () => WyzieProvider().search('Dune'),
        () => MockClient((req) async {
          asked = req.url;
          return http.Response('[]', 200);
        }),
      );

      expect(asked!.queryParameters['query'], 'Dune');
      expect(asked!.queryParameters.containsKey('id'), isFalse);
    });

    test('each track becomes a variant, keeps the hearing-impaired flag, and a track with no url is dropped',
        () async {
      final body = json.encode([
        {
          'url': 'https://sub.wyzie.io/a.srt',
          'language': 'es',
          'release': 'Dune.2021.WEB',
          'format': 'srt',
          'isHearingImpaired': true,
        },
        {'url': 'https://sub.wyzie.io/b.srt', 'lang': 'en', 'format': 'SRT'},
        {'language': 'fr'},
      ]);
      final results = await http.runWithClient(
        () => WyzieProvider().search('Dune', imdbId: 'tt0944947'),
        () => MockClient((_) async => http.Response(body, 200)),
      );

      expect(results.length, 2);
      expect(results.first.downloadUrl, 'https://sub.wyzie.io/a.srt');
      expect(results.first.title, 'Dune.2021.WEB [CC]');
      expect(results.first.isHearingImpaired, isTrue);
      expect(results.last.format, 'srt');
      expect(results.last.isHearingImpaired, isFalse);
    });

    test('a 429 from the daily quota gives no results and no thrown error', () async {
      final results = await http.runWithClient(
        () => WyzieProvider().search('Dune', imdbId: 'tt0944947'),
        () => MockClient((_) async => http.Response('quota exceeded', 429)),
      );

      expect(results, isEmpty);
    });
  });
}
