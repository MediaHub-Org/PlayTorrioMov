// test/services/anime_seasons_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/services/anime/anime_seasons.dart';
import 'package:playtorriomov/services/anime/kitsu_service.dart';

Map<String, dynamic> kitsuShow(String id, String subtype, String start) => {
      'id': id,
      'type': 'anime',
      'attributes': {
        'canonicalTitle': 'Show $id',
        'subtype': subtype,
        'startDate': start,
        'status': 'finished',
        'episodeCount': 25,
      },
    };

Map<String, dynamic> link(String role, String destId) => {
      'type': 'media-relationships',
      'attributes': {'role': role},
      'relationships': {
        'destination': {
          'data': {'type': 'anime', 'id': destId},
        },
      },
    };

http.Response json200(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );

/// A three-season show: 7001 -> 7002 -> 7003, with a movie off 7001.
http.Response relationsFor(String path) {
  if (path.contains('/anime/7001/media-relationships')) {
    return json200({
      'data': [link('sequel', '7002'), link('sequel', '7901')],
      'included': [
        kitsuShow('7002', 'TV', '2017-04-01'),
        kitsuShow('7901', 'movie', '2014-11-22'),
      ],
    });
  }
  if (path.contains('/anime/7002/media-relationships')) {
    return json200({
      'data': [link('prequel', '7001'), link('sequel', '7003')],
      'included': [
        kitsuShow('7001', 'TV', '2013-04-07'),
        kitsuShow('7003', 'TV', '2019-04-28'),
      ],
    });
  }
  if (path.contains('/anime/7003/media-relationships')) {
    return json200({
      'data': [link('prequel', '7002')],
      'included': [kitsuShow('7002', 'TV', '2017-04-01')],
    });
  }
  return json200({'data': [], 'included': []});
}

void main() {
  test('a title\'s TV sequels and prequels are seasons, movies are not', () async {
    final seasons = await http.runWithClient(
      () => KitsuService.instance.seasonNeighbors(7001),
      () => MockClient((req) async => relationsFor(req.url.path)),
    );
    expect(seasons.map((s) => s.id), [-7002]);
    expect(seasons.single.format, 'TV');
  });

  test('the chain is followed both ways and comes back oldest first', () async {
    final first = AnimeMedia(id: -7002, format: 'TV', seasonYear: 2017);
    final seasons = await http.runWithClient(
      () => AnimeSeasons.of(first),
      () => MockClient((req) async => relationsFor(req.url.path)),
    );
    expect(seasons.map((s) => s.id), [-7001, -7002, -7003]);
    expect(seasons.map((s) => s.seasonYear), [2013, 2017, 2019]);
  });

  test('a show with no linked seasons is a season of one', () async {
    final alone = AnimeMedia(id: -7100, format: 'TV', seasonYear: 2020);
    final seasons = await http.runWithClient(
      () => AnimeSeasons.of(alone),
      () => MockClient((_) async => json200({'data': [], 'included': []})),
    );
    expect(seasons.map((s) => s.id), [-7100]);
  });

  test('a loop of links stops instead of walking forever', () async {
    final loop = AnimeMedia(id: -7200, format: 'TV', seasonYear: 2021);
    var requests = 0;
    final seasons = await http.runWithClient(
      () => AnimeSeasons.of(loop),
      () => MockClient((req) async {
        requests++;
        return json200({
          'data': [link('sequel', '7200')],
          'included': [kitsuShow('7200', 'TV', '2021-01-01')],
        });
      }),
    );
    expect(seasons.map((s) => s.id), [-7200]);
    expect(requests, lessThan(10));
  });
}
