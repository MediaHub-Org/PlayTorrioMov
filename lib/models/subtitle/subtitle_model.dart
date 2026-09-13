class SubtitleVariant {
  final String providerName;
  final String language;
  final String title;
  final String downloadUrl;
  final String format; // 'srt', 'vtt', 'zip'
  final Map<String, dynamic> extraData; // For provider specific tokens if needed

  SubtitleVariant({
    required this.providerName,
    required this.language,
    required this.title,
    required this.downloadUrl,
    required this.format,
    this.extraData = const {},
  });
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

  const PlayerEmbeddedSubtitle({
    required this.index,
    required this.title,
    this.language,
    this.codec,
    this.isDefault = false,
  });
}

/// Which subtitle to turn on when the user presses CC and has not chosen a
/// track themselves.
///
/// The transport bar's subtitle button is a toggle, not a question -- it
/// used to open the picker when nothing had been selected yet, which is the
/// one thing a CC button should never do. These rules give it an answer.
///
/// Kept out of the player so the rules can be read and tested on their own;
/// they are a judgement call about what "best" means, not player plumbing.
abstract final class SubtitleAutoPick {
  /// The embedded track to use, or null if the stream carries none.
  ///
  /// A file's own `default` flag wins: it is the closest thing to an
  /// authored answer about which track belongs to this release. English
  /// comes next as the most widely useful fallback, and failing both, the
  /// first track -- a subtitle in the wrong language is still a better
  /// answer to "turn subtitles on" than nothing happening.
  static PlayerEmbeddedSubtitle? embedded(
    List<PlayerEmbeddedSubtitle> tracks,
  ) {
    if (tracks.isEmpty) return null;

    for (final track in tracks) {
      if (track.isDefault) return track;
    }
    for (final track in tracks) {
      if (_isEnglish(track.language) || _isEnglish(track.title)) return track;
    }
    return tracks.first;
  }

  /// The downloadable subtitle to fall back on when there is no embedded
  /// track, taken from whatever a search has already turned up. Never
  /// starts a new search: a toggle should not leave the user waiting on the
  /// network to find out whether it worked.
  static SubtitleVariant? variant(List<SubtitleLanguageGroup> groups) {
    for (final group in groups) {
      if (_isEnglish(group.language) && group.variants.isNotEmpty) {
        return group.variants.first;
      }
    }
    for (final group in groups) {
      if (group.variants.isNotEmpty) return group.variants.first;
    }
    return null;
  }

  /// Matches the spellings these actually arrive as -- "en", "eng",
  /// "English", "en-US" -- without matching every language that merely
  /// contains those letters.
  static bool _isEnglish(String? value) {
    if (value == null) return false;
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == 'en' || lower == 'eng') return true;
    if (lower.startsWith('en-') || lower.startsWith('en_')) return true;
    return lower.contains('english');
  }
}
