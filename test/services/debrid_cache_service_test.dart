// Which torrents the viewer's debrid service already has. The request shapes
// and response readings below follow each provider's documented lookup, but
// none was called with a real account when this was written, so the fixtures
// pin how this code reads them and nothing about what the provider sends
// today. The service is built to survive that: an unknown shape is "no marks".
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtorriomov/services/debrid/debrid_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const c = 'cccccccccccccccccccccccccccccccccccccccc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeInfoHash', () {
    test('lower-cases a 40-character hex hash', () {
      expect(DebridCacheService.normalizeInfoHash(a.toUpperCase()), a);
    });

    test('is null for anything that is not one', () {
      expect(DebridCacheService.normalizeInfoHash(null), isNull);
      expect(DebridCacheService.normalizeInfoHash(''), isNull);
      expect(DebridCacheService.normalizeInfoHash('abc'), isNull);
      expect(
        DebridCacheService.normalizeInfoHash('magnet:?xt=urn:btih:$a'),
        isNull,
        reason: 'a magnet is not a hash; the caller passes the hash',
      );
      expect(
        DebridCacheService.normalizeInfoHash('${a}zz'),
        isNull,
      );
    });
  });

  group('requests', () {
    test('TorBox sends the hashes comma-separated with a bearer token', () {
      final r = DebridCacheService.buildRequest('TorBox', 'KEY', [a, b])!;

      expect(r.uri.host, 'api.torbox.app');
      expect(r.uri.path, '/v1/api/torrents/checkcached');
      expect(r.uri.queryParameters['hash'], '$a,$b');
      expect(r.headers['Authorization'], 'Bearer KEY');
    });

    test('Premiumize repeats items[] and carries the key in the query', () {
      final r = DebridCacheService.buildRequest('Premiumize', 'K&Y', [a, b])!;

      expect(r.uri.path, '/api/cache/check');
      expect(r.uri.query, contains('items%5B%5D=$a'));
      expect(r.uri.query, contains('items%5B%5D=$b'));
      expect(r.uri.queryParameters['apikey'], 'K&Y',
          reason: 'the key is encoded, not spliced in');
    });

    test('AllDebrid and Debrid-Link ask by hash with a bearer token', () {
      final ad = DebridCacheService.buildRequest('AllDebrid', 'KEY', [a])!;
      expect(ad.uri.path, '/v4/magnet/instant');
      expect(ad.uri.query, contains('magnets%5B%5D=$a'));
      expect(ad.headers['Authorization'], 'Bearer KEY');

      final dl = DebridCacheService.buildRequest('Debrid-Link', 'KEY', [a, b])!;
      expect(dl.uri.path, '/api/v2/seedbox/cached');
      expect(dl.uri.queryParameters['url'], '$a,$b');
    });

    test('Real-Debrid has no lookup, so there is no request', () {
      expect(DebridCacheService.buildRequest('Real-Debrid', 'KEY', [a]), isNull);
    });
  });

  group('responses', () {
    test('TorBox: a map keyed by the cached hashes', () {
      final cached = DebridCacheService.parseResponse(
        'TorBox',
        {'success': true, 'data': {a: {'name': 'x'}}},
        [a, b],
      );
      expect(cached, {a});
    });

    test('TorBox: nothing cached is an empty answer, not an unknown one', () {
      for (final data in [null, false, <String, dynamic>{}, <dynamic>[]]) {
        expect(
          DebridCacheService.parseResponse(
            'TorBox',
            {'success': true, 'data': data},
            [a],
          ),
          isEmpty,
          reason: '$data',
        );
      }
    });

    test('TorBox: a failure is unknown, never "nothing cached"', () {
      expect(
        DebridCacheService.parseResponse('TorBox', {'success': false}, [a]),
        isNull,
      );
    });

    test('Premiumize: booleans answer by position', () {
      final cached = DebridCacheService.parseResponse(
        'Premiumize',
        {'status': 'success', 'response': [false, true, true]},
        [a, b, c],
      );
      expect(cached, {b, c});
    });

    test('Premiumize: an answer of the wrong length is not trusted', () {
      expect(
        DebridCacheService.parseResponse(
          'Premiumize',
          {'status': 'success', 'response': [true]},
          [a, b],
        ),
        isNull,
      );
    });

    test('AllDebrid: instant entries by hash or by magnet', () {
      final cached = DebridCacheService.parseResponse(
        'AllDebrid',
        {
          'status': 'success',
          'data': {
            'magnets': [
              {'hash': a, 'instant': true},
              {'magnet': 'magnet:?xt=urn:btih:${b.toUpperCase()}', 'instant': true},
              {'hash': c, 'instant': false},
            ],
          },
        },
        [a, b, c],
      );
      expect(cached, {a, b});
    });

    test('Debrid-Link: a map keyed by hash', () {
      final cached = DebridCacheService.parseResponse(
        'Debrid-Link',
        {'success': true, 'value': {b: {}}},
        [a, b],
      );
      expect(cached, {b});
    });

    test('anything that is not a JSON object is unknown', () {
      for (final service in ['TorBox', 'Premiumize', 'AllDebrid', 'Debrid-Link']) {
        expect(DebridCacheService.parseResponse(service, 'oops', [a]), isNull);
        expect(DebridCacheService.parseResponse(service, [1], [a]), isNull);
      }
    });
  });

  group('prefetch', () {
    late DebridCacheService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = DebridCacheService.instance..clear();
    });

    test('does nothing without a configured service', () async {
      var calls = 0;
      await http.runWithClient(
        () => service.prefetch([a, b]),
        () => MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(calls, 0);
      expect(service.isCached(a), isNull);
    });

    test('marks what TorBox lists and nothing else', () async {
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'TorBox',
        'torbox_api_key': 'KEY',
      });
      Uri? asked;
      await http.runWithClient(
        () => service.prefetch([a, b, 'not-a-hash']),
        () => MockClient((req) async {
          asked = req.url;
          return http.Response(
            json.encode({'success': true, 'data': {a: {}}}),
            200,
          );
        }),
      );

      expect(asked!.queryParameters['hash'], '$a,$b',
          reason: 'only real hashes are sent');
      expect(service.isCached(a), isTrue);
      expect(service.isCached(b), isNull,
          reason: 'not listed is not marked, and is not claimed to be absent');
      expect(service.cachedHashes, {a});
    });

    test('asks once for a hash it already has an answer for', () async {
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'TorBox',
        'torbox_api_key': 'KEY',
      });
      var calls = 0;
      await http.runWithClient(() async {
        await service.prefetch([a]);
        await service.prefetch([a]);
      }, () => MockClient((_) async {
        calls++;
        return http.Response(json.encode({'success': true, 'data': {}}), 200);
      }));

      expect(calls, 1);
    });

    test('a failing provider is left alone instead of asked for every batch',
        () async {
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'TorBox',
        'torbox_api_key': 'KEY',
      });
      var calls = 0;
      await http.runWithClient(() async {
        await service.prefetch([a]);
        await service.prefetch([b]);
      }, () => MockClient((_) async {
        calls++;
        return http.Response('boom', 500);
      }));

      expect(calls, 1);
      expect(service.isCached(a), isNull, reason: 'a failure marks nothing');
    });

    test('Real-Debrid is never asked', () async {
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'Real-Debrid',
        'real_debrid_api_key': 'KEY',
      });
      var calls = 0;
      await http.runWithClient(
        () => service.prefetch([a]),
        () => MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(calls, 0);
    });

    test('tells listeners when answers arrive', () async {
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'TorBox',
        'torbox_api_key': 'KEY',
      });
      final before = service.changes.value;
      await http.runWithClient(
        () => service.prefetch([a]),
        () => MockClient((_) async => http.Response(
              json.encode({'success': true, 'data': {a: {}}}),
              200,
            )),
      );

      expect(service.changes.value, greaterThan(before));
    });
  });
}
