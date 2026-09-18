/// The one ISO-639 code -> display-name table the subtitle providers share.
///
/// It used to be a `_iso3ToLangName` constant copied into three providers.
/// Two of those copies (OpenSubtitles and Wyzie) were byte-identical to each
/// other and 51 entries shorter than the third, so a Croatian, Bulgarian,
/// Tamil or Bengali subtitle from either of them rendered as a raw `hrv` /
/// `bul` / `tam` code while the same language from Stremio rendered as a
/// name. That is the kind of drift three copies of a lookup table produce,
/// and it is why this is one table.
///
/// The surviving table is the superset: every key the short copies had is
/// present here with the same value, so nothing that worked before changes.
library;

const Map<String, String> _iso639ToDisplayName = {
    'ara': 'Arabic',
    'ar': 'Arabic',
    'eng': 'English',
    'en': 'English',
    'spa': 'Spanish',
    'es': 'Spanish',
    'fre': 'French',
    'fra': 'French',
    'fr': 'French',
    'ger': 'German',
    'deu': 'German',
    'de': 'German',
    'ita': 'Italian',
    'it': 'Italian',
    'jpn': 'Japanese',
    'ja': 'Japanese',
    'kor': 'Korean',
    'ko': 'Korean',
    'rus': 'Russian',
    'ru': 'Russian',
    'por': 'Portuguese',
    'pt': 'Portuguese',
    'pob': 'Portuguese (BR)',
    'pb': 'Portuguese (BR)',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'zh': 'Chinese',
    'hin': 'Hindi',
    'hi': 'Hindi',
    'tur': 'Turkish',
    'tr': 'Turkish',
    'ind': 'Indonesian',
    'id': 'Indonesian',
    'vie': 'Vietnamese',
    'vi': 'Vietnamese',
    'tha': 'Thai',
    'th': 'Thai',
    'pol': 'Polish',
    'pl': 'Polish',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'nl': 'Dutch',
    'swe': 'Swedish',
    'sv': 'Swedish',
    'nor': 'Norwegian',
    'no': 'Norwegian',
    'dan': 'Danish',
    'da': 'Danish',
    'fin': 'Finnish',
    'fi': 'Finnish',
    'heb': 'Hebrew',
    'he': 'Hebrew',
    'ces': 'Czech',
    'cze': 'Czech',
    'cs': 'Czech',
    'ell': 'Greek',
    'gre': 'Greek',
    'el': 'Greek',
    'hun': 'Hungarian',
    'hu': 'Hungarian',
    'ron': 'Romanian',
    'rum': 'Romanian',
    'ro': 'Romanian',
    'ukr': 'Ukrainian',
    'uk': 'Ukrainian',
    'per': 'Persian',
    'fas': 'Persian',
    'fa': 'Persian',
    'hrv': 'Croatian',
    'scr': 'Croatian',
    'hr': 'Croatian',
    'bul': 'Bulgarian',
    'bg': 'Bulgarian',
    'est': 'Estonian',
    'et': 'Estonian',
    'mac': 'Macedonian',
    'mkd': 'Macedonian',
    'mk': 'Macedonian',
    'slv': 'Slovenian',
    'sl': 'Slovenian',
    'srp': 'Serbian',
    'scc': 'Serbian',
    'sr': 'Serbian',
    'bos': 'Bosnian',
    'bs': 'Bosnian',
    'alb': 'Albanian',
    'sqi': 'Albanian',
    'sq': 'Albanian',
    'slk': 'Slovak',
    'slo': 'Slovak',
    'sk': 'Slovak',
    'lit': 'Lithuanian',
    'lt': 'Lithuanian',
    'lav': 'Latvian',
    'lv': 'Latvian',
    'ice': 'Icelandic',
    'isl': 'Icelandic',
    'is': 'Icelandic',
    'tam': 'Tamil',
    'ta': 'Tamil',
    'tel': 'Telugu',
    'te': 'Telugu',
    'mal': 'Malayalam',
    'ml': 'Malayalam',
    'ben': 'Bengali',
    'bn': 'Bengali',
    'fil': 'Tagalog',
    'tgl': 'Tagalog',
    'tl': 'Tagalog',
    'msa': 'Malay',
    'may': 'Malay',
    'ms': 'Malay',
    'cat': 'Catalan',
    'ca': 'Catalan',
};

/// The display name for a subtitle language code, or a sensible rendering of
/// the code itself when it is not one we know.
///
/// Short codes upper-case (`pt-br` stays as-is, `zzz` becomes `ZZZ`) because
/// a three-letter code reads as an abbreviation; anything longer is already
/// a word and is left alone.
String subtitleLanguageName(String rawCode) {
  final code = rawCode.trim().toLowerCase();
  final known = _iso639ToDisplayName[code];
  if (known != null) return known;
  final regional = RegExp(r'^(.+?)\s*\(([^)]+)\)$').firstMatch(code);
  if (regional != null) {
    final base = subtitleLanguageName(regional.group(1)!);
    final region = regional.group(2)!.trim();
    final regionName = switch (region) {
      'latam' || 'latin america' || 'latin american' => 'Latin America',
      'br' || 'brazil' => 'Brazil',
      'pt' || 'portugal' => 'Portugal',
      'us' || 'usa' => 'United States',
      _ => _capitalizeWords(region),
    };
    return '$base ($regionName)';
  }
  if (code.length <= 3) return code.toUpperCase();
  return _capitalizeWords(code);
}

String _capitalizeWords(String value) => value
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');

/// mpv's own track tags that are not languages at all, mapped to what they
/// mean. These arrive on *embedded* tracks -- the container's own metadata --
/// and were rendered raw before, so a file's subtitle list offered "SPL",
/// "MON", "ZHC" and "ZHT" as though they were languages, which nobody could
/// be expected to read:
///
/// - `spl` — "subtitle only": a track carrying titles-on-screen or signs,
///   with no spoken dialogue to translate. Not a language; a kind of track.
/// - `mon` — "monolingual": the subtitles match the audio, i.e. the same
///   language the dialogue is in.
/// - `zhc` / `zht` — Chinese simplified and traditional. Real languages in
///   effect, but codes mpv invents rather than ISO ones, so they rendered as
///   three-letter noise instead of joining the Chinese group.
const Map<String, String> _mpvTagToDisplayName = {
  'mon': 'Same as audio',
  'zhc': 'Chinese (Simplified)',
  'zht': 'Chinese (Traditional)',
};

/// The display name for a language that may be an ISO code, an mpv track
/// tag, or a name already.
///
/// The mpv tags are checked first: `zhc` would otherwise fall through to the
/// unknown-code branch and render as "ZHC", which is the noise this exists
/// to replace.
String subtitleTrackLanguageName(String? rawLanguage) {
  final raw = rawLanguage?.trim() ?? '';
  if (raw.isEmpty) return '';
  if (raw.toLowerCase() == 'spl') return '';
  final mpv = _mpvTagToDisplayName[raw.toLowerCase()];
  if (mpv != null) return mpv;
  return subtitleLanguageName(raw);
}

/// The canonical group a language belongs to, so the same language arriving
/// under different labels lands in one group rather than several.
///
/// The Chinese family is the case that made this worth writing: a single
/// file can carry `zh`, `chi`, `zho`, `zhc` and `zht` tracks, which the
/// picker showed as four separate languages. They are one language with two
/// scripts, and the group header says which.
String canonicalLanguageGroup(String? rawLanguage) {
  final name = subtitleTrackLanguageName(rawLanguage);
  if (name.isEmpty) return '';
  if (name.startsWith('Chinese')) return 'Chinese';
  final regional = RegExp(
    r'^(.+?)\s*\((?:Latin America|Brazil|Portugal|United States)\)$',
  ).firstMatch(name);
  return regional?.group(1) ?? name;
}
