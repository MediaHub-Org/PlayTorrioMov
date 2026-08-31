class DebridMediaMatcher {
  static const _videoExts = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.ts',
    '.m4v',
    '.flv',
    '.wmv',
    '.iso',
  };

  static const _audioExts = {
    '.mp3',
    '.m4b',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.opus',
    '.wav',
    '.wma',
  };

  /// Intelligently picks a matching media file (video or audio) from a torrent file list.
  static T? pickMediaFile<T>(
    List<T> files, {
    int? fileIndex,
    String? filename,
    int? season,
    int? episode,
    required String Function(T) name,
    required int Function(T) size,
  }) {
    if (files.isEmpty) return null;

    // 1. If explicit fileIndex is provided and within range, verify it
    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      return files[fileIndex];
    }

    // 2. Filter out non-media files (samples, .nfo, .txt, .exe, .jpg, .sub, etc.)
    final mediaFiles = files.where((f) {
      final n = name(f).toLowerCase();
      final isMedia = _videoExts.any((ext) => n.endsWith(ext)) ||
          _audioExts.any((ext) => n.endsWith(ext));
      final isSample = n.contains('sample') || n.contains('trailer');
      return isMedia && !isSample;
    }).toList();

    final candidates = mediaFiles.isNotEmpty ? mediaFiles : files;

    // 3. Match by Season & Episode if provided (e.g. S01E02 or 1x02)
    if (season != null && episode != null) {
      final sStr = season.toString().padLeft(2, '0');
      final eStr = episode.toString().padLeft(2, '0');
      final epRegex = RegExp(
        '(?:s0*$season[ ._x-]*e0*$episode|${season}x0*$episode|ep(?:isode)?[ ._x-]*0*$episode)',
        caseSensitive: false,
      );

      final epMatches = candidates.where((f) {
        final fName = name(f).toLowerCase();
        return epRegex.hasMatch(fName) ||
            fName.contains('s$sStr' 'e$eStr') ||
            fName.contains('${season}x$eStr');
      }).toList();

      if (epMatches.isNotEmpty) {
        epMatches.sort((a, b) => size(b).compareTo(size(a)));
        return epMatches.first;
      }
    }

    // 4. Match by exact or substring filename/title
    if (filename != null && filename.isNotEmpty) {
      final cleanName = filename.toLowerCase().trim();
      final nameMatches = candidates.where((f) {
        final fName = name(f).toLowerCase();
        final baseName = fName.split('/').last.split('\\').last;
        return fName.contains(cleanName) ||
            cleanName.contains(baseName) ||
            baseName.contains(cleanName);
      }).toList();

      if (nameMatches.isNotEmpty) {
        nameMatches.sort((a, b) => size(b).compareTo(size(a)));
        return nameMatches.first;
      }
    }

    // 5. Fallback: select largest media candidate
    final sorted = List<T>.from(candidates)
      ..sort((a, b) => size(b).compareTo(size(a)));
    return sorted.first;
  }
}
