/// Models for Stremio addon manifest parsing and storage.

class AddonManifest {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? logo;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<AddonCatalog> catalogs;

  AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.logo,
    required this.resources,
    required this.types,
    required this.idPrefixes,
    required this.catalogs,
  });

  bool get supportsMeta => resources.contains('meta');
  bool get supportsCatalog => resources.contains('catalog');
  bool get supportsStream => resources.contains('stream');
  bool get supportsSubtitles => resources.contains('subtitles');

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Addon',
      version: json['version']?.toString() ?? '0.0.0',
      description: json['description']?.toString(),
      logo: json['logo']?.toString(),
      resources: _parseResourceList(json['resources']),
      types: _parseStringList(json['types']),
      idPrefixes: _parseStringList(json['idPrefixes']),
      catalogs: (json['catalogs'] as List<dynamic>?)
              ?.map((e) => AddonCatalog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
        'resources': resources,
        'types': types,
        'idPrefixes': idPrefixes,
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
      };
}

class AddonCatalog {
  final String type;
  final String id;
  final String? name;
  final List<String> genres;
  final bool supportsSearch;
  final bool supportsSkip;

  AddonCatalog({
    required this.type,
    required this.id,
    this.name,
    required this.genres,
    required this.supportsSearch,
    required this.supportsSkip,
  });

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    final extras = <Map<String, dynamic>>[];

    // Parse both 'extra' and 'extraSupported' arrays
    for (final key in ['extra', 'extraSupported']) {
      if (json[key] is List) {
        for (final e in json[key] as List) {
          if (e is Map<String, dynamic>) {
            extras.add(e);
          } else if (e is String) {
            extras.add({'name': e});
          }
        }
      }
    }

    List<String> genres = [];
    bool supportsSearch = json['supportsSearch'] as bool? ?? false;
    bool supportsSkip = json['supportsSkip'] as bool? ?? false;

    for (final extra in extras) {
      final name = extra['name']?.toString();
      if (name == 'genre') {
        genres = _parseStringList(extra['options']);
      } else if (name == 'search') {
        supportsSearch = true;
      } else if (name == 'skip') {
        supportsSkip = true;
      }
    }

    // Legacy 'genres' field fallback
    if (genres.isEmpty && json['genres'] is List) {
      genres = _parseStringList(json['genres']);
    }

    return AddonCatalog(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      genres: genres,
      supportsSearch: supportsSearch,
      supportsSkip: supportsSkip,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (name != null) 'name': name,
        'genres': genres,
        'supportsSearch': supportsSearch,
        'supportsSkip': supportsSkip,
      };
}

/// An addon that has been installed by the user.
class InstalledAddon {
  final String baseUrl;
  final AddonManifest manifest;
  bool enabled;
  bool enableCatalogs;
  bool enableSearch;
  bool enableSubtitles;
  bool enableStreams;

  InstalledAddon({
    required this.baseUrl,
    required this.manifest,
    this.enabled = true,
    this.enableCatalogs = true,
    this.enableSearch = true,
    this.enableSubtitles = true,
    this.enableStreams = true,
  });

  bool get isCatalogsActive =>
      enabled && enableCatalogs && (manifest.supportsCatalog || manifest.catalogs.isNotEmpty);

  bool get isSearchActive =>
      enabled && enableSearch && (manifest.catalogs.any((c) => c.supportsSearch) || manifest.supportsCatalog);

  bool get isSubtitlesActive =>
      enabled && enableSubtitles && manifest.supportsSubtitles;

  bool get isStreamsActive =>
      enabled && enableStreams && manifest.supportsStream;

  factory InstalledAddon.fromJson(Map<String, dynamic> json) {
    return InstalledAddon(
      baseUrl: json['baseUrl']?.toString() ?? '',
      manifest:
          AddonManifest.fromJson(json['manifest'] as Map<String, dynamic>),
      enabled: json['enabled'] as bool? ?? true,
      enableCatalogs: json['enableCatalogs'] as bool? ?? true,
      enableSearch: json['enableSearch'] as bool? ?? true,
      enableSubtitles: json['enableSubtitles'] as bool? ?? true,
      enableStreams: json['enableStreams'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'manifest': manifest.toJson(),
        'enabled': enabled,
        'enableCatalogs': enableCatalogs,
        'enableSearch': enableSearch,
        'enableSubtitles': enableSubtitles,
        'enableStreams': enableStreams,
      };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return [];
}

/// Parses the Stremio manifest `resources` field which can be either:
/// - A list of strings: `["catalog", "meta", "stream"]`
/// - A list of objects: `[{"name": "stream", "types": [...], "idPrefixes": [...]}]`
/// - A mix of both
/// Also recovers from previously stored broken toString dumps.
List<String> _parseResourceList(dynamic value) {
  if (value is! List) return [];
  
  return value.map<String>((e) {
    if (e is String) {
      // Check if this is a clean resource name
      if (!e.contains('{') && !e.contains(':')) return e;
      // Try to recover from broken toString dump like "{name: stream, types: [...]}"
      final match = RegExp(r'name:\s*(\w+)').firstMatch(e);
      if (match != null) return match.group(1)!;
      return '';
    }
    if (e is Map<String, dynamic>) return e['name']?.toString() ?? '';
    if (e is Map) return e['name']?.toString() ?? '';
    return e.toString();
  }).where((s) => s.isNotEmpty).toList();
}
