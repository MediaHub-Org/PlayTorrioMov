// test/services/tmdb_credits_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tmdb/tmdb_service.dart';

Map<String, dynamic> crew(String name, String job) => {
  'name': name,
  'job': job,
  'profile_path': '/x.jpg',
};

void main() {
  group('TmdbService.parseCredits', () {
    test('reads the crew half, which used to be decoded and dropped', () {
      // /credits returns cast AND crew in one response. The crew half was
      // being thrown away, so a title whose addon sent no director showed an
      // empty Direction section even with a working TMDB key.
      final credits = TmdbService.parseCredits({
        'cast': [
          {'name': 'Brad Pitt', 'character': 'Tyler Durden'},
        ],
        'crew': [crew('David Fincher', 'Director')],
      });

      expect(credits.cast.single.name, 'Brad Pitt');
      expect(credits.cast.single.character, 'Tyler Durden');
      expect(credits.crew.single.name, 'David Fincher');
      expect(credits.crew.single.job, 'Director');
    });

    test('keeps only the jobs worth showing under Direction', () {
      // TMDB's crew array runs to every gaffer and boom operator on a
      // feature; listing all of it would bury the names anyone looks for.
      final credits = TmdbService.parseCredits({
        'crew': [
          crew('A Director', 'Director'),
          crew('A Writer', 'Writer'),
          crew('A Gaffer', 'Gaffer'),
          crew('A Grip', 'Best Boy Electric'),
          crew('A Composer', 'Original Music Composer'),
        ],
      });

      expect(
        credits.crew.map((c) => c.name),
        ['A Director', 'A Writer'],
      );
    });

    test('one person holding several jobs gets one card', () {
      // Writer-directors are listed once per job by TMDB.
      final credits = TmdbService.parseCredits({
        'crew': [
          crew('Greta Gerwig', 'Director'),
          crew('Greta Gerwig', 'Writer'),
          crew('Greta Gerwig', 'Screenplay'),
        ],
      });

      expect(credits.crew.length, 1);
      expect(credits.crew.single.job, 'Director');
    });

    test('a body with no crew still yields the cast', () {
      final credits = TmdbService.parseCredits({
        'cast': [
          {'name': 'Solo'},
        ],
      });

      expect(credits.cast.length, 1);
      expect(credits.crew, isEmpty);
      expect(credits.isEmpty, isFalse);
    });

    test('malformed bodies are empty, not a crash', () {
      expect(TmdbService.parseCredits(null).isEmpty, isTrue);
      expect(TmdbService.parseCredits('nope').isEmpty, isTrue);
      expect(
        TmdbService.parseCredits({'cast': 'not-a-list', 'crew': 7}).isEmpty,
        isTrue,
      );
    });
  });

  group('TmdbService.parseFindResponse', () {
    // Without this lookup nothing else in this file ever runs in production:
    // MovieDetail.tmdbId comes from `moviedb_id`, which Cinemeta and most
    // Stremio addons do not send, so the credits request was never made and
    // the details page fell back to plain name strings.
    test('reads a movie id', () {
      expect(
        TmdbService.parseFindResponse({
          'movie_results': [
            {'id': 550, 'title': 'Fight Club'},
          ],
        }, isTvShow: false),
        '550',
      );
    });

    test('reads a tv id', () {
      expect(
        TmdbService.parseFindResponse({
          'tv_results': [
            {'id': 1396, 'name': 'Breaking Bad'},
          ],
        }, isTvShow: true),
        '1396',
      );
    });

    test('does not read a tv id when asking for a movie', () {
      // TMDB answers every /find with all five result arrays; taking the
      // wrong one would fetch a completely different title's credits.
      expect(
        TmdbService.parseFindResponse({
          'movie_results': const [],
          'tv_results': [
            {'id': 1396},
          ],
        }, isTvShow: false),
        isNull,
      );
    });

    test('an episode id resolves to its show', () {
      // Ids arrive as `tt0903747:1:5` too; the show is what has credits.
      expect(
        TmdbService.parseFindResponse({
          'tv_results': const [],
          'tv_episode_results': [
            {'id': 62085, 'show_id': 1396},
          ],
        }, isTvShow: true),
        '1396',
      );
    });

    test('no match is null, not a crash', () {
      expect(
        TmdbService.parseFindResponse({
          'movie_results': const [],
          'tv_results': const [],
        }, isTvShow: false),
        isNull,
      );
      expect(TmdbService.parseFindResponse(null, isTvShow: false), isNull);
      expect(
        TmdbService.parseFindResponse({'movie_results': 'nope'}, isTvShow: false),
        isNull,
      );
    });
  });
}
