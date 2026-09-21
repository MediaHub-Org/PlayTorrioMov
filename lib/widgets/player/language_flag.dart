// lib/widgets/player/language_flag.dart
//
// The one place a language name is turned into a flag for the player's
// subtitle and audio menus.
//
// Two bugs shaped this file.
//
// 1. Matching. Each menu once carried its own `_getLanguageEmoji` that
//    matched *ISO-639 code substrings* against what is actually a *display
//    name* (`SubtitleLanguageGroup.language` holds `subtitleLanguageName(...)`,
//    so it reads "Spanish" and "Chinese", not "es" and "zh"). "Spanish"
//    contains no "es"/"spa" substring so it drew the globe, "Chinese"
//    contains "hi" so it drew the Indian flag, and the two menus disagreed on
//    the same language. Keying on the display name settles all three, because
//    there is a single canonical name per language (see
//    subtitle_languages.dart).
//
// 2. Rendering. A flag emoji is two regional-indicator letters that the
//    system emoji font ligates into a picture. Android's and macOS's do;
//    Windows' Segoe UI Emoji ships no flag glyphs at all, so every flag there
//    drew as its two bare letters ("ES", "GB"). The flags are bundled as
//    small images (assets/flags/<country>.png, ~1KB each) so every platform
//    draws the same thing.
//    They are 80px-wide PNGs fetched from flagcdn.com (https://flagcdn.com/w80/<country>.png);
//    to add a language, add its row below and drop the matching file in.

import 'package:flutter/material.dart';

/// Language-name keyword -> ISO 3166 country code of the flag that stands for
/// it. Order matters only where one keyword contains another; none do today.
///
/// Each code here needs a matching `assets/flags/<code>.png`.
const Map<String, String> _languageCountry = {
  'arabic': 'sa',
  'english': 'gb',
  'portuguese': 'br',
  'spanish': 'es',
  'french': 'fr',
  'german': 'de',
  'italian': 'it',
  'russian': 'ru',
  'japanese': 'jp',
  'korean': 'kr',
  'chinese': 'cn',
  'hindi': 'in',
  'turkish': 'tr',
  'dutch': 'nl',
  'swedish': 'se',
  'norwegian': 'no',
  'danish': 'dk',
  'finnish': 'fi',
  'polish': 'pl',
  'ukrainian': 'ua',
  'greek': 'gr',
  'czech': 'cz',
  'hungarian': 'hu',
  'romanian': 'ro',
  'persian': 'ir',
  'croatian': 'hr',
  'serbian': 'rs',
  'bulgarian': 'bg',
  'hebrew': 'il',
  'indonesian': 'id',
  'vietnamese': 'vn',
  'thai': 'th',
  'tagalog': 'ph',
  'filipino': 'ph',
  'albanian': 'al',
  'bengali': 'bd',
  'bosnian': 'ba',
  // Catalonia has no country code; `es-ct` is the Senyera, drawn rather than
  // fetched because flag CDNs do not carry it. Kurdistan (`ku`) likewise.
  'catalan': 'es-ct',
  'icelandic': 'is',
  'kurdish': 'ku',
  'macedonian': 'mk',
  // Before 'malay': "Malayalam" contains it and is an Indian language.
  'malayalam': 'in',
  'malay': 'my',
  'mongolian': 'mn',
  'pashto': 'af',
  'sinhala': 'lk',
  'slovak': 'sk',
  'slovenian': 'si',
  'somali': 'so',
  'swahili': 'tz',
};

/// The country code whose flag stands for [language] (a display name such as
/// "Spanish (Latin America)"), or null when there is none.
String? languageCountryCode(String? language) {
  final name = (language ?? '').toLowerCase();
  for (final entry in _languageCountry.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

/// A language's flag, [height] tall, or [fallback] (the globe by default)
/// when the language has no flag.
class LanguageFlag extends StatelessWidget {
  final String? language;
  final double height;
  final String fallback;

  const LanguageFlag(
    this.language, {
    super.key,
    this.height = 12,
    this.fallback = '🌐',
  });

  @override
  Widget build(BuildContext context) {
    final code = languageCountryCode(language);
    // The emoji text is a fixed-size box of the same height, so a row of
    // mixed flags and fallbacks keeps its baseline.
    final placeholder = SizedBox(
      height: height,
      child: Text(fallback, style: TextStyle(fontSize: height * 0.9, height: 1)),
    );
    if (code == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.asset(
        'assets/flags/$code.png',
        height: height,
        // Flags are 2:1 or thereabouts; a fixed height with a free width
        // keeps each one's own proportions (Nepal aside, none is square).
        fit: BoxFit.fitHeight,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
