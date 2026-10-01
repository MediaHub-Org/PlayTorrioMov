import '../models/anime/anime_media.dart';
import '../models/movie/movie.dart';
import '../models/movie/movie_section.dart';
import '../models/movie/movie_year.dart';

/// The two narrowing filters the search page offers on every kind of result:
/// a decade and a minimum rating.
///
/// They are the ones every catalog can answer. Genre looked like the obvious
/// third, but an addon's search results carry only a name, poster, year and
/// rating -- no genres -- so a genre filter would work for anime and silently
/// match nothing for films and series. A filter that exists on one tab and
/// not the others is the inconsistency this replaces. The page applies them
/// to what came back rather than re-querying, so changing one is instant.
///
/// A title that does not say its year (or its rating) is left out while that
/// filter is on, not guessed at, the same rule the Anime page's decade filter
/// has always had: absent from a decade beats shown under the wrong one.
bool decadeMatches(int? year, int? decade) =>
    decade == null || (year != null && year ~/ 10 * 10 == decade);

bool ratingMatches(double? rating, double? minRating) =>
    minRating == null || (rating != null && rating >= minRating);

/// A film or series' rating on the 0-10 scale, or null when it has none.
double? movieRatingOf(Movie movie) => double.tryParse(movie.imdbRating ?? '');

/// An anime's AniList score as 0-10, or null when it has none yet (AniList
/// reports 0 for unscored).
double? animeRatingOf(AnimeMedia anime) =>
    anime.averageScore > 0 ? anime.averageScore / 10 : null;

List<MovieSection> filterSections(
  List<MovieSection> sections, {
  int? decade,
  double? minRating,
}) {
  if (decade == null && minRating == null) return sections;
  final out = <MovieSection>[];
  for (final section in sections) {
    final kept = section.movies
        .where(
          (m) =>
              decadeMatches(startYearOf(m.year), decade) &&
              ratingMatches(movieRatingOf(m), minRating),
        )
        .toList();
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
}) {
  if (decade == null && minRating == null) return anime;
  return anime
      .where(
        (a) =>
            decadeMatches(a.seasonYear > 0 ? a.seasonYear : null, decade) &&
            ratingMatches(animeRatingOf(a), minRating),
      )
      .toList();
}
