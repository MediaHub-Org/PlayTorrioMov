import 'subtitle_model.dart';

/// What a subtitle row shows for a [SubtitleVariant], worked out from the
/// fields providers fill in unevenly.
///
/// A provider's `title` is whatever it had to hand: a release name from
/// Wyzie, the bare numeric file id from OpenSubtitles ("13628256"), a
/// leftover like "t 2026 1080p -" from SubtitleCat once the movie's own words
/// were stripped out. Shown raw, five rows read as five ids. This keeps what
/// tells subtitles apart (a release name, the video quality it was made for)
/// and drops what does not.
class SubtitleDisplay {
  /// The release name, or empty when the provider gave nothing worth reading
  /// -- the row then shows a localized "Standard".
  final String title;

  /// What the subtitle was timed against: `1080p`, `WEB-DL`, `x264`. Matching
  /// these to the video's own release is how a viewer avoids a subtitle that
  /// drifts.
  final List<String> tags;

  /// The provider's name as its owner spells it ("OpenSubtitles").
  final String provider;

  /// `SRT`, `VTT`, ...
  final String format;

  /// Machine-translated rather than made by a person.
  final bool isTranslated;

  /// How many times it was downloaded, when the provider says.
  final int? downloads;

  const SubtitleDisplay({
    required this.title,
    required this.tags,
    required this.provider,
    required this.format,
    required this.isTranslated,
    this.downloads,
  });
}

final RegExp _resolution = RegExp(r'\b(2160p|4k|uhd|1080p|720p|576p|480p)\b', caseSensitive: false);
final RegExp _source = RegExp(
  r'\b(web[\s-]?dl|webrip|blu[\s-]?ray|bdrip|brrip|hdrip|hdtv|dvdrip|remux|hmax|amzn|nf)\b',
  caseSensitive: false,
);
final RegExp _codec = RegExp(r'\b(x264|x265|h[\s.]?264|h[\s.]?265|hevc|av1|10bit)\b', caseSensitive: false);
final RegExp _year = RegExp(r'\b(19|20)\d{2}\b');
final RegExp _extension = RegExp(r'\.(srt|vtt|ass|ssa|sub|zip)$', caseSensitive: false);
/// The placeholders `SubtitleService._cleanVariant` and the providers fall
/// back to ("Standard", "CC - Forced", "Stremio Addon"). Each is a badge or
/// nothing at all, never a name.
final RegExp _placeholder = RegExp(
  r'\b(standard|translated|forced|cc|sdh|hearing impaired|subtitles?|stremio addon|wyzie)\b',
  caseSensitive: false,
);

/// Providers whose names are two words squashed together, or in another case.
const Map<String, String> _providerNames = {
  'opensubtitles': 'OpenSubtitles',
  'subtitlecat': 'SubtitleCat',
  'subdl': 'SubDL',
  'wyzie': 'Wyzie',
};

String _prettyProvider(String raw) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s._-]'), '');
  return _providerNames[key] ?? raw.trim();
}

/// Works out the row text for [variant].
SubtitleDisplay describeSubtitle(SubtitleVariant variant) {
  var text = variant.title.trim().replaceAll(_extension, '');
  text = text.replaceAll(RegExp(r'[._]+'), ' ');

  // Auto-translation is a fact about the subtitle, shown as a badge, so the
  // words come out of the title.
  final translatedInTitle = RegExp(r'\(?auto[\s-]?translated\)?', caseSensitive: false);
  final isTranslated =
      variant.extraData['isTranslate'] == true || translatedInTitle.hasMatch(text);
  text = text.replaceAll(translatedInTitle, ' ');

  // CC is the badge's job too: "[CC]" appended by a provider, or a bare " CC ".
  text = text.replaceAll(RegExp(r'[\[(]\s*(cc|sdh|hi)\s*[\])]', caseSensitive: false), ' ');

  // Pull the quality tags out, in the order resolution, source, codec.
  final tags = <String>[];
  for (final pattern in [_resolution, _source, _codec]) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    tags.add(_formatTag(match.group(0)!));
    text = text.replaceAll(pattern, ' ');
  }

  // A year says nothing about which release this is, and the movie's own
  // title has usually been stripped already, leaving it stranded.
  text = text.replaceAll(_year, ' ');

  // What stripping the movie's words leaves behind: single letters ("Don't"
  // became "t"), and hyphens or brackets with nothing on one side.
  text = text
      .replaceAll(_placeholder, ' ')
      .replaceAll(RegExp(r'\b[A-Za-z]\b'), ' ')
      .replaceAll(RegExp(r'[\[\]()]'), ' ')
      .replaceAll(RegExp(r'\s[-–—]+\s|^[-–—\s]+|[-–—\s]+$'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // The bare id OpenSubtitles sends, or a "#2" counter: nothing to read.
  final title = RegExp(r'^#?\d*$').hasMatch(text) ? '' : text;

  final downloads = variant.extraData['downloads'];
  return SubtitleDisplay(
    title: title,
    tags: tags,
    provider: _prettyProvider(variant.providerName),
    format: variant.format.toUpperCase(),
    isTranslated: isTranslated,
    downloads: downloads is num ? downloads.toInt() : int.tryParse('$downloads'),
  );
}

String _formatTag(String raw) {
  final t = raw.trim();
  final lower = t.toLowerCase();
  if (RegExp(r'^\d+p$').hasMatch(lower)) return lower;
  if (lower == '4k' || lower == 'uhd') return lower == '4k' ? '4K' : 'UHD';
  return switch (lower.replaceAll(RegExp(r'[\s-]'), '')) {
    'webdl' => 'WEB-DL',
    'webrip' => 'WEBRip',
    'bluray' => 'BluRay',
    'bdrip' => 'BDRip',
    'brrip' => 'BRRip',
    'hdrip' => 'HDRip',
    'hdtv' => 'HDTV',
    'dvdrip' => 'DVDRip',
    'remux' => 'REMUX',
    'hmax' => 'HMAX',
    'amzn' => 'AMZN',
    'nf' => 'NF',
    'x264' => 'x264',
    'x265' => 'x265',
    'h264' || 'h.264' => 'H.264',
    'h265' || 'h.265' => 'H.265',
    'hevc' => 'HEVC',
    'av1' => 'AV1',
    '10bit' => '10-bit',
    _ => t,
  };
}

/// "1.2k", "34", "2.5M": a download count short enough for a row.
String compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
  return '$n';
}
