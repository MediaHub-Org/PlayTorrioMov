// test/utils/search_result_filters_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/addon/addon.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/movie/movie.dart';
import 'package:playtorriomov/models/movie/movie_section.dart';
import 'package:playtorriomov/utils/search_result_filters.dart';

Movie movie(String name, {String? year, String? rating}) => Movie(
  id: name,
  name: name,
  year: year,
  type: 'movie',
  addonBaseUrl: 'https://addon.test',
  imdbRating: rating,
);

MovieSection section(List<Movie> movies) => MovieSection(
  title: 'Results',
  subtitle: '',
  contentType: 'movie',
  addonBaseUrl: 'https://addon.test',
  catalog: AddonCatalog(type: 'movie', id: 'top'),
  movies: movies,
);

void main() {
  group('filterSections', () {
    final sections = [
      section([
        movie('Old', year: '1994', rating: '8.9'),
        movie('Mid', year: '2012', rating: '6.4'),
        movie('New', year: '2023', rating: '7.8'),
        movie('Unknown'),
      ]),
    ];

    test('with no filter the sections pass through untouched', () {
      expect(identical(filterSections(sections), sections), isTrue);
    });

    test('a decade keeps only that decade, and drops titles with no year', () {
      final out = filterSections(sections, decade: 2010);
      expect(out.single.movies.map((m) => m.name), ['Mid']);
    });

    test('a range like 2022- counts by its start year', () {
      final out = filterSections([
        section([movie('Running', year: '2022–')]),
      ], decade: 2020);
      expect(out.single.movies.single.name, 'Running');
    });

    test('a minimum rating keeps that rating and above, and drops unrated', () {
      final out = filterSections(sections, minRating: 7);
      expect(out.single.movies.map((m) => m.name), ['Old', 'New']);
    });

    test('both together narrow to what satisfies both', () {
      final out = filterSections(sections, decade: 2020, minRating: 7);
      expect(out.single.movies.map((m) => m.name), ['New']);
    });

    test('a section left empty is dropped, not shown empty', () {
      expect(filterSections(sections, decade: 1980), isEmpty);
    });
  });

  group('filterAnime', () {
    const anime = [
      AnimeMedia(id: 1, titleRomaji: 'A', seasonYear: 2006, averageScore: 86),
      AnimeMedia(id: 2, titleRomaji: 'B', seasonYear: 2021, averageScore: 69),
      AnimeMedia(id: 3, titleRomaji: 'C', seasonYear: 2022),
      AnimeMedia(id: 4, titleRomaji: 'D', averageScore: 80),
    ];

    test('decade reads the season year; an undated show is left out', () {
      expect(filterAnime(anime, decade: 2020).map((a) => a.id), [2, 3]);
    });

    test('rating is the AniList score out of ten; unscored is left out', () {
      expect(filterAnime(anime, minRating: 8).map((a) => a.id), [1, 4]);
      expect(filterAnime(anime, minRating: 6).map((a) => a.id), [1, 2, 4]);
    });
  });
}
