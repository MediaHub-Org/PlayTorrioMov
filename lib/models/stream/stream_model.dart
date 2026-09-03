/// Models for Stremio stream sources.

class StreamSource {
  final String? name;
  final String? title;
  final String? url;
  final String? externalUrl;
  final String? description;
  final String? infoHash;
  final int? fileIdx;
  final String addonName;
  final Map<String, dynamic>? behaviorHints;
  final List<String>? sources;
  final Map<String, String>? headers;

  StreamSource({
    this.name,
    this.title,
    this.url,
    this.externalUrl,
    this.description,
    this.infoHash,
    this.fileIdx,
    required this.addonName,
    this.behaviorHints,
    this.sources,
    this.headers,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json, String addonName) {
    Map<String, dynamic>? hints;
    if (json['behaviorHints'] is Map) {
      hints = Map<String, dynamic>.from(json['behaviorHints']);
    }

    List<String>? srcList;
    if (json['sources'] is List) {
      srcList = (json['sources'] as List).map((e) => e.toString()).toList();
    }

    int? fIdx;
    if (json['fileIdx'] is int) {
      fIdx = json['fileIdx'];
    } else if (json['fileIdx'] != null) {
      fIdx = int.tryParse(json['fileIdx'].toString());
    }

    Map<String, String>? headersMap;
    if (json['headers'] is Map) {
      headersMap = (json['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (hints != null) {
      if (hints['proxyHeaders'] is Map && (hints['proxyHeaders'] as Map)['request'] is Map) {
        headersMap = ((hints['proxyHeaders'] as Map)['request'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      } else if (hints['requestHeaders'] is Map) {
        headersMap = (hints['requestHeaders'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }

    return StreamSource(
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString(),
      externalUrl: json['externalUrl']?.toString(),
      infoHash: json['infoHash']?.toString(),
      fileIdx: fIdx,
      addonName: addonName,
      behaviorHints: hints,
      sources: srcList,
      headers: headersMap,
    );
  }

  static final RegExp _fileSizeRegex = RegExp(
    r'(\d+(?:[\.,]\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)|(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\s*(\d+(?:[\.,]\d+)?)',
    caseSensitive: false,
  );

  static final List<RegExp> _seederPatterns = [
    RegExp(r'[👤👥🌱⚡]\s*(\d+)', caseSensitive: false),
    RegExp(r'(?:seeds?|seeders?|peers?|s)\s*[:=]\s*(\d+)', caseSensitive: false),
    RegExp(r'(\d+)\s*(?:seeds?|seeders?)', caseSensitive: false),
    RegExp(r'\[\s*(\d+)\s*(?:s|seeds?)', caseSensitive: false),
    RegExp(r'/\s*(\d+)\s*peers?', caseSensitive: false),
    RegExp(r'(\d+)\s*/\s*\d+\s*(?:peers?|seeds?)?', caseSensitive: false),
  ];

  String? _cachedQuality;
  bool _qualityComputed = false;
  /// Extract resolution badge from title/name text.
  String? get quality {
    if (_qualityComputed) return _cachedQuality;
    _qualityComputed = true;
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    if (text.contains('2160') || text.contains('4k') || text.contains('uhd')) return _cachedQuality = '4K';
    if (text.contains('1080')) return _cachedQuality = '1080p';
    if (text.contains('720')) return _cachedQuality = '720p';
    if (text.contains('480')) return _cachedQuality = '480p';
    return _cachedQuality = null;
  }

  bool? _cachedHDR;
  /// Extract HDR badge.
  bool get isHDR {
    if (_cachedHDR != null) return _cachedHDR!;
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    return _cachedHDR = (text.contains('hdr') ||
        text.contains('dolby vision') ||
        text.contains('dv'));
  }

  String? _cachedCodec;
  bool _codecComputed = false;
  /// Extract codec info.
  String? get codec {
    if (_codecComputed) return _cachedCodec;
    _codecComputed = true;
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    if (text.contains('hevc') || text.contains('x265') || text.contains('h.265') || text.contains('h265')) return _cachedCodec = 'HEVC';
    if (text.contains('x264') || text.contains('h.264') || text.contains('h264') || text.contains('avc')) return _cachedCodec = 'H.264';
    if (text.contains('av1')) return _cachedCodec = 'AV1';
    return _cachedCodec = null;
  }

  String? _cachedFileSize;
  bool _fileSizeComputed = false;
  /// Extract file size string if mentioned in title, name, or description.
  String? get fileSize {
    if (_fileSizeComputed) return _cachedFileSize;
    _fileSizeComputed = true;
    final text = '${title ?? ''} ${name ?? ''} ${description ?? ''}';
    final match = _fileSizeRegex.firstMatch(text);
    if (match != null) {
      final numStr = match.group(1) ?? match.group(4);
      final unit = (match.group(2) ?? match.group(3))?.toUpperCase();
      if (numStr != null && unit != null) {
        return _cachedFileSize = '$numStr $unit';
      }
    }
    return _cachedFileSize = null;
  }

  double? _cachedSizeBytes;
  bool _sizeBytesComputed = false;
  /// Extracted size in bytes for filtering and sorting.
  double? get sizeBytes {
    if (_sizeBytesComputed) return _cachedSizeBytes;
    _sizeBytesComputed = true;
    final text = '${title ?? ''} ${name ?? ''} ${description ?? ''}';
    final match = _fileSizeRegex.firstMatch(text);
    if (match != null) {
      final numStr = match.group(1) ?? match.group(4);
      final unit = (match.group(2) ?? match.group(3))?.toUpperCase();
      if (numStr != null && unit != null) {
        final val = double.tryParse(numStr.replaceAll(',', '.'));
        if (val != null) {
          if (unit.startsWith('T')) return _cachedSizeBytes = val * 1024 * 1024 * 1024 * 1024;
          if (unit.startsWith('G')) return _cachedSizeBytes = val * 1024 * 1024 * 1024;
          if (unit.startsWith('M')) return _cachedSizeBytes = val * 1024 * 1024;
          if (unit.startsWith('K')) return _cachedSizeBytes = val * 1024;
        }
      }
    }
    return _cachedSizeBytes = null;
  }

  int? _cachedSeeders;
  bool _seedersComputed = false;
  /// Extracted seeders count from title, name, or description.
  int? get seeders {
    if (_seedersComputed) return _cachedSeeders;
    _seedersComputed = true;
    final text = '${title ?? ''} ${name ?? ''} ${description ?? ''}';
    for (final pattern in _seederPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '');
        if (val != null) return _cachedSeeders = val;
      }
    }
    return _cachedSeeders = null;
  }

  int? _cachedQualityRank;
  /// Numeric quality rank for sorting (higher is better).
  int get qualityRank {
    if (_cachedQualityRank != null) return _cachedQualityRank!;
    switch (quality) {
      case '4K': return _cachedQualityRank = 4;
      case '1080p': return _cachedQualityRank = 3;
      case '720p': return _cachedQualityRank = 2;
      case '480p': return _cachedQualityRank = 1;
      default: return _cachedQualityRank = 0;
    }
  }

  /// Human-readable display title.
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (name != null && name!.isNotEmpty) return name!;
    return 'Unknown source';
  }

  /// Whether this source is a magnet link or torrent stream.
  bool get isMagnet =>
      (infoHash != null && infoHash!.isNotEmpty) ||
      (url != null && url!.startsWith('magnet:'));

  /// Formatted magnet link with tracker and display name parameters if available.
  String? get magnetUrl {
    if (url != null && url!.startsWith('magnet:')) {
      return url;
    }
    if (infoHash != null && infoHash!.isNotEmpty) {
      var magnet = 'magnet:?xt=urn:btih:$infoHash';
      if (title != null && title!.isNotEmpty) {
        magnet += '&dn=${Uri.encodeComponent(title!)}';
      } else if (name != null && name!.isNotEmpty) {
        magnet += '&dn=${Uri.encodeComponent(name!)}';
      }
      if (sources != null) {
        for (final src in sources!) {
          if (src.startsWith('tracker:')) {
            final trackerUrl = src.replaceFirst('tracker:', '');
            magnet += '&tr=${Uri.encodeComponent(trackerUrl)}';
          }
        }
      }
      return magnet;
    }
    return null;
  }
}
