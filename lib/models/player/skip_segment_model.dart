import 'package:flutter/material.dart';

/// Represents a media skip segment (intro, recap, credits, preview).
class MediaSkipSegment {
  final String type; // 'intro' | 'recap' | 'credits' | 'preview'
  final int? startMs;
  final int? endMs;

  const MediaSkipSegment({
    required this.type,
    this.startMs,
    this.endMs,
  });

  /// The start duration of this segment (defaults to 0 if null).
  Duration get start => Duration(milliseconds: startMs ?? 0);

  /// The end duration of this segment (null represents end of media).
  Duration? get end => endMs != null ? Duration(milliseconds: endMs!) : null;

  /// Unique key to identify this segment for dismissal/deduplication.
  String get uniqueKey => '${type}_${startMs ?? 0}_${endMs ?? -1}';

  /// Human-friendly display label.
  String get label {
    switch (type.toLowerCase()) {
      case 'intro':
        return 'Skip Intro';
      case 'recap':
        return 'Skip Recap';
      case 'credits':
        return 'Skip Credits';
      case 'preview':
        return 'Skip Preview';
      default:
        return 'Skip ${type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : "Segment"}';
    }
  }

  /// Action icon representing the skip type.
  IconData get icon {
    switch (type.toLowerCase()) {
      case 'credits':
        return Icons.skip_next_rounded;
      case 'intro':
      case 'recap':
      case 'preview':
      default:
        return Icons.fast_forward_rounded;
    }
  }

  /// Checks if a playback position falls inside this segment.
  bool contains(Duration position, [Duration? totalDuration]) {
    final posMs = position.inMilliseconds;
    final sMs = startMs ?? 0;
    final effectiveEndMs = endMs ?? totalDuration?.inMilliseconds ?? (sMs + 600000);

    return posMs >= sMs && posMs < effectiveEndMs;
  }

  factory MediaSkipSegment.fromJson(String type, Map<String, dynamic> json) {
    int? sMs;
    int? eMs;

    if (json['start_ms'] != null) {
      sMs = (json['start_ms'] as num).toInt();
    } else if (json['start_sec'] != null) {
      sMs = ((json['start_sec'] as num) * 1000).toInt();
    }

    if (json['end_ms'] != null) {
      eMs = (json['end_ms'] as num).toInt();
    } else if (json['end_sec'] != null) {
      eMs = ((json['end_sec'] as num) * 1000).toInt();
    }

    return MediaSkipSegment(
      type: type,
      startMs: sMs,
      endMs: eMs,
    );
  }
}

/// Container for all skip segments retrieved from IntroDB.
class MediaSkipData {
  final int? tmdbId;
  final String? type;
  final int? season;
  final int? episode;
  final List<MediaSkipSegment> segments;

  const MediaSkipData({
    this.tmdbId,
    this.type,
    this.season,
    this.episode,
    this.segments = const [],
  });

  factory MediaSkipData.fromJson(Map<String, dynamic> json) {
    final list = <MediaSkipSegment>[];

    void parseSegmentArray(String typeKey) {
      final raw = json[typeKey];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            list.add(MediaSkipSegment.fromJson(typeKey, item));
          } else if (item is Map) {
            list.add(MediaSkipSegment.fromJson(typeKey, Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    parseSegmentArray('intro');
    parseSegmentArray('recap');
    parseSegmentArray('credits');
    parseSegmentArray('preview');

    // Sort segments chronologically
    list.sort((a, b) => (a.startMs ?? 0).compareTo(b.startMs ?? 0));

    return MediaSkipData(
      tmdbId: (json['tmdb_id'] as num?)?.toInt(),
      type: json['type']?.toString(),
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      segments: list,
    );
  }
}
