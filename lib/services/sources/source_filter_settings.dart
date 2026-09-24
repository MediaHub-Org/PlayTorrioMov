import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/subtitle/subtitle_model.dart';

/// The audio-language filter options, in the order they are offered.
///
/// `'all'` first, then the keys [StreamSource.hasAudioLanguage] understands.
/// The `Watch` screen and the Sources & Filters settings page both read this
/// list, so a language added here shows up in both without a second edit.
const List<String> kAudioFilterKeys = [
  'all',
  'multi',
  'english',
  'hindi',
  'german',
  'french',
  'spanish',
  'russian',
  'japanese',
  'italian',
];

/// The resolution filter options, `'all'` first. The rest match the values
/// [StreamSource.quality] returns, so [StreamSource.hasQuality] is an exact
/// comparison rather than a second parser.
const List<String> kQualityFilterKeys = [
  'all',
  '4K',
  '1080p',
  '720p',
  '480p',
];

/// The languages a preferred-audio list can rank, alphabetical.
///
/// A separate list from [kAudioFilterKeys] on purpose. The filter is one
/// choice made from a short, dub-heavy set; the preference is an ordered
/// ranking, and it is matched against the *real* track language the player
/// reports rather than the release name -- so it needs the languages files
/// actually tag, which is a wider set.
const List<String> kPreferredAudioLanguageKeys = [
  'arabic',
  'chinese',
  'english',
  'french',
  'german',
  'hindi',
  'italian',
  'japanese',
  'korean',
  'portuguese',
  'russian',
  'spanish',
  'turkish',
];

/// The ISO 639-1 code each preference key stands for.
///
/// Matching a file's own track tag goes through [SubtitleLanguageGroup
/// .languageKey], the one alias table in the app, so `eng`, `English`,
/// `en-US` and `english` all reduce to `en` and then to the `english` key.
const Map<String, String> _preferredIsoToKey = {
  'ar': 'arabic',
  'zh': 'chinese',
  'en': 'english',
  'fr': 'french',
  'de': 'german',
  'hi': 'hindi',
  'it': 'italian',
  'ja': 'japanese',
  'ko': 'korean',
  'pt': 'portuguese',
  'ru': 'russian',
  'es': 'spanish',
  'tr': 'turkish',
};

/// The preference key a real track language belongs to, or null when the
/// track carries no usable language tag or one outside the ranked list.
///
/// Null is deliberately not "unknown": a caller ranking preferences must
/// skip such a track rather than treat it as a match.
String? preferredAudioKeyForTrackLanguage(String? rawLanguage) {
  final iso = SubtitleAutoPick.languageKey(rawLanguage);
  if (iso == null) return null;
  return _preferredIsoToKey[iso];
}

/// The label for one preferred-audio [key], in the app's language.
String preferredAudioLabel(AppLocalizations l10n, String key) => switch (key) {
  'arabic' => l10n.sourcePreferredArabic,
  'chinese' => l10n.sourcePreferredChinese,
  'english' => l10n.sourceFilterEnglish,
  'french' => l10n.sourceFilterFrench,
  'german' => l10n.sourceFilterGerman,
  'hindi' => l10n.sourceFilterHindi,
  'italian' => l10n.sourceFilterItalian,
  'japanese' => l10n.sourceFilterJapanese,
  'korean' => l10n.sourcePreferredKorean,
  'portuguese' => l10n.sourcePreferredPortuguese,
  'russian' => l10n.sourceFilterRussian,
  'spanish' => l10n.sourceFilterSpanish,
  'turkish' => l10n.sourcePreferredTurkish,
  _ => key,
};

/// The label for one audio-language [key], in the app's language.
///
/// A key with no row falls back to "All Audio" rather than throwing: the
/// filter key round-trips through SharedPreferences, and a value written by
/// an older build must not be able to blank the dropdown.
String audioFilterLabel(AppLocalizations l10n, String key) => switch (key) {
  'multi' => l10n.sourceFilterMultiAudio,
  'english' => l10n.sourceFilterEnglish,
  'hindi' => l10n.sourceFilterHindi,
  'german' => l10n.sourceFilterGerman,
  'french' => l10n.sourceFilterFrench,
  'spanish' => l10n.sourceFilterSpanish,
  'russian' => l10n.sourceFilterRussian,
  'japanese' => l10n.sourceFilterJapanese,
  'italian' => l10n.sourceFilterItalian,
  _ => l10n.sourceFilterAllAudio,
};

/// The label for one video-quality [key], in the app's language.
String qualityFilterLabel(AppLocalizations l10n, String key) => switch (key) {
  '4K' => l10n.sourceFilterQuality4k,
  '1080p' => l10n.sourceFilterQuality1080p,
  '720p' => l10n.sourceFilterQuality720p,
  '480p' => l10n.sourceFilterQuality480p,
  _ => l10n.sourceFilterAllQualities,
};

/// The audio-language and video-quality filters the source list opens with,
/// remembered across sessions.
///
/// These two used to be private `_selected…` fields on `WatchScreen`: they
/// reset to "All" every time a title was opened, so a viewer who only ever
/// wants Spanish audio -- or only 1080p -- re-picked it on every episode.
/// They now live here instead, are written whenever the dropdown changes,
/// and are read back on the next open.
///
/// The value is shared both ways on purpose: the Settings page is where you
/// set the default, and the Watch screen is where you override it for one
/// title, but they are the same value, so the last choice made anywhere wins.
abstract final class SourceFilterSettings {
  static const _keyAudioLanguage = 'source_filter_audio_language';
  static const _keyQuality = 'source_filter_quality';
  static const _keyPreferredAudio = 'source_preferred_audio_languages';

  /// The audio-language filter key, `'all'` meaning "no filter".
  static final ValueNotifier<String> audioLanguage = ValueNotifier<String>('all');

  /// The quality filter key, `'all'` meaning "no filter".
  static final ValueNotifier<String> quality = ValueNotifier<String>('all');

  /// The languages to prefer inside a file that carries several, in
  /// priority order. Empty means "do not override the file's own default".
  ///
  /// This is what the filter above cannot do. The filter picks which *source*
  /// to offer, from the release name; a source tagged MULTI says nothing
  /// about which languages are inside it, and only the player, once the file
  /// is open, knows. A ranking here is applied to those real tracks -- see
  /// `applyPreferredAudioTrack` in the player.
  static final ValueNotifier<List<String>> preferredAudioLanguages =
      ValueNotifier<List<String>>(<String>[]);

  /// Loads the saved filters. A stored key this build no longer knows is
  /// ignored rather than applied, so an unknown value can't leave the list
  /// filtered down to nothing with no dropdown entry explaining why.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final audio = prefs.getString(_keyAudioLanguage);
      if (audio != null && kAudioFilterKeys.contains(audio)) {
        audioLanguage.value = audio;
      }

      final quality = prefs.getString(_keyQuality);
      if (quality != null && kQualityFilterKeys.contains(quality)) {
        SourceFilterSettings.quality.value = quality;
      }

      final preferred = prefs.getStringList(_keyPreferredAudio) ?? const [];
      preferredAudioLanguages.value = preferred
          .where(kPreferredAudioLanguageKeys.contains)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error initializing: $e');
    }
  }

  /// Updates the audio-language filter and persists it.
  static Future<void> setAudioLanguage(String key) async {
    if (!kAudioFilterKeys.contains(key)) return;
    audioLanguage.value = key;
    await _persist(_keyAudioLanguage, key);
  }

  /// Updates the video-quality filter and persists it.
  static Future<void> setQuality(String key) async {
    if (!kQualityFilterKeys.contains(key)) return;
    quality.value = key;
    await _persist(_keyQuality, key);
  }

  /// Returns the two *list* filters -- audio language and quality -- to "no
  /// filter", without touching the preferred-audio ranking.
  ///
  /// This is the "clear filters" escape offered on an emptied source list.
  /// Clearing the ranking along with them would be surprising: the ranking
  /// cannot empty a list (it acts inside a file, after a source is chosen),
  /// so it is not a filter the user is trying to escape.
  static Future<void> clearFilters() async {
    audioLanguage.value = 'all';
    quality.value = 'all';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAudioLanguage);
      await prefs.remove(_keyQuality);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error clearing filters: $e');
    }
  }

  /// Returns every setting on this service to its default and persists that.
  static Future<void> reset() async {
    audioLanguage.value = 'all';
    quality.value = 'all';
    preferredAudioLanguages.value = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAudioLanguage);
      await prefs.remove(_keyQuality);
      await prefs.remove(_keyPreferredAudio);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error resetting: $e');
    }
  }

  /// Moves [key] one place up the [preferredAudioLanguages] ranking, and
  /// persists the result. A no-op at the top.
  static Future<void> promotePreferredAudio(String key) async {
    final list = List<String>.from(preferredAudioLanguages.value);
    final idx = list.indexOf(key);
    if (idx <= 0) return;
    final moved = list.removeAt(idx);
    list.insert(idx - 1, moved);
    await _savePreferredAudio(list);
  }

  /// Moves [key] one place down the ranking, and persists the result. A
  /// no-op at the bottom.
  static Future<void> demotePreferredAudio(String key) async {
    final list = List<String>.from(preferredAudioLanguages.value);
    final idx = list.indexOf(key);
    if (idx < 0 || idx >= list.length - 1) return;
    final moved = list.removeAt(idx);
    list.insert(idx + 1, moved);
    await _savePreferredAudio(list);
  }

  /// Adds [key] to the end of the ranking, or removes it if it is already
  /// there. The settings page's chips are a toggle for exactly this.
  static Future<void> togglePreferredAudio(String key) async {
    if (!kPreferredAudioLanguageKeys.contains(key)) return;
    final list = List<String>.from(preferredAudioLanguages.value);
    if (!list.remove(key)) list.add(key);
    await _savePreferredAudio(list);
  }

  static Future<void> _savePreferredAudio(List<String> list) async {
    preferredAudioLanguages.value = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyPreferredAudio, list);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error saving preferred audio: $e');
    }
  }

  static Future<void> _persist(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error saving $key: $e');
    }
  }
}

/// The index of the track to switch to, given each track's raw language tag
/// in playback order, or null to leave the file's own default alone.
///
/// Pure and free-standing so the ranking can be tested without a player. The
/// ranking is walked in priority order and the first *track* that satisfies
/// the highest-priority language wins, so `[Spanish, English]` on a file with
/// English then Spanish picks Spanish, not the first track matching anything.
///
/// Returns null when the ranking is empty -- the setting is opt-in, and an
/// empty list means "never override the file" -- or when no track carries a
/// ranked language, in which case the muxer's default is the honest answer.
int? preferredAudioTrackIndex(List<String?> trackLanguages) {
  final rank = SourceFilterSettings.preferredAudioLanguages.value;
  if (rank.isEmpty) return null;
  for (final wanted in rank) {
    for (var i = 0; i < trackLanguages.length; i++) {
      if (preferredAudioKeyForTrackLanguage(trackLanguages[i]) == wanted) {
        return i;
      }
    }
  }
  return null;
}