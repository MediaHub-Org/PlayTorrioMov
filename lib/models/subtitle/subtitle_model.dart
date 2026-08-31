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
