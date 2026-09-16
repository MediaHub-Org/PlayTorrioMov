// lib/widgets/player/language_flag.dart
//
// The one place a language name is turned into a flag emoji for the player's
// subtitle and audio menus.
//
// The bug this replaces: each menu carried its own `_getLanguageEmoji` that
// matched *ISO-639 code substrings* against what is actually a *display name*
// (`SubtitleLanguageGroup.language` holds `subtitleLanguageName(...)`, so it
// reads "Spanish" and "Chinese", not "es" and "zh"). Three consequences:
//
// - "Spanish" contains no "es"/"spa" substring, so it rendered the 🌐 globe.
// - "Chinese" contains "hi", so it rendered the Indian flag 🇮🇳.
// - The two menus disagreed on the same language (audio matched `fra`, the
//   subtitle menu did not), so one language showed two different flags
//   depending on which panel you opened.
//
// Keying on the exact display name settles all three, because there is a
// single canonical name per language (see subtitle_languages.dart).

/// The flag emoji for a language name or code, or the globe when unknown.
String languageFlag(String? language) {
  final name = (language ?? '').toLowerCase();

  if (name.contains('arabic')) return '🇸🇦';
  if (name.contains('english')) return '🇬🇧';
  if (name.contains('portuguese')) return '🇧🇷';
  if (name.contains('spanish')) return '🇪🇸';
  if (name.contains('french')) return '🇫🇷';
  if (name.contains('german')) return '🇩🇪';
  if (name.contains('italian')) return '🇮🇹';
  if (name.contains('russian')) return '🇷🇺';
  if (name.contains('japanese')) return '🇯🇵';
  if (name.contains('korean')) return '🇰🇷';
  if (name.contains('chinese')) return '🇨🇳';
  if (name.contains('hindi')) return '🇮🇳';
  if (name.contains('turkish')) return '🇹🇷';
  if (name.contains('dutch')) return '🇳🇱';
  if (name.contains('swedish')) return '🇸🇪';
  if (name.contains('norwegian')) return '🇳🇴';
  if (name.contains('danish')) return '🇩🇰';
  if (name.contains('finnish')) return '🇫🇮';
  if (name.contains('polish')) return '🇵🇱';
  if (name.contains('ukrainian')) return '🇺🇦';
  if (name.contains('greek')) return '🇬🇷';
  if (name.contains('czech')) return '🇨🇿';
  if (name.contains('hungarian')) return '🇭🇺';
  if (name.contains('romanian')) return '🇷🇴';
  if (name.contains('persian')) return '🇮🇷';
  if (name.contains('croatian')) return '🇭🇷';
  if (name.contains('serbian')) return '🇷🇸';
  if (name.contains('bulgarian')) return '🇧🇬';
  if (name.contains('hebrew')) return '🇮🇱';
  if (name.contains('indonesian')) return '🇮🇩';
  if (name.contains('vietnamese')) return '🇻🇳';
  if (name.contains('thai')) return '🇹🇭';
  if (name.contains('tagalog') || name.contains('filipino')) return '🇵🇭';

  return '🌐';
}