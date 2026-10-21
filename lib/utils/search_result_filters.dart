import '../models/anime/anime_media.dart';
import '../models/movie/movie.dart';
import '../models/movie/movie_section.dart';
import '../models/movie/movie_year.dart';

/// The narrowing filters the search page offers on every kind of result: a
/// decade, a minimum rating, a genre, and an alphabetical order.
///
/// They apply to what came back rather than re-querying, so changing one is
/// instant. An anime result carries its genres from AniList. A film or series
/// result does not: the page reads its genres from its metadata, and only once
/// a genre is picked, so a search with no genre picked costs no extra requests.
///
/// A title that does not say its year (or its rating) is left out while that
/// filter is on, not guessed at, the same rule the Anime page's decade filter
/// has always had: absent from a decade beats shown under the wrong one.
bool decadeMatches(int? year, int? decade) =>
    decade == null || (year != null && year ~/ 10 * 10 == decade);

bool ratingMatches(double? rating, double? minRating) =>
    minRating == null || (rating != null && rating >= minRating);

/// Whether a title's genres include [genre], ignoring case. A title whose genres
/// are not known yet is left out while a genre is on, the same as one with no
/// year under a decade.
bool genreMatches(List<String>? genres, String? genre) =>
    genre == null ||
    (genres != null &&
        genres.any((g) => g.toLowerCase() == genre.toLowerCase()));

/// A film or series' rating on the 0-10 scale, or null when it has none.
double? movieRatingOf(Movie movie) => double.tryParse(movie.imdbRating ?? '');

/// An anime's AniList score as 0-10, or null when it has none yet (AniList
/// reports 0 for unscored).
double? animeRatingOf(AnimeMedia anime) =>
    anime.averageScore > 0 ? anime.averageScore / 10 : null;

/// The order a search's results come back in: as the addons ranked them, or by
/// title, either way.
enum SearchSort { relevance, az, za }

/// [items] in the order [sort] asks for, by the title [titleOf] reads. The
/// relevance order is the addon's own, so it comes back unchanged.
List<T> sortedByTitle<T>(
  List<T> items,
  String Function(T) titleOf,
  SearchSort sort,
) {
  if (sort == SearchSort.relevance) return items;
  final sorted = List<T>.of(items)
    ..sort((a, b) => titleOf(a).toLowerCase().compareTo(titleOf(b).toLowerCase()));
  return sort == SearchSort.za ? sorted.reversed.toList() : sorted;
}

/// [genreOf] reads a title's genres from wherever they are kept; a search
/// answer does not carry them, so the page looks them up once a genre is on.
List<MovieSection> filterSections(
  List<MovieSection> sections, {
  int? decade,
  double? minRating,
  String? genre,
  List<String>? Function(Movie movie)? genreOf,
  SearchSort sort = SearchSort.relevance,
}) {
  if (decade == null &&
      minRating == null &&
      genre == null &&
      sort == SearchSort.relevance) {
    return sections;
  }
  final out = <MovieSection>[];
  for (final section in sections) {
    final kept = sortedByTitle(
      section.movies
          .where(
            (m) =>
                decadeMatches(startYearOf(m.year), decade) &&
                ratingMatches(movieRatingOf(m), minRating) &&
                genreMatches(genreOf?.call(m), genre),
          )
          .toList(),
      (m) => m.name,
      sort,
    );
    // A section with nothing left is dropped rather than shown empty.
    if (kept.isEmpty) continue;
    out.add(
      MovieSection(
        title: section.title,
        subtitle: section.subtitle,
        contentType: section.contentType,
        addonBaseUrl: section.addonBaseUrl,
        catalog: section.catalog,
        movies: kept,
      ),
    );
  }
  return out;
}

List<AnimeMedia> filterAnime(
  List<AnimeMedia> anime, {
  int? decade,
  double? minRating,
  String? genre,
  SearchSort sort = SearchSort.relevance,
}) {
  if (decade == null &&
      minRating == null &&
      genre == null &&
      sort == SearchSort.relevance) {
    return anime;
  }
  final kept = anime
      .where(
        (a) =>
            decadeMatches(a.seasonYear > 0 ? a.seasonYear : null, decade) &&
            ratingMatches(animeRatingOf(a), minRating) &&
            genreMatches(a.genres, genre),
      )
      .toList();
  return sortedByTitle(kept, (a) => a.displayTitle, sort);
}
