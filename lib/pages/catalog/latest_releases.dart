import '../../models/movie/movie.dart';

/// Sorts [items] by year descending (items with no parseable 4-digit year
/// sort last), truncated to [limit]. Pure and synchronous — the data is
/// already in memory, no network involved.
List<Movie> latestReleases(List<Movie> items, {int limit = 20}) {
  int? yearOf(Movie m) {
    final match = RegExp(r'\d{4}').firstMatch(m.year ?? '');
    return match == null ? null : int.parse(match.group(0)!);
  }

  final sorted = List<Movie>.of(items)
    ..sort((a, b) => (yearOf(b) ?? -1).compareTo(yearOf(a) ?? -1));
  return sorted.take(limit).toList();
}
