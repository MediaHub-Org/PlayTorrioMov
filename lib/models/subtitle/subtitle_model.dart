class SubtitleVariant {
  final String providerName;
  final String language;
  final String title;
  final String downloadUrl;
  final String format; // 'srt', 'vtt', 'zip'
  final Map<String, dynamic> extraData; // For provider specific tokens if needed

  /// The provider says this track is for the hearing impaired — its own
  /// flag, not a word found in the title. Wyzie sends `isHearingImpaired`;
  /// the others do not, so their tracks are classified from the title.
  final bool isHearingImpaired;

  /// The provider says this is a forced-narrative track — subtitles for the
  /// bits of dialogue not in the audio's language, not a translation.
  /// Stremio addons mark it in the file name or a `forced` field; detection
  /// falls back to the title.
  final bool isForced;

  SubtitleVariant({
    required this.providerName,
    required this.language,
    required this.title,
    required this.downloadUrl,
    required this.format,
    this.extraData = const {},
    bool? isHearingImpaired,
    bool? isForced,
  })  : // Fall back to the title when the provider has no flag of its own.
        // Title sniffing is weak -- a release named "White.House" matches
        // "HI" -- but a word-boundary match on the known markers is the only
        // evidence the title-only providers offer, and it is what the menu
        // was doing before, only now it happens once at the source instead
        // of being re-derived at every render.
        isHearingImpaired =
            isHearingImpaired ?? titleSaysHearingImpaired(title),
        isForced = isForced ?? titleSaysForced(title);
}

/// Whether a subtitle's title marks it for the deaf and hard of hearing.
/// Weak evidence -- a release named "White.House" matches "HI" -- but all a
/// title-only source offers. Shared by online variants and embedded tracks.
bool titleSaysHearingImpaired(String title) {
  // Word boundaries, so "Movie.2020.SDH" and "Movie_CC" match as well as
  // "Movie (CC)" -- release names separate with dots and underscores, and the
  // old `' sdh'` check only saw a space.
  return _hearingImpairedMarker.hasMatch(title);
}

final RegExp _hearingImpairedMarker = RegExp(
  r'\b(sdh|hoh|hi|cc)\b|hearing[\s._-]*impaired|\bdeaf\b',
  caseSensitive: false,
);

/// Whether a subtitle's title marks it as a forced-narrative track.
bool titleSaysForced(String title) {
  return RegExp(r'\bforced\b', caseSensitive: false).hasMatch(title);
}

class SubtitleLanguageGroup {
  final String language;
  final List<SubtitleVariant> variants;

  SubtitleLanguageGroup({
    required this.language,
    required this.variants,
  });
}

class PlayerEmbeddedSubtitle {
  final int index;
  final String title;
  final String? language;
  final String? codec;
  final bool isDefault;

  /// The container marks this track forced (mpv's own `forced` flag), as
  /// opposed to a title that merely says so -- see [isForced].
  final bool isForcedTrack;

  const PlayerEmbeddedSubtitle({
    required this.index,
    required this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isForcedTrack = false,
  });

  /// Marked forced by the file's flag, or by its title.
  bool get isForced => isForcedTrack || titleSaysForced(title);

  bool get isHearingImpaired => titleSaysHearingImpaired(title);

  PlayerEmbeddedSubtitle withFlags({
    required bool isDefault,
    required bool isForcedTrack,
  }) => PlayerEmbeddedSubtitle(
    index: index,
    title: title,
    language: language,
    codec: codec,
    isDefault: isDefault,
    isForcedTrack: isForcedTrack,
  );
}

/// Which subtitle to turn on when the user presses CC and has not chosen a
/// track themselves.
///
/// The transport bar's subtitle button is a toggle, not a question -- it
/// used to open the picker when nothing had been selected yet, which is the
/// one thing a CC button should never do. These rules give it an answer.
///
/// **The answer is the audio language.** Subtitles exist to put in writing
/// what is being said, so the track that matches the selected audio is the
/// one that makes the words on screen the words in the room. Everything
/// below it is a fallback for when no such track exists.
///
/// Kept out of the player so the rules can be read and tested on their own;
/// they are a judgement call about what "best" means, not player plumbing.
abstract final class SubtitleAutoPick {
  /// The embedded track to use, or null if the stream carries none.
  ///
  /// In order: the track matching [audioLanguage], then the one the file
  /// itself marks default, then English, then simply the first -- a
  /// subtitle in the wrong language still answers "turn subtitles on"
  /// better than nothing happening.
  static PlayerEmbeddedSubtitle? embedded(
    List<PlayerEmbeddedSubtitle> tracks, {
    String? audioLanguage,
  }) {
    if (tracks.isEmpty) return null;

    final spoken = languageKey(audioLanguage);
    if (spoken != null) {
      for (final track in tracks) {
        if (languageKey(track.language) == spoken ||
            languageKey(track.title) == spoken) {
          return track;
        }
      }
    }

    for (final track in tracks) {
      if (track.isDefault) return track;
    }
    for (final track in tracks) {
      if (languageKey(track.language) == 'en' ||
          languageKey(track.title) == 'en') {
        return track;
      }
    }
    return tracks.first;
  }

  /// The downloadable subtitle to fall back on when there is no embedded
  /// track, taken from whatever a search has already turned up. Never
  /// starts a new search: a toggle should not leave the user waiting on the
  /// network to find out whether it worked.
  static SubtitleVariant? variant(
    List<SubtitleLanguageGroup> groups, {
    String? audioLanguage,
  }) {
    final spoken = languageKey(audioLanguage);
    if (spoken != null) {
      for (final group in groups) {
        if (languageKey(group.language) == spoken && group.variants.isNotEmpty) {
          return group.variants.first;
        }
      }
    }

    for (final group in groups) {
      if (languageKey(group.language) == 'en' && group.variants.isNotEmpty) {
        return group.variants.first;
      }
    }
    for (final group in groups) {
      if (group.variants.isNotEmpty) return group.variants.first;
    }
    return null;
  }

  /// Reduces a language as a stream might spell it -- "en", "eng",
  /// "English", "en-US", "Español", "ja (Japanese)" -- to one comparable
  /// key, or null when it says nothing useful.
  ///
  /// Audio and subtitle tracks in the same file are routinely labeled in
  /// different schemes, so comparing the raw strings would miss most real
  /// matches: an "eng" audio track beside an "English" subtitle is the
  /// common case, not the exotic one.
  static String? languageKey(String? value) {
    if (value == null) return null;
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty || lower == 'und' || lower == 'unknown') return null;

    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        if (lower == alias ||
            lower.startsWith('$alias-') ||
            lower.startsWith('${alias}_') ||
            _containsWord(lower, alias)) {
          return entry.key;
        }
      }
    }

    // Unknown language: its own first token still compares equal to itself,
    // so two tracks labeled the same way match even off this table.
    final token = lower.split(RegExp(r'[^a-z]+')).firstWhere(
      (t) => t.isNotEmpty,
      orElse: () => '',
    );
    return token.isEmpty ? null : token;
  }

  /// Whole-word only: without this, "slovenian" matches "en" and a Slovenian
  /// track wins the English fallback.
  static bool _containsWord(String haystack, String needle) {
    if (needle.length <= 3) return false;
    return RegExp('(?:^|[^a-z])${RegExp.escape(needle)}(?:\$|[^a-z])')
        .hasMatch(haystack);
  }

  /// Only the languages this app's catalogs actually surface, each keyed
  /// by its ISO 639-1 code. Anything absent still matches itself through
  /// the token fallback above.
  static const Map<String, List<String>> _aliases = {
    'en': ['en', 'eng', 'english'],
    'es': ['es', 'spa', 'esp', 'spanish', 'espanol', 'español', 'castellano'],
    'fr': ['fr', 'fre', 'fra', 'french', 'francais', 'français'],
    'de': ['de', 'ger', 'deu', 'german', 'deutsch'],
    'it': ['it', 'ita', 'italian', 'italiano'],
    'pt': ['pt', 'por', 'portuguese', 'portugues', 'português'],
    'ja': ['ja', 'jpn', 'jap', 'japanese'],
    'ko': ['ko', 'kor', 'korean'],
    'zh': ['zh', 'chi', 'zho', 'chinese', 'mandarin', 'cantonese'],
    'ru': ['ru', 'rus', 'russian'],
    'ar': ['ar', 'ara', 'arabic'],
    'hi': ['hi', 'hin', 'hindi'],
    'tr': ['tr', 'tur', 'turkish'],
    'pl': ['pl', 'pol', 'polish'],
    'nl': ['nl', 'dut', 'nld', 'dutch'],
    'sv': ['sv', 'swe', 'swedish'],
    'da': ['da', 'dan', 'danish'],
    'no': ['no', 'nor', 'norwegian'],
    'fi': ['fi', 'fin', 'finnish'],
  };
}
