import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../anime/anilist_service.dart';

/// Which rows appear on the Films, Series and Anime home pages.
///
/// The same shape as the Live TV category manager ([IptvSettings]), which
/// is where the pattern comes from: everything shows by default and a
/// toggle hides a row. Two lists per section make that stick across
/// releases and installs:
///
/// - `visible`: what shows right now.
/// - `known`: every id ever seen -- the defaults snapshot plus addon
///   catalog rows (`catalog:<title>`) registered when their page first
///   loads, hidden or not.
///
/// Telling those apart is what keeps two promises at once. A row added by
/// a later release (in defaults but never known) still shows, while a
/// default the viewer hid (known but not visible) stays hidden across
/// restarts -- restarting used to re-append every missing default, so
/// hiding one never survived. Hiding a dynamic row likewise never forgets
/// it: re-registering one leaves visibility exactly as it was, and only
/// its checkbox brings it back. Reset restores the factory rows; catalog
/// rows forgotten that way show again the next time their section loads,
/// as if newly installed.
enum HomeSection { movies, series, anime }

abstract final class HomeRowsSettings {
  static const _keyMovies = 'home_rows_movies';
  static const _keySeries = 'home_rows_series';
  static const _keyAnime = 'home_rows_anime';
  static const _keyKnownMovies = 'home_rows_known_movies';
  static const _keyKnownSeries = 'home_rows_known_series';
  static const _keyKnownAnime = 'home_rows_known_anime';

  /// Built-in row ids per section. The anime ids match the nine rows
  /// [AnimePage] builds; the films/series ones match [TypeCatalogPage].
  static const List<String> defaultMovies = [
    'topRated',
    'latestReleases',
    'documentaries',
    'comingSoon',
  ];
  static const List<String> defaultSeries = [
    'topRated',
    'latestReleases',
    'documentaries',
    'comingSoon',
    'upcomingCalendar',
  ];
  static const List<String> defaultAnime = [
    'trending',
    'season',
    'top',
    'classics',
    'upcoming',
    'action',
    'romance',
    'fantasy',
    'scifi',
  ];

  static final ValueNotifier<List<String>> visibleMovies =
      ValueNotifier<List<String>>(List.from(defaultMovies));
  static final ValueNotifier<List<String>> visibleSeries =
      ValueNotifier<List<String>>(List.from(defaultSeries));
  static final ValueNotifier<List<String>> visibleAnime =
      ValueNotifier<List<String>>(List.from(defaultAnime));

  static final Map<HomeSection, List<String>> _known = {
    HomeSection.movies: [],
    HomeSection.series: [],
    HomeSection.anime: [],
  };

  static List<String> defaultsFor(HomeSection section) => switch (section) {
        HomeSection.movies => defaultMovies,
        HomeSection.series => defaultSeries,
        HomeSection.anime => defaultAnime,
      };

  static ValueNotifier<List<String>> visibleFor(HomeSection section) =>
      switch (section) {
        HomeSection.movies => visibleMovies,
        HomeSection.series => visibleSeries,
        HomeSection.anime => visibleAnime,
      };

  /// Every id the settings page lists, in display order: the built-ins
  /// first, then registered dynamic rows in the order they were first seen.
  static List<String> displayIds(HomeSection section) => [
        ...defaultsFor(section),
        ..._known[section]!.where(
          (id) => !defaultsFor(section).contains(id),
        ),
      ];

  static String _visibleKeyFor(HomeSection section) => switch (section) {
        HomeSection.movies => _keyMovies,
        HomeSection.series => _keySeries,
        HomeSection.anime => _keyAnime,
      };

  static String _knownKeyFor(HomeSection section) => switch (section) {
        HomeSection.movies => _keyKnownMovies,
        HomeSection.series => _keyKnownSeries,
        HomeSection.anime => _keyKnownAnime,
      };

  static Future<void> _persist(HomeSection section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _visibleKeyFor(section),
      visibleFor(section).value,
    );
    await prefs.setStringList(_knownKeyFor(section), List.from(_known[section]!));
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    for (final section in HomeSection.values) {
      final savedVisible = prefs.getStringList(_visibleKeyFor(section));
      final savedKnown = prefs.getStringList(_knownKeyFor(section)) ?? [];
      final fresh = defaultsFor(section)
          .where((id) => !savedKnown.contains(id))
          .toList();
      _known[section] = [...savedKnown, ...fresh];
      if (savedVisible != null && savedVisible.isNotEmpty) {
        visibleFor(section).value = [
          ...savedVisible,
          ...fresh.where((id) => !savedVisible.contains(id)),
        ];
      } else {
        visibleFor(section).value = List.from(defaultsFor(section));
      }
    }
  }

  static bool isVisible(HomeSection section, String id) =>
      visibleFor(section).value.contains(id);

  /// Hides or shows one row. Like the Live TV categories, hiding the last
  /// visible row is refused: a home page with no rows at all reads as
  /// broken, not minimal.
  static Future<void> toggleRow(
    HomeSection section,
    String id, {
    required bool visible,
  }) async {
    final list = List<String>.from(visibleFor(section).value);
    if (visible) {
      if (!list.contains(id)) list.add(id);
    } else {
      if (list.length > 1) list.remove(id);
    }
    visibleFor(section).value = list;
    _known[section] = [
      ..._known[section]!,
      ...defaultsFor(section).where((known) => !_known[section]!.contains(known)),
    ];
    await _persist(section);
  }

  /// Registers row ids a page just built. Only addon catalog sections need
  /// this -- their titles come from installed addons, so they cannot be
  /// listed up front. A brand-new id shows immediately; an already known
  /// one is left exactly as the viewer left it, hidden or not. A no-op
  /// when nothing is new, without touching the notifier, so ordinary
  /// rebuilds stay quiet.
  static Future<void> registerRows(
    HomeSection section,
    Iterable<String> ids,
  ) async {
    final known = _known[section]!;
    final defaults = defaultsFor(section);
    final missingDefaults =
        defaults.where((id) => !known.contains(id)).toList();
    final fresh = ids
        .where((id) => !defaults.contains(id) && !known.contains(id))
        .toList();
    if (missingDefaults.isEmpty && fresh.isEmpty) return;
    // Snapshot first, so a later release can tell these defaults apart
    // from ones it adds itself -- otherwise every restart re-appended
    // them on top of the saved order.
    known.addAll([...missingDefaults, ...fresh]);
    if (fresh.isNotEmpty) {
      visibleFor(section).value = [...visibleFor(section).value, ...fresh];
    }
    await _persist(section);
  }

  static Future<void> resetSection(HomeSection section) async {
    visibleFor(section).value = List.from(defaultsFor(section));
    _known[section] = List.from(defaultsFor(section));
    await _persist(section);
  }

  /// Display name for a row id. Built-ins map to translated strings;
  /// addon catalog sections (`catalog:<title>`) show their own title,
  /// which is data from the addon, not UI. Unknown ids fall back to the
  /// id itself rather than a blank checkbox.
  static String labelOf(
    HomeSection section,
    String id,
    AppLocalizations l10n,
  ) {
    switch (section) {
      case HomeSection.movies:
      case HomeSection.series:
        return switch (id) {
          'topRated' => l10n.catalogTopRated,
          'latestReleases' => l10n.catalogLatestReleases,
          'documentaries' => l10n.catalogDocumentaries,
          'comingSoon' => l10n.catalogComingSoon,
          'upcomingCalendar' => l10n.homeCalendar,
          _ when id.startsWith('catalog:') =>
            id.substring('catalog:'.length),
          _ => id,
        };
      case HomeSection.anime:
        return switch (id) {
          'trending' => l10n.animeTrendingTitle,
          'season' => l10n.animeSeasonTitle(
              AnilistService.currentSeason(),
            ),
          'top' => l10n.animeTopTitle,
          'upcoming' => l10n.animeUpcomingTitle,
          'classics' => l10n.animeClassicsTitle,
          'action' => l10n.animeActionTitle,
          'romance' => l10n.animeRomanceTitle,
          'fantasy' => l10n.animeFantasyTitle,
          'scifi' => l10n.animeSciFiTitle,
          _ => id,
        };
    }
  }
}
