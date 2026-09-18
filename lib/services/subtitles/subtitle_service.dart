
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
      if (language.isEmpty) continue;

      final cleaned = _cleanVariant(variant, movieName, language);
      final key = _variantKey(cleaned, language);
      if (!seenVariants.add(key)) continue;
      grouped.putIfAbsent(language, () => []).add(cleaned);
    }

    // Sort languages alphabetically
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    
    return sortedKeys.map((lang) {
      return SubtitleLanguageGroup(language: lang, variants: grouped[lang]!);
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
    return '$language|$title|${variant.isHearingImpaired}|${variant.isForced}|$translated';
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
