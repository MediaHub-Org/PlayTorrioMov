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
    // `nb` is Bokmål, which is what a provider means by "Norwegian" -- it is
    // the written form the overwhelming majority of releases ship. It was
    // missing, so a Norwegian track rendered as the raw code "NB".
    'nb': 'Norwegian',
    'nob': 'Norwegian',
    'nno': 'Norwegian (Nynorsk)',
    'nn': 'Norwegian (Nynorsk)',
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
    // The rest of the codes a provider actually sends. Each of these was
    // rendering as a raw three-letter code -- "MAR", "YUE", "AFR" -- which
    // reads as noise rather than as a language.
    'mar': 'Marathi',
    'mr': 'Marathi',
    'guj': 'Gujarati',
    'gu': 'Gujarati',
    'kan': 'Kannada',
    'kn': 'Kannada',
    'pan': 'Punjabi',
    'pa': 'Punjabi',
    'urd': 'Urdu',
    'ur': 'Urdu',
    'nep': 'Nepali',
    'ne': 'Nepali',
    'mya': 'Burmese',
    'bur': 'Burmese',
    'my': 'Burmese',
    'khm': 'Khmer',
    'km': 'Khmer',
    'lao': 'Lao',
    'lo': 'Lao',
    'yue': 'Cantonese',
    'cmn': 'Mandarin',
    'afr': 'Afrikaans',
    'af': 'Afrikaans',
    'amh': 'Amharic',
    'am': 'Amharic',
    'yor': 'Yoruba',
    'yo': 'Yoruba',
    'hau': 'Hausa',
    'ha': 'Hausa',
    'zul': 'Zulu',
    'zu': 'Zulu',
    'aze': 'Azerbaijani',
    'az': 'Azerbaijani',
    'kaz': 'Kazakh',
    'kk': 'Kazakh',
    'uzb': 'Uzbek',
    'uz': 'Uzbek',
    'geo': 'Georgian',
    'kat': 'Georgian',
    'ka': 'Georgian',
    'arm': 'Armenian',
    'hye': 'Armenian',
    'hy': 'Armenian',
    'bel': 'Belarusian',
    'be': 'Belarusian',
    'gle': 'Irish',
    'ga': 'Irish',
    'cym': 'Welsh',
    'wel': 'Welsh',
    'cy': 'Welsh',
    'eus': 'Basque',
    'baq': 'Basque',
    'eu': 'Basque',
    'glg': 'Galician',
    'gl': 'Galician',
    'mlt': 'Maltese',
    'mt': 'Maltese',
    'asm': 'Assamese',
    'as': 'Assamese',
    'ori': 'Odia',
    'ory': 'Odia',
    'or': 'Odia',
    'snd': 'Sindhi',
    'sd': 'Sindhi',
    'tat': 'Tatar',
    'tt': 'Tatar',
    'tuk': 'Turkmen',
    'tk': 'Turkmen',
    'kir': 'Kyrgyz',
    'ky': 'Kyrgyz',
    'tgk': 'Tajik',
    'tg': 'Tajik',
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
  // Bare muxer spellings of the same two tags. Containers write "chs" and
  // "cht" where mpv reports "zhc" and "zht"; without these they rendered as
  // three-letter noise instead of joining the Chinese group.
  'chs': 'Chinese (Simplified)',
  'cht': 'Chinese (Traditional)',
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
  // `auto` is mpv's own pseudo-track, not a language. It reached the picker
  // as a row reading "Auto", which is not something anyone can choose
  // deliberately -- there is nothing to choose it by.
  if (const {'spl', 'mon', 'auto'}.contains(raw.toLowerCase())) return '';
  final mpv = _mpvTagToDisplayName[raw.toLowerCase()];
  if (mpv != null) return mpv;
  return subtitleLanguageName(raw);
}

/// Display names for a set of tracks that may share a language.
///
/// A file with two Spanish subtitle tracks -- one Castilian, one Latin
/// American -- rendered both as "Spanish", so the list showed the same word
/// twice and the choice between them was invisible. Every language follows
/// the same pattern: a canonical base (`Spanish (ES)`, `Chinese`) with the
/// title's region swapped in (`Spanish (LATAM)`, `Chinese (Traditional)`),
/// and -- unless [numberDuplicates] is off -- a number where rows would
/// otherwise collide, as `Spanish (ES) #1`. Numbering is the honest answer
/// there: the tracks really are indistinguishable from their metadata.
///
/// Embedded lists turn numbering off: a handful of tracks are told apart by
/// trial, and "Spanish #1" next to "Spanish (LATAM)" reads as two different
/// kinds of thing. The audio menu keeps it on, where identical rows would
/// otherwise collide with no recourse.
///
/// A track whose tag is empty but whose title is a bare code ("chi") is
/// named for the code -- see [_namedOrGuessed]. Tracks whose language is
/// unknown even then are left alone: numbering "Track 3" would invent a
/// language.
List<String> uniqueTrackLanguageNames(
  List<String?> rawLanguages,
  List<String?> titles, {
  bool numberDuplicates = true,
}) {
  // Canonical first, so every language groups like Spanish does: script
  // variants collapse to Chinese, untagged Spanish joins Spanish (ES).
  // Without this each spelling was its own row -- "Chinese" beside
  // "Chinese (Traditional)".
  final names = <String>[
    for (var i = 0; i < rawLanguages.length; i++)
      canonicalLanguageGroup(
        _namedOrGuessed(rawLanguages[i], i < titles.length ? titles[i] : null),
      ),
  ];

  // The title's region swapped in, replacing any the base carries: a track
  // tagged generic but titled for Mexico reads "Spanish (MX)", not
  // "Spanish (ES) (MX)". A bare code never gains a region it did not state.
  final labeled = <String>[
    for (var i = 0; i < names.length; i++)
      () {
        final name = names[i];
        if (name.isEmpty) return '';
        final region =
            _regionFromTitle(i < titles.length ? titles[i] : null);
        if (region == null) return name;
        final base = name.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '');
        return '$base ($region)';
      }(),
  ];

  final totals = <String, int>{};
  for (final label in labeled) {
    if (label.isEmpty) continue;
    totals[label] = (totals[label] ?? 0) + 1;
  }

  final seen = <String, int>{};
  return [
    for (var i = 0; i < labeled.length; i++)
      () {
        final label = labeled[i];
        if (label.isEmpty || totals[label]! < 2 || !numberDuplicates) {
          return label;
        }
        final n = seen[label] = (seen[label] ?? 0) + 1;
        return '$label #$n';
      }(),
  ];
}

/// The language when the tag is empty but the title is explicit.
///
/// Muxers leave the language field blank and write "chi" or "eng" as the
/// title; without this those tracks fell back to "Track N". Only something
/// unambiguous counts: a known code, an mpv tag, or a bare display name
/// straight from the table. Free text is never guessed from -- "Full" is
/// not a language, and a wrong guess here mislabels the track.
String _namedOrGuessed(String? raw, String? title) {
  final named = subtitleTrackLanguageName(raw);
  if (named.isNotEmpty) return named;
  final text = title?.trim().toLowerCase() ?? '';
  if (text.isEmpty) return '';
  if (_isKnownCode(text)) return subtitleTrackLanguageName(text);
  for (final entry in _iso639ToDisplayName.entries) {
    if (entry.value.toLowerCase() == text) return entry.value;
  }
  for (final token in text.split(RegExp(r'[^a-z]+'))) {
    if (token.isEmpty) continue;
    if (_isKnownCode(token)) return subtitleTrackLanguageName(token);
    for (final entry in _iso639ToDisplayName.entries) {
      if (entry.value.toLowerCase() == token) return entry.value;
    }
  }
  return '';
}

/// A token the table actually knows: an ISO code or an mpv tag. Anything
/// else falls through to the plain-text rendering, which is noise rather
/// than a language.
bool _isKnownCode(String token) =>
    _iso639ToDisplayName.containsKey(token) ||
    _mpvTagToDisplayName.containsKey(token);

/// What an embedded track with no language is called.
///
/// The container title first -- muxers write usable names there -- then the
/// codec as a short label, then a bare number. A track with neither a tag
/// nor a title cannot be named "Language (Region)", but "Track 17 · SRT"
/// still tells a viewer picking by trial which row they tried, where three
/// rows reading "SRT" would not.
String embeddedFallbackTitle({
  String? containerTitle,
  String? codec,
  required int index,
}) {
  final title = containerTitle?.trim() ?? '';
  if (title.isNotEmpty) return title;
  final label = _codecShortLabel(codec);
  if (label != null) return 'Track $index · $label';
  return 'Track $index';
}

/// A codec mpv reports, shortened for a row title. Unknown codecs yield
/// nothing rather than a shouty technical string.
String? _codecShortLabel(String? codec) {
  switch (codec?.trim().toLowerCase()) {
    case 'subrip':
    case 'srt':
      return 'SRT';
    case 'ass':
    case 'ssa':
      return 'ASS';
    case 'mov_text':
      return 'MOV Text';
    case 'webvtt':
    case 'vtt':
      return 'VTT';
    case 'microdvd':
      return 'MicroDVD';
    case 'mpl2':
      return 'MPL2';
    case 'realtext':
      return 'RealText';
    case 'sami':
      return 'SAMI';
    case 'hdmv_pgs_subtitle':
    case 'pgssub':
      return 'PGS';
    case 'dvd_subtitle':
    case 'vobsub':
      return 'VobSub';
    case 'dvb_subtitle':
    case 'dvb_sub':
      return 'DVB';
    case 'eia_608':
    case 'cc_dec':
      return 'CC';
    case 'xsub':
      return 'XSUB';
    default:
      return null;
  }
}
///
/// Deliberately narrow: it looks for the region words and codes that appear
/// in real track titles, and returns nothing rather than guessing. A wrong
/// region here would label a track as a variant it is not, which is worse
/// than the number it falls back to.
String? _regionFromTitle(String? title) {
  if (title == null || title.trim().isEmpty) return null;
  final text = title.toLowerCase();
  const regions = <String, String>{
    'latin america': 'LATAM',
    'latino': 'LATAM',
    'latam': 'LATAM',
    'castilian': 'ES',
    'castellano': 'ES',
    'spain': 'ES',
    'españa': 'ES',
    'brazil': 'BR',
    'brasil': 'BR',
    'portugal': 'PT',
    'united states': 'US',
    'united kingdom': 'UK',
    'australia': 'AU',
    'canada': 'CA',
    'mexico': 'MX',
    'argentina': 'AR',
    'taiwan': 'TW',
    'hong kong': 'HK',
    'simplified': 'Simplified',
    'traditional': 'Traditional',
  };
  for (final entry in regions.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  // A bracketed or parenthesised two-letter code, e.g. "Spanish [ES]".
  final code = RegExp(r'[\[(]([a-z]{2})[\])]').firstMatch(text);
  if (code != null) return code.group(1)!.toUpperCase();
  return null;
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
  // No invented regions: an untagged "Spanish" stays "Spanish". Calling it
  // Spanish (ES) would state a region no metadata names, and a wrong region
  // is worse than a bare language -- the region shows only where a title or
  // tag actually states one.
  return name;
}
