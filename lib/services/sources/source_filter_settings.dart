import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/subtitle/subtitle_model.dart';

/// The audio-language filter options, in the order they are offered.
///
/// This is the *one* audio list now. It used to be a short dub-heavy set for
/// the filter, with a separate, wider [kPreferredAudioLanguageKeys] for the
/// ranking -- two lists that both said "audio language" and did different
/// jobs, which is what made the settings page read as three unrelated
/// blocks. They are one list because they are one choice: pick the languages
/// you want, and the source list shows sources matching any of them while
/// the player prefers them in the order you put them.
///
/// Every key here must be one [StreamSource.getAudioLanguages] can detect.
/// A key the detector has no pattern for would hide every source, since a
/// language it cannot see is absent from all of them.
const List<String> kAudioFilterKeys = [
  'multi',
  'english',
  'hindi',
  'german',
  'french',
  'spanish',
  'russian',
  'japanese',
  'italian',
  'arabic',
  'chinese',
  'korean',
  'portuguese',
  'turkish',
];

/// The resolution filter options. The rest match the values
/// [StreamSource.quality] returns, so [StreamSource.hasQuality] is an exact
/// comparison rather than a second parser.
const List<String> kQualityFilterKeys = [
  '4K',
  '1080p',
  '720p',
  '480p',
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

/// The label for one audio-language [key], in the app's language.
///
/// A key with no row falls back to the raw key rather than throwing: the
/// filter round-trips through SharedPreferences, and a value written by an
/// older build must not be able to blank a chip.
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
  'arabic' => l10n.sourcePreferredArabic,
  'chinese' => l10n.sourcePreferredChinese,
  'korean' => l10n.sourcePreferredKorean,
  'portuguese' => l10n.sourcePreferredPortuguese,
  'turkish' => l10n.sourcePreferredTurkish,
  _ => key,
};

/// The label for one video-quality [key], in the app's language.
String qualityFilterLabel(AppLocalizations l10n, String key) => switch (key) {
  '4K' => l10n.sourceFilterQuality4k,
  '1080p' => l10n.sourceFilterQuality1080p,
  '720p' => l10n.sourceFilterQuality720p,
  '480p' => l10n.sourceFilterQuality480p,
  _ => key,
};

/// The audio-language and video-quality filters the source list opens with,
/// remembered across sessions.
///
/// These two used to be private `_selected…` fields on `WatchScreen`: they
/// reset to "All" every time a title was opened, so a viewer who only ever
/// wants Spanish audio -- or only 1080p -- re-picked it on every episode.
/// They now live here instead, are written whenever the selection changes,
/// and are read back on the next open.
///
/// The value is shared both ways on purpose: the Settings page is where you
/// set the default, and the Watch screen is where you override it for one
/// title, but they are the same value, so the last choice made anywhere wins.
///
/// Both are *lists*, and an empty list means "no filter". The audio list is
/// also the preferred-audio ranking: it is walked in order when a file with
/// several tracks opens, so the first entry is the one you want most. One
/// list rather than two because the two were always the same choice -- which
/// languages do you want -- asked twice with different answers.
abstract final class SourceFilterSettings {
  static const _keyAudioLanguage = 'source_filter_audio_language';
  static const _keyQuality = 'source_filter_quality';
  static const _keyPreferredAudio = 'source_preferred_audio_languages';

  /// The selected audio languages, in preference order. Empty means "no
  /// filter", and also "do not override the file's own default track".
  static final ValueNotifier<List<String>> audioLanguages =
      ValueNotifier<List<String>>(<String>[]);

  /// The selected video qualities. Empty means "no filter". Unordered: a
  /// resolution has no "inside the file" equivalent to rank, and the source
  /// list's own sort already covers "best first".
  static final ValueNotifier<List<String>> qualities =
      ValueNotifier<List<String>>(<String>[]);

  /// Loads the saved filters. A stored key this build no longer knows is
  /// ignored rather than applied, so an unknown value can't leave the list
  /// filtered down to nothing with no chip explaining why.
  ///
  /// The two single-value keys are still read, and folded into the lists.
  /// They are what the previous build wrote, and a viewer who had picked
  /// Spanish should not have to pick it again after updating. The old keys
  /// are left in place rather than removed: a downgrade would otherwise lose
  /// the setting, and they cost nothing.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      audioLanguages.value = _readList(
        prefs.get(_keyAudioLanguage),
        kAudioFilterKeys,
      );
      qualities.value = _readList(
        prefs.get(_keyQuality),
        kQualityFilterKeys,
      );

      // The ranking was its own key. It is the same list now, so it is
      // folded in after the filter: a language the viewer had ranked but not
      // filtered on still belongs in the list, and appending keeps the
      // ranking's own order intact.
      final ranked = prefs.getStringList(_keyPreferredAudio) ?? const <String>[];
      final merged = List<String>.from(audioLanguages.value);
      for (final key in ranked) {
        if (kAudioFilterKeys.contains(key) && !merged.contains(key)) {
          merged.add(key);
        }
      }
      audioLanguages.value = merged;
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error initializing: $e');
    }
  }

  /// Reads one filter out of storage, accepting either shape it has been
  /// written in.
  ///
  /// The previous build stored a single `String` per filter, with `'all'` as
  /// its "no filter" sentinel; this one stores a `StringList` and uses empty
  /// for the same thing. Both are read here so an update does not silently
  /// drop a viewer's choice.
  ///
  /// The type is checked rather than assumed because `getStringList` on a
  /// stored `String` throws, and the throw would be caught by the caller's
  /// handler -- turning a migration into a silent reset, which is the exact
  /// failure this is here to prevent.
  static List<String> _readList(Object? raw, List<String> known) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .where(known.contains)
          .toList(growable: false);
    }
    if (raw is String && raw != 'all' && known.contains(raw)) {
      return <String>[raw];
    }
    return const <String>[];
  }

  /// Adds [key] to the end of the audio list, or removes it if it is already
  /// there. The settings page's chips and the Watch screen's menu are both a
  /// toggle for exactly this.
  static Future<void> toggleAudioLanguage(String key) async {
    if (!kAudioFilterKeys.contains(key)) return;
    final list = List<String>.from(audioLanguages.value);
    if (!list.remove(key)) list.add(key);
    await _saveAudioLanguages(list);
  }

  /// Adds [key] to the end of the quality list, or removes it if it is
  /// already there.
  static Future<void> toggleQuality(String key) async {
    if (!kQualityFilterKeys.contains(key)) return;
    final list = List<String>.from(qualities.value);
    if (!list.remove(key)) list.add(key);
    await _saveQualities(list);
  }

  /// Returns the two filters to "no filter", without touching the audio
  /// list's *order* -- clearing is not the same as forgetting.
  ///
  /// This is the "clear filters" escape offered on an emptied source list.
  static Future<void> clearFilters() async {
    audioLanguages.value = const <String>[];
    qualities.value = const <String>[];
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
    audioLanguages.value = const <String>[];
    qualities.value = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAudioLanguage);
      await prefs.remove(_keyQuality);
      await prefs.remove(_keyPreferredAudio);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error resetting: $e');
    }
  }

  /// Moves [key] one place up the audio list, and persists the result. A
  /// no-op at the top.
  static Future<void> promoteAudioLanguage(String key) async {
    final list = List<String>.from(audioLanguages.value);
    final idx = list.indexOf(key);
    if (idx <= 0) return;
    final moved = list.removeAt(idx);
    list.insert(idx - 1, moved);
    await _saveAudioLanguages(list);
  }

  /// Moves [key] one place down the audio list, and persists the result. A
  /// no-op at the bottom.
  static Future<void> demoteAudioLanguage(String key) async {
    final list = List<String>.from(audioLanguages.value);
    final idx = list.indexOf(key);
    if (idx < 0 || idx >= list.length - 1) return;
    final moved = list.removeAt(idx);
    list.insert(idx + 1, moved);
    await _saveAudioLanguages(list);
  }

  static Future<void> _saveAudioLanguages(List<String> list) async {
    audioLanguages.value = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyAudioLanguage, list);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error saving audio languages: $e');
    }
  }

  static Future<void> _saveQualities(List<String> list) async {
    qualities.value = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyQuality, list);
    } catch (e) {
      debugPrint('[SourceFilterSettings] Error saving qualities: $e');
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
  final rank = SourceFilterSettings.audioLanguages.value;
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