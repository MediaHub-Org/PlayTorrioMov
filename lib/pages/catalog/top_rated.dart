import '../../models/movie/movie.dart';

/// The catalog's most critically acclaimed titles, highest rating first.
///
/// Ratings arrive as strings in whatever shape the addon sent -- "8.7",
/// "8.7/10" -- so only the leading number is read. Titles with no rating
/// sort last and never make the row: without a score there is no claim to
/// acclaim. Pure and synchronous -- the data is already in memory, no
/// network involved. See [latestReleases] for the same shape by year.
List<Movie> topRated(List<Movie> items, {int limit = 18}) {
  double ratingOf(Movie m) {
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(m.imdbRating ?? '');
    return match == null ? 0 : double.tryParse(match.group(0)!) ?? 0;
  }

  final rated = items.where((m) => ratingOf(m) > 0).toList()
    ..sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
  // A shelf of low scores is not "top" anything: below this the catalog
  // simply has nothing acclaimed to show, and the caller skips the row.
  if (rated.length < 4 || ratingOf(rated.first) < 7.0) return const [];
  return rated.take(limit).toList();
}
