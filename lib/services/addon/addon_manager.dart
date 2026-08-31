import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../utils/search/relevance_scorer.dart';
import '../metadata/metadata_service.dart';

/// Manages installed Stremio metadata addons.
///
/// - Persists addon list + enabled state to SharedPreferences.
/// - On first launch, installs Cinemeta as default.
/// - Provides [fetchAllHomeSections] to aggregate catalogs across all active addons.
class AddonManager {
  AddonManager._();
  static final AddonManager instance = AddonManager._();

  static const String _storageKey = 'installed_addons_v4';

  List<InstalledAddon> _addons = [];
  bool _initialized = false;

  List<InstalledAddon> get addons => List.unmodifiable(_addons);

  List<InstalledAddon> get activeAddons =>
      _addons.where((a) => a.enabled).toList();

  List<InstalledAddon> get activeCatalogAddons =>
      _addons.where((a) => a.isCatalogsActive).toList();

  List<InstalledAddon> get activeSearchAddons =>
      _addons.where((a) => a.isSearchActive).toList();

  List<InstalledAddon> get activeSubtitleAddons =>
      _addons.where((a) => a.isSubtitlesActive).toList();

  List<InstalledAddon> get activeStreamAddons =>
      _addons.where((a) => a.isStreamsActive).toList();

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored != null) {
      try {
        final list = jsonDecode(stored) as List<dynamic>;
        _addons = list
            .map((e) => InstalledAddon.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _addons = [];
      }
    }

    // First launch → install Cinemeta
    if (_addons.isEmpty) {
      try {
        await addAddon('https://v3-cinemeta.strem.io');
      } catch (_) {
        // Offline — will retry next time
      }
    }

    _initialized = true;
  }

  // ── Add / Remove / Toggle ─────────────────────────────────────────────

  /// Install an addon by its base URL or manifest URL.
  Future<InstalledAddon> addAddon(String url) async {
    String baseUrl = url.trim();

    // Convert stremio:// or stremio: URI scheme to https://
    if (baseUrl.startsWith('stremio://')) {
      baseUrl = 'https://${baseUrl.substring('stremio://'.length)}';
    } else if (baseUrl.startsWith('stremio:')) {
      baseUrl = 'https://${baseUrl.substring('stremio:'.length)}';
    } else if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }

    if (baseUrl.endsWith('/manifest.json')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - '/manifest.json'.length);
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Duplicate check by URL
    if (_addons.any((a) => a.baseUrl == baseUrl)) {
      throw Exception('This addon is already installed');
    }

    final manifest = await MetadataService.fetchManifest(baseUrl);

    // Duplicate check by addon ID
    if (_addons.any((a) => a.manifest.id == manifest.id)) {
      throw Exception('An addon with ID "${manifest.id}" is already installed');
    }

    final addon = InstalledAddon(
      baseUrl: baseUrl,
      manifest: manifest,
      enabled: true,
    );

    _addons.add(addon);
    MetadataService.clearCache();
    await _save();
    return addon;
  }

  Future<void> removeAddon(String addonId) async {
    _addons.removeWhere((a) => a.manifest.id == addonId);
    MetadataService.clearCache();
    await _save();
  }

  Future<void> toggleAddon(String addonId, bool enabled) async {
    for (final addon in _addons) {
      if (addon.manifest.id == addonId) {
        addon.enabled = enabled;
        break;
      }
    }
    MetadataService.clearCache();
    await _save();
  }

  Future<void> updateAddonFeature({
    required String addonId,
    bool? enableCatalogs,
    bool? enableSearch,
    bool? enableSubtitles,
    bool? enableStreams,
  }) async {
    for (final addon in _addons) {
      if (addon.manifest.id == addonId) {
        if (enableCatalogs != null) addon.enableCatalogs = enableCatalogs;
        if (enableSearch != null) addon.enableSearch = enableSearch;
        if (enableSubtitles != null) addon.enableSubtitles = enableSubtitles;
        if (enableStreams != null) addon.enableStreams = enableStreams;
        break;
      }
    }
    MetadataService.clearCache();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_addons.map((a) => a.toJson()).toList()),
    );
  }

  // ── Home sections ─────────────────────────────────────────────────────

  /// Fetch all home page sections from every active addon's catalogs.
  /// Each addon's catalogs are fetched concurrently.
  Future<List<MovieSection>> fetchAllHomeSections() async {
    final active = activeCatalogAddons;

    final addonFutures = active.map(_fetchAddonSections);
    final results = await Future.wait(addonFutures);

    final allSections = <MovieSection>[];
    for (final sections in results) {
      allSections.addAll(sections);
    }

    return allSections;
  }

  /// Streams home page sections one by one as they load, so the UI can populate dynamically.
  Stream<MovieSection> streamHomeSections() async* {
    final active = activeCatalogAddons;
    final List<Future<MovieSection?>> sectionFutures = [];

    // 1. Kick off all network requests concurrently
    for (final addon in active) {
      final catalogsToFetch = addon.manifest.catalogs;

      for (final catalog in catalogsToFetch) {
        sectionFutures.add(() async {
          try {
            final movies = await MetadataService.fetchCatalog(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
            );

            if (movies.isEmpty) return null;

            return MovieSection(
              title: _catalogDisplayName(catalog),
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: movies,
            );
          } catch (_) {
            return null; // Gracefully handle failure
          }
        }());
      }
    }

    // 2. Yield them in order so the UI stays stable (top addons appear first)
    for (final future in sectionFutures) {
      final section = await future;
      if (section != null) yield section;
    }
  }

  Future<List<MovieSection>> _fetchAddonSections(
    InstalledAddon addon,
  ) async {
    // Fetch all catalogs that the addon provides
    final catalogsToFetch = addon.manifest.catalogs;

    final futures = catalogsToFetch.map((catalog) async {
      try {
        final movies = await MetadataService.fetchCatalog(
          baseUrl: addon.baseUrl,
          type: catalog.type,
          catalogId: catalog.id,
        );

        return MovieSection(
          title: _catalogDisplayName(catalog),
          subtitle: addon.manifest.name,
          contentType: catalog.type,
          addonBaseUrl: addon.baseUrl,
          catalog: catalog,
          movies: movies,
        );
      } catch (_) {
        return null;
      }
    }).toList();

    final results = await Future.wait(futures);

    return results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();
  }

  /// Fetch catalogs of a single content type (e.g. 'movie' or 'series') across
  /// all active addons, so a section renders only content of that type.
  ///
  /// This is stricter than [fetchAllHomeSections] + client-side filtering:
  /// it only requests catalogs whose manifest declares the requested type, so
  /// a Series section never receives movie-typed catalogs.
  Future<List<MovieSection>> fetchByType(String type) async {
    final active = activeAddons;
    final futures = <Future<MovieSection?>>[];

    for (final addon in active) {
      final typeCatalogs = addon.manifest.catalogs
          .where((c) => c.type == type)
          .toList();

      for (final catalog in typeCatalogs) {
        futures.add(() async {
          try {
            final movies = await MetadataService.fetchCatalog(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
            );
            if (movies.isEmpty) return null;

            // Keep only items whose real type matches the requested type.
            // Items now carry the catalog type as a fallback, so a movie-typed
            // catalog that returns series is filtered out here.
            final typedMovies = movies
                .where((m) => m.type == type)
                .map((m) => Movie(
                      id: m.id,
                      name: m.name,
                      poster: m.poster,
                      year: m.year,
                      type: type,
                      addonBaseUrl: m.addonBaseUrl,
                    ))
                .toList();
            if (typedMovies.isEmpty) return null;

            return MovieSection(
              title: _catalogDisplayName(catalog),
              subtitle: addon.manifest.name,
              contentType: type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: typedMovies,
            );
          } catch (_) {
            return null; // Gracefully handle failure
          }
        }());
      }
    }

    final results = await Future.wait(futures);
    return results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();
  }

  /// Search across all active addons that support search.
  ///
  /// If [contentType] is provided (e.g. 'movie', 'series', 'anime'), only
  /// catalogs of that type are searched, scoping results to a section.
  Future<List<MovieSection>> searchAll(String query, {String? contentType}) async {
    final active = activeSearchAddons;
    final futures = <Future<MovieSection?>>[];

    for (final addon in active) {
      final searchCatalogs = addon.manifest.catalogs
          .where((c) =>
              c.supportsSearch &&
              (contentType == null || c.type == contentType))
          .toList();

      for (final catalog in searchCatalogs) {
        futures.add(() async {
          try {
            final movies = await MetadataService.search(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
              query: query,
            );

            if (movies.isEmpty) return null;

            // Sort movies within this section by relevance score
            final sortedMovies = List<Movie>.from(movies);
            sortedMovies.sort((a, b) {
              final scoreA = RelevanceScorer.score(title: a.name, query: query);
              final scoreB = RelevanceScorer.score(title: b.name, query: query);
              return scoreB.compareTo(scoreA);
            });

            return MovieSection(
              title: _catalogDisplayName(catalog),
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: sortedMovies,
            );
          } catch (_) {
            return null;
          }
        }());
      }
    }

    final results = await Future.wait(futures);
    final validSections = results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();

    // Sort sections by the relevance score of their top match
    validSections.sort((a, b) {
      final topScoreA = a.movies.isNotEmpty ? RelevanceScorer.score(title: a.movies.first.name, query: query) : 0.0;
      final topScoreB = b.movies.isNotEmpty ? RelevanceScorer.score(title: b.movies.first.name, query: query) : 0.0;
      return topScoreB.compareTo(topScoreA);
    });

    return validSections;
  }

  /// Fetch catalogs filtered by a specific genre across all active addons.
  Future<List<MovieSection>> fetchByGenre(String genre) async {
    final active = activeCatalogAddons;
    final futures = <Future<MovieSection?>>[];

    for (final addon in active) {
      // Find catalogs that explicitly support filtering by genre via their 'extra' properties.
      final genreCatalogs = addon.manifest.catalogs.where((c) {
        final supportsGenre = c.genres.isNotEmpty;
        final isCinemetaTop = addon.manifest.id == 'com.linvo.cinemeta' && c.id == 'top';
        return supportsGenre || isCinemetaTop;
      }).toList();

      for (final catalog in genreCatalogs) {
        futures.add(() async {
          try {
            final movies = await MetadataService.fetchCatalog(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
              genre: genre,
            );

            if (movies.isEmpty) return null;

            return MovieSection(
              title: '${_catalogDisplayName(catalog)} - $genre',
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: movies,
            );
          } catch (_) {
            return null;
          }
        }());
      }
    }

    final results = await Future.wait(futures);
    return results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();
  }

  /// Generate a human-readable name for a catalog.
  String _catalogDisplayName(AddonCatalog catalog) {
    if (catalog.name != null && catalog.name!.isNotEmpty) {
      return catalog.name!;
    }

    final typeLabel = catalog.type == 'series'
        ? 'Series'
        : (catalog.type == 'anime'
            ? 'Anime'
            : (catalog.type == 'movie' ? 'Movies' : catalog.type));

    switch (catalog.id) {
      case 'top':
        return 'Popular $typeLabel';
      case 'year':
        return 'New $typeLabel';
      case 'imdbRating':
        return 'Top Rated $typeLabel';
      default:
        final id = catalog.id;
        final capitalized =
            id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';
        return '$capitalized $typeLabel';
    }
  }
}
