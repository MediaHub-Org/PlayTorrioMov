import '../l10n/app_localizations.dart';
/// Tracks the section the user is currently browsing, so search opens on it.
///
/// Each hub/section registers its content type (e.g. 'movie', 'series',
/// 'anime') when it becomes active. The search page reads it once, to
/// pre-select a [SearchFilter] chip. It is a starting point, not a cage: the
/// user can widen to All from the chip row without leaving the page.
abstract final class SearchScope {
  static String? _contentType;

  /// Sets the active search scope. Pass `null` to search everything.
  static void set(String? contentType) {
    _contentType = contentType;
  }

  /// The content type to scope search to, or null for "all".
  static String? get contentType => _contentType;
}

/// The content-type filter the unified search page runs with.
///
/// Search used to mean different things depending on which button opened it:
/// the same icon led to an addon search on Movies and Series, and to a
/// separate AniList page on Anime. One page now serves all three and this
/// decides where a query is actually sent -- addons, AniList, or both.
///
/// Live TV is deliberately not a value here. Its search matches a portal's
/// stream list by keyword rather than searching a title catalog, so a
/// result there is a different kind of object; it keeps its own search.
enum SearchFilter {
  all('all'),
  movie('movie'),
  series('series'),
  anime('anime');

  /// Matches the addon `contentType` strings, so [addonContentType] can pass
  /// it straight through.
  final String id;

  const SearchFilter(this.id);

  /// Chip text, in the app's language.
  String label(AppLocalizations l10n) => switch (this) {
    SearchFilter.all => l10n.commonAll,
    SearchFilter.movie => l10n.libraryFilterMovies,
    SearchFilter.series => l10n.libraryFilterSeries,
    SearchFilter.anime => l10n.libraryFilterAnime,
  };

  /// Reads inside a sentence: "Search $scope". Words for the scope rather than
  /// the chip's label, so the sentence stays one grammatical piece.
  String scopeLabel(AppLocalizations l10n) => switch (this) {
    SearchFilter.all => l10n.searchScopeAll,
    SearchFilter.movie => l10n.searchScopeMovies,
    SearchFilter.series => l10n.searchScopeSeries,
    SearchFilter.anime => l10n.searchScopeAnime,
  };

  /// AniList is a separate API from the addons, so anime-only queries skip
  /// the addon fan-out entirely rather than asking for nothing.
  bool get searchesAddons => this != SearchFilter.anime;

  bool get searchesAnime => this == SearchFilter.all || this == SearchFilter.anime;

  /// `null` means "every catalog" to the addon search.
  String? get addonContentType => this == SearchFilter.all ? null : id;

  /// A scope with no chip of its own (Live TV, or the Library's null) opens
  /// on [all] rather than on a filter the user cannot see or undo.
  static SearchFilter fromScope(String? contentType) {
    for (final filter in values) {
      if (filter.id == contentType) return filter;
    }
    return SearchFilter.all;
  }
}
