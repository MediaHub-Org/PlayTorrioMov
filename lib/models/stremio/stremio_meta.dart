/// Model representing Stremio meta items used by Trakt and Simkl transformers.
class StremioMeta {
  final String id;
  final String? imdbId;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? description;
  final String? year;
  final double? imdbRating;
  final List<String>? genres;
  final int? addedAtMs;

  const StremioMeta({
    required this.id,
    this.imdbId,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.description,
    this.year,
    this.imdbRating,
    this.genres,
    this.addedAtMs,
  });

  String? get effectiveImdbId => imdbId ?? (id.startsWith('tt') ? id : null);
}
