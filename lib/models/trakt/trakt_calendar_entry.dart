/// A single upcoming episode entry from Trakt's or Simkl's calendar.
class TraktCalendarEntry {
  final String firstAired;
  final DateTime firstAiredLocal;
  final int showTraktId;
  final String showTitle;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeTitle;
  final String? episodeOverview;
  final String? imdbId;

  const TraktCalendarEntry({
    required this.firstAired,
    required this.firstAiredLocal,
    required this.showTraktId,
    required this.showTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    this.episodeOverview,
    this.imdbId,
  });

  String? get showImdbId => imdbId;

  static TraktCalendarEntry? fromTraktJson(Map<String, dynamic> json) {
    try {
      final firstAiredStr = json['first_aired'] as String?;
      if (firstAiredStr == null) return null;
      final parsedDate = DateTime.tryParse(firstAiredStr)?.toLocal();
      if (parsedDate == null) return null;

      final episode = json['episode'] as Map<String, dynamic>? ?? {};
      final show = json['show'] as Map<String, dynamic>? ?? {};
      final showIds = show['ids'] as Map<String, dynamic>? ?? {};
      final episodeIds = episode['ids'] as Map<String, dynamic>? ?? {};

      return TraktCalendarEntry(
        firstAired: firstAiredStr,
        firstAiredLocal: parsedDate,
        showTraktId: (showIds['trakt'] as int?) ?? 0,
        showTitle: (show['title'] as String?) ?? 'Unknown Show',
        seasonNumber: (episode['season'] as int?) ?? 1,
        episodeNumber: (episode['number'] as int?) ?? 1,
        episodeTitle: (episode['title'] as String?) ?? 'Episode',
        episodeOverview: episode['overview'] as String?,
        imdbId: (showIds['imdb'] as String?) ?? (episodeIds['imdb'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  static TraktCalendarEntry? fromSimklCalendarJson(Map<String, dynamic> json) {
    try {
      final dateStr = (json['date'] ?? json['first_aired']) as String?;
      if (dateStr == null) return null;
      final parsedDate = DateTime.tryParse(dateStr)?.toLocal();
      if (parsedDate == null) return null;

      final show = json['show'] as Map<String, dynamic>? ?? {};
      final showIds = show['ids'] as Map<String, dynamic>? ?? {};

      return TraktCalendarEntry(
        firstAired: dateStr,
        firstAiredLocal: parsedDate,
        showTraktId: (showIds['simkl'] as int?) ?? 0,
        showTitle: (show['title'] as String?) ?? (json['show_title'] as String?) ?? 'Unknown Show',
        seasonNumber: (json['season'] as int?) ?? 1,
        episodeNumber: (json['episode'] as int?) ?? (json['number'] as int?) ?? 1,
        episodeTitle: (json['title'] as String?) ?? (json['episode_title'] as String?) ?? 'Episode',
        episodeOverview: json['overview'] as String?,
        imdbId: showIds['imdb'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
