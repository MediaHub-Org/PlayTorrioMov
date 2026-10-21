// test/services/kitsu_service_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtorriomov/services/anime/anilist_service.dart';
import 'package:playtorriomov/services/anime/kitsu_service.dart';

/// One Kitsu anime in JSON:API form, shaped like the live response.
Map<String, dynamic> kitsuAnime({
  String id = '1555',
  String status = 'finished',
  String? averageRating = '84.07',
}) =>
    {
      'id': id,
      'type': 'anime',
      'attributes': {
        'canonicalTitle': 'Naruto: Shippuuden',
        'titles': {'en': 'Naruto: Shippuden', 'ja_jp': 'NARUTO-ナルト- 疾風伝'},
        'slug': 'naruto-shippuden',
        'synopsis': 'Twelve years later.',
        'averageRating': averageRating,
        'startDate': '2007-02-15',
        'status': status,
        'subtype': 'TV',
        'episodeCount': 500,
        'episodeLength': 23,
        'posterImage': {
          'original': 'https://media.kitsu.app/p/original.jpg',
          'large': 'https://media.kitsu.app/p/large.jpg',
          'medium': 'https://media.kitsu.app/p/medium.jpg',
        },
        'coverImage': {'original': 'https://media.kitsu.app/c/original.jpg'},
      },
      'relationships': {
        'categories': {
          'data': [
            {'type': 'categories', 'id': '7'},
            {'type': 'categories', 'id': '9'},
          ],
        },
      },
    };

final _categories = [
  {'type': 'categories', 'id': '7', 'attributes': {'title': 'Action'}},
  {'type': 'categories', 'id': '9', 'attributes': {'title': 'Comedy'}},
];

http.Response json200(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  test('a Kitsu title gets a negative id, its genres, score and episode count', () async {
    final results = await http.runWithClient(
      () => KitsuService.instance.search('naruto mapping'),
      () => MockClient((req) async {
        expect(req.url.host, 'kitsu.io');
        return json200({'data': [kitsuAnime()], 'included': _categories});
      }),
    );

    final anime = results.single;
    expect(anime.id, -1555, reason: 'negative, so it never meets an AniList id');
    expect(KitsuService.isKitsuId(anime.id), isTrue);
    expect(KitsuService.kitsuIdOf(anime.id), 1555);
    expect(anime.titleRomaji, 'Naruto: Shippuuden');
    expect(anime.titleEnglish, 'Naruto: Shippuden');
    expect(anime.genres, ['Action', 'Comedy']);
    expect(anime.averageScore, 84, reason: 'Kitsu gives 0-100 with decimals');
    expect(anime.totalEpisodes, 500);
    expect(anime.durationMinutes, 23);
    expect(anime.format, 'TV');
    expect(anime.status, 'FINISHED');
    expect(anime.seasonYear, 2007);
    expect(anime.coverImageLarge, 'https://media.kitsu.app/p/large.jpg');
  });

  test('a current show is RELEASING, an upcoming one NOT_YET_RELEASED', () async {
    final results = await http.runWithClient(
      () => KitsuService.instance.search('status words'),
      () => MockClient((_) async => json200({
            'data': [
              kitsuAnime(id: '11', status: 'current'),
              kitsuAnime(id: '12', status: 'upcoming'),
            ],
            'included': _categories,
          })),
    );
    expect(results.map((a) => a.status), ['RELEASING', 'NOT_YET_RELEASED']);
  });

  test('a missing score is 0, not a crash', () async {
    final results = await http.runWithClient(
      () => KitsuService.instance.search('no score here'),
      () => MockClient((_) async => json200({
            'data': [kitsuAnime(id: '21', averageRating: null)],
            'included': _categories,
          })),
    );
    expect(results.single.averageScore, 0);
  });

  test('the AniList id of a show comes from Kitsu\'s mapping', () async {
    final id = await http.runWithClient(
      () => KitsuService.instance.anilistIdFor(1555),
      () => MockClient((req) async {
        expect(req.url.path, endsWith('/anime/1555/mappings'));
        return json200({
          'data': [
            {'attributes': {'externalSite': 'myanimelist/anime', 'externalId': '1735'}},
            {'attributes': {'externalSite': 'anilist/anime', 'externalId': '1735'}},
          ],
        });
      }),
    );
    expect(id, 1735);
  });

  test('a failed mapping request is not remembered as "no AniList id"', () async {
    final first = await http.runWithClient(
      () => KitsuService.instance.anilistIdFor(7777),
      () => MockClient((_) async => http.Response('down', 503)),
    );
    expect(first, isNull);

    final second = await http.runWithClient(
      () => KitsuService.instance.anilistIdFor(7777),
      () => MockClient((_) async => json200({
            'data': [
              {'attributes': {'externalSite': 'anilist/anime', 'externalId': '99'}},
            ],
          })),
    );
    expect(second, 99, reason: 'the second look-up was not answered from a miss');
  });

  test('episodes carry their titles and thumbnails in order', () async {
    final episodes = await http.runWithClient(
      () => KitsuService.instance.episodesOf(1555),
      () => MockClient((_) async => json200({
            'data': [
              {
                'attributes': {
                  'number': 1,
                  'canonicalTitle': 'Homecoming',
                  'thumbnail': {'original': 'https://media.kitsu.app/e/1.jpeg'},
                },
              },
              {
                'attributes': {'number': 2, 'canonicalTitle': 'The Akatsuki Makes Its Move'},
              },
            ],
          })),
    );
    expect(episodes.map((e) => e.number), [1, 2]);
    expect(episodes.first.title, 'Homecoming');
    expect(episodes.first.thumbnail, 'https://media.kitsu.app/e/1.jpeg');
    expect(episodes.last.thumbnail, isNull);
  });

  test('a Kitsu error gives an empty answer, not an exception', () async {
    final results = await http.runWithClient(
      () => KitsuService.instance.search('kitsu is down'),
      () => MockClient((_) async => http.Response('oops', 500)),
    );
    expect(results, isEmpty);
  });

  test('when AniList answers 403, the anime lists come from Kitsu', () async {
    final results = await http.runWithClient(
      () => AnilistService.instance.fetchTrendingAnime(perPage: 5),
      () => MockClient((req) async {
        if (req.url.host == 'graphql.anilist.co') {
          return http.Response('{"message":"temporarily disabled"}', 403);
        }
        expect(req.url.host, 'kitsu.io');
        return json200({'data': [kitsuAnime(id: '1555')], 'included': _categories});
      }),
    );
    expect(results, isNotEmpty);
    expect(results.every((a) => KitsuService.isKitsuId(a.id)), isTrue);
  });
}
