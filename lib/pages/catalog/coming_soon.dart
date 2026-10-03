import '../../models/movie/movie.dart';

/// Not yet released, soonest first. Items without a parseable year are
/// skipped: "coming soon" with no date is a guess, and unlike Latest
/// Releases -- where an undated title simply sorts last -- the row only
/// earns its place for dated titles. Pure and synchronous, like its
/// neighbours: the data is already in memory, no network involved.
List<Movie> comingSoon(List<Movie> items, {int limit = 20}) {
  int? yearOf(Movie m) {
    final match = RegExp(r'\d{4}').firstMatch(m.year ?? '');
    return match == null ? null : int.parse(match.group(0)!);
  }

  final now = DateTime.now().year;
  final upcoming = items.where((m) {
    final year = yearOf(m);
    return year != null && year > now;
  }).toList()
    ..sort((a, b) => yearOf(a)!.compareTo(yearOf(b)!));
  return upcoming.take(limit).toList();
}
