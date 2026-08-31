/// Selection model for resolving continue-watching items or search results.
class AdvancedSearchSelection {
  final String imdbId;
  final bool isSeries;
  final String title;
  final String? year;
  final int? season;
  final int? episode;
  final String? contentType;
  final String? posterUrl;
  final double? traktProgressPercent;
  final bool traktSource;
  final double? simklProgressPercent;
  final bool simklSource;

  const AdvancedSearchSelection({
    required this.imdbId,
    required this.isSeries,
    required this.title,
    this.year,
    this.season,
    this.episode,
    this.contentType,
    this.posterUrl,
    this.traktProgressPercent,
    this.traktSource = false,
    this.simklProgressPercent,
    this.simklSource = false,
  });
}
