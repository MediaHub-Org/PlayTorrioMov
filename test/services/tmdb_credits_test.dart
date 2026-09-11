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
}
