import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class AniDbEpisode {
  final int number;
  final String id;

  AniDbEpisode({
    required this.number,
    required this.id,
  });
}

class AniDbResult {
  final String url;
  final String quality;
  final Map<String, String> headers;
  final String category; // 'sub' or 'dub'

  AniDbResult({
    required this.url,
    this.quality = 'auto',
    required this.headers,
    required this.category,
  });
}

class AniDbExtractor {
  static final AniDbExtractor instance = AniDbExtractor._internal();
  AniDbExtractor._internal();

  static const String baseUrl = 'https://anidb.app';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const Map<String, String> _defaultHeaders = {
    'User-Agent': _userAgent,
    'Referer': '$baseUrl/',
    'Origin': baseUrl,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  final http.Client _client = http.Client();

  // Cache: title/id -> anime slug ID (e.g. 'one-piece-3880')
  final Map<String, String> _slugCache = {};

  // Cache: slug -> list of episodes
  final Map<String, List<AniDbEpisode>> _episodesCache = {};

  /// Fetches URL via curl subprocess on desktop or http.Client on mobile/web.
  Future<String> _fetch(String url) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final curlCmd = Platform.isWindows ? 'curl.exe' : 'curl';
        final result = await Process.run(
          curlCmd,
          [
            '-sL',
            '-A',
            _userAgent,
            '-e',
            '$baseUrl/',
            '--max-time',
            '10',
            url,
          ],
        );
        if (result.exitCode == 0 && (result.stdout as String).isNotEmpty) {
          return result.stdout as String;
        }
      } catch (_) {}
    }

    final response = await _client.get(
      Uri.parse(url),
      headers: _defaultHeaders,
    );
    return response.body;
  }

  /// Searches AniDB for a matching anime and returns its slug identifier.
  Future<String?> mapAnime({
    required List<String> titleCandidates,
  }) async {
    final uniqueTitles = <String>[];
    final seen = <String>{};

    for (final t in titleCandidates) {
      final clean = t.trim().toLowerCase();
      if (clean.isNotEmpty && seen.add(clean)) {
        uniqueTitles.add(t.trim());
      }
    }

    if (uniqueTitles.isEmpty) return null;

    final cacheKey = uniqueTitles.first.toLowerCase();
    if (_slugCache.containsKey(cacheKey)) {
      return _slugCache[cacheKey];
    }

    for (final title in uniqueTitles) {
      try {
        final searchUrl = '$baseUrl/search/suggestions?q=${Uri.encodeComponent(title)}';
        final html = await _fetch(searchUrl);

        if (html.isNotEmpty) {
          final doc = html_parser.parse(html);
          final links = doc.querySelectorAll("a[href*='/anime/']");
          final results = <Map<String, String>>[];

          for (final el in links) {
            final href = el.attributes['href'] ?? '';
            final itemTitle = el.querySelector('p')?.text.trim() ??
                el.attributes['title'] ??
                el.text.trim();

            if (href.isNotEmpty && itemTitle.isNotEmpty) {
              final match = RegExp(r'/anime/([a-z0-9-]+-[0-9]+)', caseSensitive: false)
                  .firstMatch(href);
              if (match != null) {
                results.add({'id': match.group(1)!, 'title': itemTitle});
              }
            }
          }

          // Fallback to browse if suggestions empty
          if (results.isEmpty) {
            final browseUrl = '$baseUrl/browse?q=${Uri.encodeComponent(title)}';
            final browseHtml = await _fetch(browseUrl);

            if (browseHtml.isNotEmpty) {
              final browseDoc = html_parser.parse(browseHtml);
              final browseLinks = browseDoc.querySelectorAll("a[href*='/anime/']");

              for (final el in browseLinks) {
                final href = el.attributes['href'] ?? '';
                final itemTitle = el.attributes['title'] ??
                    el.querySelector('h3, p, span')?.text.trim() ??
                    el.text.trim();

                if (href.isNotEmpty && itemTitle.isNotEmpty) {
                  final match = RegExp(r'/anime/([a-z0-9-]+-[0-9]+)', caseSensitive: false)
                      .firstMatch(href);
                  if (match != null) {
                    results.add({'id': match.group(1)!, 'title': itemTitle});
                  }
                }
              }
            }
          }

          if (results.isNotEmpty) {
            final normalizedSearch = title.toLowerCase().trim();
            // Check exact match
            final exactMatch = results.firstWhere(
              (r) => (r['title'] ?? '').toLowerCase().trim() == normalizedSearch,
              orElse: () => results.first,
            );

            final slug = exactMatch['id']!;
            _slugCache[cacheKey] = slug;
            return slug;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AniDb] Error searching for $title: $e');
      }
    }

    return null;
  }

  /// Gets episode list for an AniDB anime slug.
  Future<List<AniDbEpisode>?> getEpisodes(String providerId) async {
    if (providerId.isEmpty) return null;
    if (_episodesCache.containsKey(providerId)) {
      return _episodesCache[providerId];
    }

    try {
      final numericId = providerId.split('-').last;
      if (numericId.isEmpty) return null;

      final episodesUrl = '$baseUrl/api/frontend/anime/$numericId/episodes';
      final jsonStr = await _fetch(episodesUrl);

      if (jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        if (data is Map && data['episodes'] is List) {
          final list = (data['episodes'] as List).map((ep) {
            final numVal = ep['number'];
            final num = numVal is int ? numVal : int.tryParse(numVal.toString()) ?? 1;
            return AniDbEpisode(
              number: num,
              id: ep['id'].toString(),
            );
          }).toList();

          list.sort((a, b) => a.number.compareTo(b.number));
          _episodesCache[providerId] = list;
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AniDb] Error fetching episodes: $e');
    }

    return null;
  }

  /// Scrapes the video stream for an episode in SUB or DUB category.
  Future<AniDbResult?> scrapeEpisodeStream({
    required String providerId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    try {
      final episodes = await getEpisodes(providerId);
      if (episodes == null || episodes.isEmpty) return null;

      final ep = episodes.firstWhere(
        (e) => e.number == episodeNumber,
        orElse: () => episodes.first,
      );

      if (ep.number != episodeNumber && episodes.any((e) => e.number == episodeNumber)) {
        return null;
      }

      final languagesUrl = '$baseUrl/api/frontend/episode/${ep.id}/languages';
      final langJsonStr = await _fetch(languagesUrl);
      if (langJsonStr.isEmpty) return null;

      final langData = jsonDecode(langJsonStr);
      if (langData is! Map || langData['languages'] is! List) return null;

      final languages = (langData['languages'] as List).cast<Map<String, dynamic>>();
      if (languages.isEmpty) return null;

      Map<String, dynamic>? targetLang;
      if (category.toLowerCase() == 'dub') {
        targetLang = languages.firstWhere(
          (l) =>
              l['code'] == 'eng' ||
              (l['name']?.toString().toLowerCase().contains('english') == true) ||
              (l['name']?.toString().toLowerCase().contains('dub') == true),
          orElse: () => <String, dynamic>{},
        );
      } else {
        targetLang = languages.firstWhere(
          (l) =>
              l['code'] == 'jpn' ||
              (l['name']?.toString().toLowerCase().contains('japanese') == true) ||
              (l['name']?.toString().toLowerCase().contains('sub') == true),
          orElse: () => <String, dynamic>{},
        );
      }

      if (targetLang.isEmpty) {
        targetLang = languages.first;
      }

      final embedUrl = targetLang['embed_url']?.toString();
      if (embedUrl == null || embedUrl.isEmpty) return null;

      final embedHtml = await _fetch(embedUrl);
      if (embedHtml.isEmpty) return null;

      final fileMatch =
          RegExp(r'''file:\s*['"]([^'"]+)['"]''').firstMatch(embedHtml);
      if (fileMatch == null || fileMatch.group(1) == null) return null;

      final masterUrl = fileMatch.group(1)!;
      return AniDbResult(
        url: masterUrl,
        quality: 'auto',
        category: category.toLowerCase(),
        headers: {
          'Referer': '$baseUrl/',
          'Origin': baseUrl,
          'User-Agent': _userAgent,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AniDb] Scrape error: $e');
      return null;
    }
  }

  /// Convenience extractor integrating title mapping, episode lookup, and scraping.
  Future<AniDbResult?> extract({
    required List<String> titleCandidates,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    final slug = await mapAnime(titleCandidates: titleCandidates);
    if (slug == null) return null;
    return scrapeEpisodeStream(
      providerId: slug,
      episodeNumber: episodeNumber,
      category: category,
    );
  }
}
