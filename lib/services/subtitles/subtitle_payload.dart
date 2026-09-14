// What a downloaded subtitle body actually is, decided without touching the
// network or the disk.
//
// This used to live inside `SubtitleExtractor.downloadAndExtract`, between an
// HTTP GET and a `File.writeAsBytes`, which meant the only way to exercise it
// was to download a real subtitle from a real provider. Those tests are tagged
// `network` and excluded from CI, so the archive handling below -- the part
// most likely to meet a shape nobody anticipated -- was never checked by a
// run that gates a merge.
//
// Splitting it out costs one indirection and buys a test that runs in
// milliseconds against a zip built in memory.

import 'package:archive/archive.dart';

import 'subtitle_parser.dart';

/// A subtitle body, unwrapped from whatever container it arrived in and
/// decoded to text.
class SubtitlePayload {
  const SubtitlePayload({required this.extension, required this.text});

  /// `srt`, `vtt` or `ass` -- no leading dot.
  final String extension;

  /// The subtitle itself, decoded from whatever legacy encoding it used.
  final String text;

  /// Subtitle extensions worth pulling out of an archive, and the extension
  /// each one implies. `.sub` is recognised as a subtitle but saved as `srt`:
  /// it is a container name, not a format, and the player reads the content.
  static const _subtitleExtensions = {
    '.srt': 'srt',
    '.vtt': 'vtt',
    '.ass': 'ass',
    '.sub': 'srt',
  };

  /// Unwrap [bytes] and decode them.
  ///
  /// [url] is read only for its extension, as a hint when the bytes
  /// themselves do not say what they are -- a gzipped `.vtt`, say, or a bare
  /// body with no container at all. A `.vtt` or `.ass` in the URL wins over
  /// the archive's own guess, because the provider named the format it is
  /// serving and the file inside a zip is often just `subtitle.srt`.
  ///
  /// Never throws: a corrupt archive falls back to treating the bytes as the
  /// subtitle itself, which is what a truncated download usually is.
  static SubtitlePayload decode(List<int> bytes, {required String url}) {
    final lowerUrl = url.toLowerCase();

    List<int>? unwrapped;
    String extension = 'srt';

    if (_isZip(bytes)) {
      final picked = _pickFromZip(bytes);
      if (picked != null) {
        unwrapped = picked.content;
        extension = picked.extension;
      }
    } else if (_isGzip(bytes)) {
      try {
        unwrapped = const GZipDecoder().decodeBytes(bytes);
        extension = lowerUrl.contains('.vtt') ? 'vtt' : 'srt';
      } catch (_) {
        // Fall through to the raw bytes below.
      }
    }

    // Not an archive, or an archive we could not read: the body is the
    // subtitle.
    unwrapped ??= bytes;

    // The URL's own extension is the last word, for the reason in the doc
    // comment above.
    if (lowerUrl.endsWith('.vtt')) {
      extension = 'vtt';
    } else if (lowerUrl.endsWith('.ass')) {
      extension = 'ass';
    }

    return SubtitlePayload(
      extension: extension,
      text: SubtitleParser.decodeBytesWithFallback(unwrapped),
    );
  }

  /// PK\x03\x04, and the empty- and spanned-archive variants.
  static bool _isZip(List<int> b) =>
      b.length > 4 && b[0] == 0x50 && b[1] == 0x4B;

  static bool _isGzip(List<int> b) =>
      b.length > 2 && b[0] == 0x1F && b[1] == 0x8B;

  /// The largest subtitle in the archive.
  ///
  /// Largest, not first: a release zip often carries a short "forced" track
  /// for signs alongside the full dialogue, and the full one is what someone
  /// turning subtitles on is asking for.
  static _ZipPick? _pickFromZip(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? best;
      String bestExtension = 'srt';
      var bestSize = -1;

      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();
        if (_isArchiveJunk(name)) continue;

        String? extension;
        for (final entry in _subtitleExtensions.entries) {
          if (name.endsWith(entry.key)) {
            extension = entry.value;
            break;
          }
        }
        if (extension == null) continue;

        if (file.size > bestSize) {
          bestSize = file.size;
          best = file;
          bestExtension = extension;
        }
      }

      if (best == null) return null;
      return _ZipPick(
        content: best.content as List<int>,
        extension: bestExtension,
      );
    } catch (_) {
      return null;
    }
  }

  /// macOS packs its own metadata into zips it creates. These entries are
  /// named after the real file, so `__MACOSX/._movie.srt` matches every
  /// subtitle-extension check and is not a subtitle.
  static bool _isArchiveJunk(String lowerName) =>
      lowerName.contains('__macosx') ||
      lowerName.split('/').last.startsWith('._') ||
      lowerName.endsWith('.ds_store');
}

class _ZipPick {
  const _ZipPick({required this.content, required this.extension});
  final List<int> content;
  final String extension;
}
