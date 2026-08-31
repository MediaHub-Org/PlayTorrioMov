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

  /// Extract resolution badge from title/name text.
  String? get quality {
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    if (text.contains('2160') || text.contains('4k') || text.contains('uhd')) return '4K';
    if (text.contains('1080')) return '1080p';
    if (text.contains('720')) return '720p';
    if (text.contains('480')) return '480p';
    return null;
  }

  /// Extract HDR badge.
  bool get isHDR {
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    return text.contains('hdr') ||
        text.contains('dolby vision') ||
        text.contains('dv');
  }

  /// Extract codec info.
  String? get codec {
    final text = '${title ?? ''} ${name ?? ''}'.toLowerCase();
    if (text.contains('hevc') || text.contains('x265') || text.contains('h.265') || text.contains('h265')) return 'HEVC';
    if (text.contains('x264') || text.contains('h.264') || text.contains('h264') || text.contains('avc')) return 'H.264';
    if (text.contains('av1')) return 'AV1';
    return null;
  }

  /// Extract file size string if mentioned in title, name, or description.
  String? get fileSize {
    final text = '${title ?? ''} ${name ?? ''} ${description ?? ''}';
    final regex = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)|(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\s*(\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final numStr = match.group(1) ?? match.group(4);
      final unit = (match.group(2) ?? match.group(3))?.toUpperCase();
      if (numStr != null && unit != null) {
        return '$numStr $unit';
      }
    }
    return null;
  }

  /// Extracted size in bytes for filtering and sorting.
  double? get sizeBytes {
    final text = '${title ?? ''} ${name ?? ''} ${description ?? ''}';
    final regex = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)|(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\s*(\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      final numStr = match.group(1) ?? match.group(4);
      final unit = (match.group(2) ?? match.group(3))?.toUpperCase();
      if (numStr != null && unit != null) {
        final val = double.tryParse(numStr.replaceAll(',', '.'));
        if (val != null) {
          if (unit.startsWith('T')) return val * 1024 * 1024 * 1024 * 1024;
          if (unit.startsWith('G')) return val * 1024 * 1024 * 1024;
          if (unit.startsWith('M')) return val * 1024 * 1024;
          if (unit.startsWith('K')) return val * 1024;
        }
      }
    }
    return null;
  }

  /// Numeric quality rank for sorting (higher is better).
  int get qualityRank {
    switch (quality) {
      case '4K': return 4;
      case '1080p': return 3;
      case '720p': return 2;
      case '480p': return 1;
      default: return 0;
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
