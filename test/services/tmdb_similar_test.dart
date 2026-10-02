// test/services/tmdb_similar_test.dart
//
// The details page's Similar Content row reads TMDB's recommendations. The
// parsing is held offline, with the shape of a real `/recommendations` body.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tmdb/tmdb_service.dart';

void main() {
  const body = {
    'page': 1,
    'results': [
      {
        'id': 157336,
        'title': 'Interstellar',
        'poster_path': '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
        'release_date': '2014-11-05',
        'vote_average': 8.4,
        'genre_ids': [12, 18, 878],
        'overview': 'The adventures of a group of explorers...',
      },
      {
        // No poster: a card with nothing to look at is dropped.
        'id': 1,
        'title': 'No Poster',
        'poster_path': null,
        'release_date': '2010-01-01',
      },
      {
        // A series: `name` and `first_air_date`, and no rating yet.
        'id': 66732,
        'name': 'Stranger Things',
        'poster_path': '/x.jpg',
        'first_air_date': '2016-07-15',
        'vote_average': 0,
        'genre_ids': [10765],
      },
      {'id': 2, 'poster_path': '/y.jpg'}, // no title at all
    ],
  };

  test('reads a title into a card', () {
    final items = TmdbService.parseSimilar(body, isTvShow: false);
    final first = items.first;

    expect(first.title, 'Interstellar');
    expect(first.year, 2014);
    expect(first.rating, 8.4);
    expect(first.genre, 'Adventure');
    expect(first.thumbUrl, endsWith('/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg'));
    expect(first.thumbUrl, startsWith('https://image.tmdb.org/'));
    expect(first.tmdbId, 157336);
    expect(first.similarityPercent, isNull, reason: 'TMDB has no such score');
  });

  test('drops what cannot be drawn: no poster, no title', () {
    final items = TmdbService.parseSimilar(body, isTvShow: false);
    expect(items.map((i) => i.title), ['Interstellar', 'Stranger Things']);
  });

  test('a series reads name and first air date, and an unrated one has no '
      'rating', () {
    final series = TmdbService.parseSimilar(body, isTvShow: true).last;

    expect(series.title, 'Stranger Things');
    expect(series.year, 2016);
    expect(series.rating, isNull);
    expect(series.isTv, isTrue);
    expect(series.genre, 'Sci-Fi & Fantasy');
  });

  test('anything that is not a results list is an empty row, not a crash', () {
    expect(TmdbService.parseSimilar(null, isTvShow: false), isEmpty);
    expect(TmdbService.parseSimilar({'results': 'nope'}, isTvShow: false),
        isEmpty);
    expect(TmdbService.parseSimilar({'results': []}, isTvShow: false), isEmpty);
  });

  test('a row is at most twenty cards', () {
    final many = {
      'results': [
        for (var i = 1; i <= 40; i++)
          {'id': i, 'title': 'T$i', 'poster_path': '/p$i.jpg'},
      ],
    };
    expect(TmdbService.parseSimilar(many, isTvShow: false), hasLength(20));
  });
}
