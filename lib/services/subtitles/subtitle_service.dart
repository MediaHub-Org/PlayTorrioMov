
import 'package:flutter/foundation.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import './providers/subdl_provider.dart';
import './providers/subtitlecat_provider.dart';
import './providers/wyzie_provider.dart';
import './providers/opensubtitles_provider.dart';
import './providers/stremio_subtitle_provider.dart';
import './subtitle_provider.dart';
import './subtitle_languages.dart';

class SubtitleService {
  static final SubtitleService _instance = SubtitleService._internal();
  factory SubtitleService() => _instance;
  SubtitleService._internal();

  final List<SubtitleProvider> _providers = [
    WyzieProvider(),
    SubtitleCatProvider(),
    OpenSubtitlesProvider(),
    SubdlProvider(),
    StremioSubtitleProvider(),
  ];

  /// Fetches subtitles from all registered providers concurrently.
  /// Groups the results by language.
  Future<List<SubtitleLanguageGroup>> fetchAllSubtitles(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) async {
    final futures = _providers.map((p) => p.search(
      movieName,
      imdbId: imdbId,
      season: season,
      episode: episode,
      year: year,
    ));
    
    // Wait for all providers to finish (or fail)
    final results = await Future.wait(futures.map((f) => f.catchError((_) => <SubtitleVariant>[])));
    
    final List<SubtitleVariant> allVariants = results.expand((x) => x).toList();
    
    if (allVariants.isEmpty) return [];

    // Group by canonical language. The same language arrives under
    // different labels from different providers -- "Chinese" and "Chinese
    // (Simplified)" and mpv's `zhc` are one language to a viewer choosing
    // what to read -- and separate groups for each label made the picker's
    // language bar a row of near-duplicates.
    final Map<String, List<SubtitleVariant>> grouped = {};
    final seenVariants = <String>{};
    for (final variant in allVariants) {
      final language = canonicalLanguageGroup(variant.language);
      // A variant with no language is not offered. It cannot be listed --
      // the row would have no name -- and it cannot be chosen deliberately,
      // because there is nothing to choose it by. Providers do send these:
      // a result whose language field is empty or a code the table does not
      // know. Dropping them is better than a row reading "Unknown".
      if (language.isEmpty) continue;

      final cleaned = _cleanVariant(variant, movieName, language);
      final key = _variantKey(cleaned, language);
      if (!seenVariants.add(key)) continue;
      grouped.putIfAbsent(language, () => []).add(cleaned);
    }

    // Sort languages alphabetically
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    return sortedKeys.map((lang) {
      return SubtitleLanguageGroup(
        language: lang,
        variants: dedupeVariants(grouped[lang]!),
      );
    }).toList();
  }

  @visibleForTesting
  static SubtitleVariant cleanVariant(
    SubtitleVariant variant,
    String movieName,
    String language,
  ) =>
      _cleanVariant(variant, movieName, language);

  @visibleForTesting
  static String variantKey(SubtitleVariant variant, String language) =>
      _variantKey(variant, language);

  static SubtitleVariant _cleanVariant(
    SubtitleVariant variant,
    String movieName,
    String language,
  ) {
    var title = variant.title.trim();
    for (final word in _words(movieName)) {
      title = title.replaceAll(
        RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false),
        ' ',
      );
    }
    title = title
        .replaceAll(RegExp(r'\.(srt|vtt|ass|ssa|sub|zip)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final word in _words(language)) {
      title = title.replaceAll(
        RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false),
        ' ',
      );
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty ||
        RegExp(r'^(subtitle|subtitles|stremio addon|wyzie)\s*#?\d*$', caseSensitive: false)
            .hasMatch(title)) {
      final tags = <String>[];
      if (variant.isHearingImpaired) tags.add('CC');
      if (variant.isForced) tags.add('Forced');
      if (variant.extraData['isTranslate'] == true) tags.add('Translated');
      title = tags.isEmpty ? 'Standard' : tags.join(' - ');
    }

    return SubtitleVariant(
      providerName: variant.providerName,
      language: subtitleTrackLanguageName(language),
      title: title,
      downloadUrl: variant.downloadUrl,
      format: variant.format,
      extraData: variant.extraData,
      isHearingImpaired: variant.isHearingImpaired,
      isForced: variant.isForced,
    );
  }

  static String _variantKey(SubtitleVariant variant, String language) {
    final title = variant.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final translated = variant.extraData['isTranslate'] == true ? 'translated' : '';
    // The provider is part of the identity. Without it, two different files
    // that happen to share a language and a cleaned title collapsed into one
    // -- and the survivor was whichever provider answered first, so a
    // SubtitleCat file could be dropped in favour of an OpenSubtitles one
    // with no way to tell. They are different downloads; the viewer is
    // choosing between them.
    final provider = variant.providerName.toLowerCase().trim();
    return '$language|$provider|$title|${variant.isHearingImpaired}|${variant.isForced}|$translated';
  }

  /// Collapses variants that are the same file offered twice, and numbers the
  /// ones that are genuinely different but identically named.
  ///
  /// A provider can return the same release several times -- SubtitleCat
  /// lists a file once per language it has been translated into, and the
  /// translations share a title. Those are one choice, not four. What is left
  /// after collapsing is numbered, because four rows reading "SubtitleCat"
  /// give a viewer nothing to choose between them by.
  @visibleForTesting
  static List<SubtitleVariant> dedupeVariants(List<SubtitleVariant> variants) {
    final seen = <String>{};
    final kept = <SubtitleVariant>[];
    for (final variant in variants) {
      // The URL is in the key, so only an exact repeat collapses. Two files
      // that share a name but not a URL are two downloads, and the viewer is
      // choosing between them.
      final key = [
        variant.providerName.toLowerCase().trim(),
        variant.title.toLowerCase().trim(),
        variant.format.toLowerCase().trim(),
        variant.downloadUrl.trim(),
        variant.isHearingImpaired,
        variant.isForced,
        variant.extraData['isTranslate'] == true,
      ].join('|');
      if (!seen.add(key)) continue;
      kept.add(variant);
    }

    // Number only the names that repeat *within one provider*, so a group of
    // distinct titles is left alone, two providers each offering one file do
    // not become "#1" and "#2", and a provider's own identical rows become
    // #1, #2, #3.
    String groupOf(SubtitleVariant v) =>
        '${v.providerName.toLowerCase().trim()}|${v.title.toLowerCase().trim()}';
    final totals = <String, int>{};
    for (final variant in kept) {
      final group = groupOf(variant);
      totals[group] = (totals[group] ?? 0) + 1;
    }
    final seenCount = <String, int>{};
    return [
      for (final variant in kept)
        () {
          final group = groupOf(variant);
          if (totals[group]! < 2) return variant;
          final n = seenCount[group] = (seenCount[group] ?? 0) + 1;
          return SubtitleVariant(
            providerName: variant.providerName,
            language: variant.language,
            title: '${variant.title} #$n',
            downloadUrl: variant.downloadUrl,
            format: variant.format,
            extraData: variant.extraData,
            isHearingImpaired: variant.isHearingImpaired,
            isForced: variant.isForced,
          );
        }(),
    ];
  }

  static Set<String> _words(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 2)
      .toSet();

  /// Downloads and extracts the specific subtitle variant.
  Future<String?> downloadSubtitle(SubtitleVariant variant) async {
    SubtitleProvider? provider;
    try {
      provider = _providers.firstWhere((p) => p.name == variant.providerName);
    } catch (_) {
      // If variant was generated by an addon, use StremioSubtitleProvider
      try {
        provider = _providers.firstWhere((p) => p is StremioSubtitleProvider);
      } catch (_) {
        provider = _providers.first;
      }
    }
    return provider.download(variant);
  }
}
