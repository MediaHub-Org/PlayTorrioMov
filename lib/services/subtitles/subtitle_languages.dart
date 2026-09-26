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
    // Regional variants, which providers send as `en-US`, `es-419`, `pt-BR`
    // and so on. Without these the code fell through to the unknown branch
    // and rendered as "EN-US" -- and worse, Spanish (Spain) and Spanish
    // (Latin America) arrived as one indistinguishable "Spanish", which is
    // the pair a viewer is most likely to care about: the dubs are different
    // recordings, not different spellings.
    'en-us': 'English (US)',
    'en-gb': 'English (UK)',
    'en-au': 'English (AU)',
    'eng-us': 'English (US)',
    'eng-gb': 'English (UK)',
    'spa': 'Spanish',
    'es': 'Spanish',
    'es-es': 'Spanish (ES)',
    'es-spain': 'Spanish (ES)',
    'spa-es': 'Spanish (ES)',
    'es-419': 'Spanish (LATAM)',
    'es-la': 'Spanish (LATAM)',
    'es-mx': 'Spanish (LATAM)',
    'es-ar': 'Spanish (LATAM)',
    'es-co': 'Spanish (LATAM)',
    'es-cl': 'Spanish (LATAM)',
    'spa-419': 'Spanish (LATAM)',
    'fre': 'French',
    'fra': 'French',
    'fr': 'French',
    'fr-fr': 'French (FR)',
    'fr-ca': 'French (CA)',
    'ger': 'German',
    'deu': 'German',
    'de': 'German',
    'de-de': 'German (DE)',
    'de-at': 'German (AT)',
    'ita': 'Italian',
    'it': 'Italian',
    'it-it': 'Italian (IT)',
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
    'pt-br': 'Portuguese (BR)',
    'por-br': 'Portuguese (BR)',
    'pt-pt': 'Portuguese (PT)',
    'por-pt': 'Portuguese (PT)',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'zh': 'Chinese',
    'zh-cn': 'Chinese (Simplified)',
    'zh-hans': 'Chinese (Simplified)',
    'zh-sg': 'Chinese (Simplified)',
    'zh-tw': 'Chinese (Traditional)',
    'zh-hant': 'Chinese (Traditional)',
    'zh-hk': 'Chinese (Traditional)',
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
    'kur': 'Kurdish',
    'ckb': 'Kurdish',
    'ku': 'Kurdish',
    'mn': 'Mongolian',
    'pus': 'Pashto',
    'ps': 'Pashto',
    'sin': 'Sinhala',
    'si': 'Sinhala',
    'som': 'Somali',
    'so': 'Somali',
    'swa': 'Swahili',
    'swh': 'Swahili',
    'sw': 'Swahili',
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
      // Short codes throughout, so a language and its variants read as a
      // family: "Spanish (ES)" beside "Spanish (LATAM)", not "Spanish
      // (Spain)" beside "Spanish (Latin America)". The long spellings were
      // also inconsistent with the code path -- `es-419` and `spanish
      // (latam)` are the same variant and have to render the same way.
      'latam' || 'latin america' || 'latin american' || '419' || 'la' =>
        'LATAM',
      'br' || 'brazil' => 'BR',
      'pt' || 'portugal' => 'PT',
      'us' || 'usa' || 'united states' => 'US',
      'uk' || 'gb' || 'united kingdom' => 'UK',
      'au' || 'australia' => 'AU',
      'ca' || 'canada' => 'CA',
      'mx' || 'mexico' => 'MX',
      'ar' || 'argentina' => 'AR',
      'co' || 'colombia' => 'CO',
      'cl' || 'chile' => 'CL',
      'es' || 'spain' => 'ES',
      'cn' || 'china' => 'CN',
      'tw' || 'taiwan' => 'TW',
      'hk' || 'hong kong' => 'HK',
      'sg' || 'singapore' => 'SG',
      'fr' || 'france' => 'FR',
      'de' || 'germany' => 'DE',
      'at' || 'austria' => 'AT',
      'it' || 'italy' => 'IT',
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
///   language the dialogue is in. Not a language either, and a row reading
///   "Same as audio" told the viewer nothing the track's own title does not,
///   so it is dropped like `spl` rather than given a label.
/// - `zhc` / `zht` — Chinese simplified and traditional. Real languages in
///   effect, but codes mpv invents rather than ISO ones, so they rendered as
///   three-letter noise instead of joining the Chinese group.
const Map<String, String> _mpvTagToDisplayName = {
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
  if (const {'spl', 'mon'}.contains(raw.toLowerCase())) return '';
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
///
/// **Regional variants are deliberately kept apart.** Spanish (ES) and
/// Spanish (LATAM) are different recordings, not different spellings of one
/// label, and a viewer who wants one does not want the other -- so they are
/// two groups. The same goes for Portuguese (BR) and (PT), and for English
/// (US) and (UK). Only the *script* split is collapsed, because Simplified
/// and Traditional Chinese are the same audio with two writing systems, and
/// a viewer reading one can generally read the other.
String canonicalLanguageGroup(String? rawLanguage) {
  final name = subtitleTrackLanguageName(rawLanguage);
  if (name.isEmpty) return '';
  // Script variants collapse to one Chinese group; the row still says which
  // script it is.
  if (name.startsWith('Chinese')) return 'Chinese';
  return name;
}
