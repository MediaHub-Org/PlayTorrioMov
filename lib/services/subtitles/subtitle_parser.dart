import 'dart:convert';
import 'dart:math';

enum SubFormat { srt, vtt, ass }

class SubCue {
  final double start;
  final double end;
  final String text;

  const SubCue({
    required this.start,
    required this.end,
    required this.text,
  });

  SubCue copyWith({
    double? start,
    double? end,
    String? text,
  }) {
    return SubCue(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
    );
  }

  @override
  String toString() => 'SubCue(start: $start, end: $end, text: $text)';
}

class SubtitleParseResult {
  final List<SubCue> cues;
  final SubFormat format;

  const SubtitleParseResult({
    required this.cues,
    required this.format,
  });
}

class SubtitleParser {
  /// Decodes raw bytes to a String handling UTF-8, UTF-16, Windows-1256, and Latin-1.
  static String decodeBytesWithFallback(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // 1. Check for UTF-8 with BOM
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      try {
        return utf8.decode(bytes.sublist(3));
      } catch (_) {}
    }

    // 2. Try standard UTF-8
    try {
      return utf8.decode(bytes);
    } catch (_) {}

    // 3. Check for UTF-16 BOM
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        // UTF-16LE
        final codeUnits = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
        }
        return String.fromCharCodes(codeUnits);
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        // UTF-16BE
        final codeUnits = <int>[];
        for (int i = 2; i + 1 < bytes.length; i += 2) {
          codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return String.fromCharCodes(codeUnits);
      }
    }

    // 4. Fallback to Latin-1 / Windows-1252 / Windows-1256 lossless char mapping
    try {
      return latin1.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  static SubtitleParseResult parse(String raw, {SubFormat? format}) {
    final text = raw
        .replaceFirst(RegExp(r'^\uFEFF'), '') // Remove BOM
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final fmt = format ?? detectFormat(text);
    List<SubCue> cues;

    switch (fmt) {
      case SubFormat.vtt:
        cues = parseVtt(text);
        break;
      case SubFormat.ass:
        cues = parseAss(text);
        break;
      case SubFormat.srt:
        cues = parseSrt(text);
        break;
    }

    return SubtitleParseResult(cues: cues, format: fmt);
  }

  static SubFormat detectFormat(String text) {
    final head = text.substring(0, min(text.length, 300)).trim().toLowerCase();
    if (head.startsWith('webvtt')) return SubFormat.vtt;
    if (head.contains('[script info]') ||
        head.contains('[v4+ styles]') ||
        text.toLowerCase().contains('[events]')) {
      return SubFormat.ass;
    }
    return SubFormat.srt;
  }

  static List<SubCue> parseSrt(String text) {
    final List<SubCue> cues = [];
    final blocks = text.split(RegExp(r'\n{2,}'));

    final timingRegex = RegExp(
      r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
    );

    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) continue;

      int timingIdx = 0;
      if (RegExp(r'^\d+$').hasMatch(lines[0].trim())) {
        timingIdx = 1;
      }
      if (timingIdx >= lines.length) continue;

      final timing = lines[timingIdx];
      final m = timingRegex.firstMatch(timing);
      if (m == null) continue;

      final start = _toSec(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
      final end = _toSec(m.group(5)!, m.group(6)!, m.group(7)!, m.group(8)!);
      final body = lines.sublist(timingIdx + 1).join('\n');
      final cleanText = cleanInline(body);

      if (cleanText.isNotEmpty) {
        cues.add(SubCue(start: start, end: end, text: cleanText));
      }
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<SubCue> parseVtt(String text) {
    final List<SubCue> cues = [];
    final stripped = text.replaceFirst(RegExp(r'^WEBVTT[^\n]*\n+', caseSensitive: false), '');
    final blocks = stripped.split(RegExp(r'\n{2,}'));

    final timingRegex = RegExp(
      r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[,.](\d{1,3})\s*-->\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[,.](\d{1,3})',
    );

    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      int timingIdx = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timingIdx = i;
          break;
        }
      }
      if (timingIdx == -1) continue;

      final m = timingRegex.firstMatch(lines[timingIdx]);
      if (m == null) continue;

      final start = _toSec(
        m.group(1) ?? '0',
        m.group(2)!,
        m.group(3)!,
        m.group(4)!,
      );
      final end = _toSec(
        m.group(5) ?? '0',
        m.group(6)!,
        m.group(7)!,
        m.group(8)!,
      );
      final body = lines.sublist(timingIdx + 1).join('\n');
      final cleanText = cleanInline(body);

      if (cleanText.isNotEmpty) {
        cues.add(SubCue(start: start, end: end, text: cleanText));
      }
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<SubCue> parseAss(String text) {
    final List<SubCue> cues = [];
    final eventsIdx = text.toLowerCase().indexOf('[events]');
    if (eventsIdx == -1) return cues;

    final eventsBlock = text.substring(eventsIdx);
    final lines = eventsBlock.split('\n');
    List<String>? format;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Format:')) {
        format = trimmed
            .substring(7)
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .toList();
        continue;
      }
      if (!trimmed.startsWith('Dialogue:')) continue;
      if (format == null) continue;

      final startIdx = format.indexOf('start');
      final endIdx = format.indexOf('end');
      final textIdx = format.indexOf('text');
      if (startIdx == -1 || endIdx == -1 || textIdx == -1) continue;

      final parts = _splitAssDialogue(trimmed.substring(9), format.length);
      if (parts.length < format.length) continue;

      final start = _parseAssTime(parts[startIdx]);
      final end = _parseAssTime(parts[endIdx]);
      if (start.isNaN || end.isNaN) continue;

      final body = _stripAssTags(parts[textIdx]);
      if (body.isNotEmpty) {
        cues.add(SubCue(start: start, end: end, text: body));
      }
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<String> _splitAssDialogue(String line, int fields) {
    final List<String> out = [];
    int i = 0;
    String buf = '';
    int count = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == ',' && count < fields - 1) {
        out.add(buf.trim());
        buf = '';
        count++;
      } else {
        buf += c;
      }
      i++;
    }
    out.add(buf);
    return out;
  }

  static double _parseAssTime(String s) {
    final m = RegExp(r'(\d+):(\d{2}):(\d{2})\.(\d{1,3})').firstMatch(s.trim());
    if (m == null) return double.nan;
    return _toSec(m.group(1)!, m.group(2)!, m.group(3)!, '${m.group(4)!}00'.substring(0, 3));
  }

  static String _stripAssTags(String s) {
    return s
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\h', ' ')
        .trim();
  }

  static String cleanInline(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]+>'), '') // HTML tags like <i>, <b>, <font>
        .replaceAll(RegExp(r'\{[^}]*\}'), '') // ASS formatting
        .replaceAll(r'\N', '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  static double _toSec(String h, String m, String s, String ms) {
    final paddedMs = '${ms}000'.substring(0, 3);
    final hours = int.tryParse(h) ?? 0;
    final mins = int.tryParse(m) ?? 0;
    final secs = int.tryParse(s) ?? 0;
    final millis = int.tryParse(paddedMs) ?? 0;
    return (hours * 3600) + (mins * 60) + secs + (millis / 1000.0);
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  static String toSrt(List<SubCue> cues) {
    final sorted = List<SubCue>.from(cues)..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();

    for (int i = 0; i < sorted.length; i++) {
      final cue = sorted[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${formatSrtTime(cue.start)} --> ${formatSrtTime(cue.end)}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String toVtt(List<SubCue> cues) {
    final sorted = List<SubCue>.from(cues)..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer('WEBVTT\n\n');

    for (final cue in sorted) {
      buffer.writeln('${formatVttTime(cue.start)} --> ${formatVttTime(cue.end)}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String formatSrtTime(double sec) {
    final totalMs = (sec * 1000).round();
    final h = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  static String formatVttTime(double sec) {
    final totalMs = (sec * 1000).round();
    final h = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    if (totalMs >= 3600000) {
      return '$h:$m:$s.$ms';
    }
    return '$m:$s.$ms';
  }

  static String formatDisplayTime(double sec) {
    final totalSec = sec.floor();
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Binary Search Lookup
  // ---------------------------------------------------------------------------

  static int? findActiveCueIndex(List<SubCue> cues, double timeSec) {
    if (cues.isEmpty) return null;

    int lo = 0;
    int hi = cues.length - 1;

    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final c = cues[mid];
      if (timeSec < c.start) {
        hi = mid - 1;
      } else if (timeSec >= c.end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }

    return null;
  }

  /// Finds the active cue index, or if during silence/gap between cues, finds the closest cue.
  static int findClosestCueIndex(List<SubCue> cues, double timeSec) {
    if (cues.isEmpty) return 0;
    if (timeSec <= cues.first.start) return 0;
    if (timeSec >= cues.last.end) return cues.length - 1;

    int lo = 0;
    int hi = cues.length - 1;

    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final c = cues[mid];
      if (timeSec < c.start) {
        hi = mid - 1;
      } else if (timeSec >= c.end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }

    if (lo >= cues.length) return cues.length - 1;
    if (hi < 0) return 0;

    final diffPrev = (timeSec - cues[hi].end).abs();
    final diffNext = (cues[lo].start - timeSec).abs();

    return diffPrev <= diffNext ? hi : lo;
  }
}
