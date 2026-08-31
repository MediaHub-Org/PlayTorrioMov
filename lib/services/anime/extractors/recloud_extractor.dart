import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ReCloudTrack {
  final String file;
  final String label;
  final String kind; // 'captions', 'subtitles', 'thumbnails'
  final bool isDefault;

  ReCloudTrack({
    required this.file,
    required this.label,
    required this.kind,
    this.isDefault = false,
  });

  factory ReCloudTrack.fromJson(Map<String, dynamic> json) {
    return ReCloudTrack(
      file: json['file']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Unknown',
      kind: json['kind']?.toString() ?? 'subtitles',
      isDefault: json['default'] == true,
    );
  }
}

class ReCloudResult {
  final String url;
  final Map<String, String> headers;
  final List<ReCloudTrack> tracks;
  final Map<String, dynamic>? intro;
  final Map<String, dynamic>? outro;
  final String category; // 'sub' or 'dub'

  ReCloudResult({
    required this.url,
    required this.headers,
    this.tracks = const [],
    this.intro,
    this.outro,
    required this.category,
  });
}

class ReCloudExtractor {
  static final ReCloudExtractor instance = ReCloudExtractor._internal();
  ReCloudExtractor._internal();

  static const String baseUrl = 'https://cdn.4animo.xyz';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _client = http.Client();

  /// Scrapes the video stream and subtitles from ReCloud (4Animo) for an Anilist Anime ID and Episode.
  Future<ReCloudResult?> extract({
    required int anilistId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    try {
      final cat = category.toLowerCase() == 'dub' ? 'dub' : 'sub';
      final embedUrl = '$baseUrl/embed/ani/$anilistId/$episodeNumber/$cat?k=1';

      final embedRes = await _client.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': 'https://google.com/',
        },
      ).timeout(const Duration(seconds: 10));

      if (embedRes.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[ReCloud] Embed request failed: ${embedRes.statusCode}');
        }
        return null;
      }

      final html = embedRes.body;
      final match = RegExp(r'''var\s+sourcesUrl\s*=\s*['"]([^'"]+)['"]''').firstMatch(html);
      if (match == null) {
        if (kDebugMode) {
          debugPrint('[ReCloud] sourcesUrl not found in HTML');
        }
        return null;
      }

      final sourcesPath = match.group(1)!;
      final sourcesUrl = sourcesPath.startsWith('http')
          ? sourcesPath
          : '$baseUrl$sourcesPath';

      final sourcesRes = await _client.get(
        Uri.parse(sourcesUrl),
        headers: {
          'User-Agent': _userAgent,
          'Referer': embedUrl,
          'Accept': 'application/json, text/plain, */*',
        },
      ).timeout(const Duration(seconds: 10));

      if (sourcesRes.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[ReCloud] Sources request failed: ${sourcesRes.statusCode}');
        }
        return null;
      }

      final data = jsonDecode(sourcesRes.body) as Map<String, dynamic>;
      final sources = data['sources'] as List?;
      if (sources == null || sources.isEmpty) {
        return null;
      }

      final firstSource = sources[0] as Map<String, dynamic>;
      final filePath = firstSource['file']?.toString();
      if (filePath == null || filePath.isEmpty) {
        return null;
      }

      final streamUrl = filePath.startsWith('http') ? filePath : '$baseUrl$filePath';

      // Parse subtitle tracks
      final tracks = <ReCloudTrack>[];
      if (data['tracks'] is List) {
        for (final item in data['tracks']) {
          if (item is Map<String, dynamic>) {
            final trackFile = item['file']?.toString() ?? '';
            final fullTrackFile = trackFile.startsWith('http')
                ? trackFile
                : (trackFile.isNotEmpty ? '$baseUrl$trackFile' : '');
            if (fullTrackFile.isNotEmpty) {
              tracks.add(ReCloudTrack(
                file: fullTrackFile,
                label: item['label']?.toString() ?? 'Subtitles',
                kind: item['kind']?.toString() ?? 'subtitles',
                isDefault: item['default'] == true,
              ));
            }
          }
        }
      }

      // Parse intro / outro
      Map<String, dynamic>? intro;
      if (data['intro'] is Map<String, dynamic>) {
        final start = data['intro']['start'];
        final end = data['intro']['end'];
        if (start != null && end != null && (end as num) > (start as num)) {
          intro = {'start': start, 'end': end};
        }
      }

      Map<String, dynamic>? outro;
      if (data['outro'] is Map<String, dynamic>) {
        final start = data['outro']['start'];
        final end = data['outro']['end'];
        if (start != null && end != null && (end as num) > (start as num)) {
          outro = {'start': start, 'end': end};
        }
      }

      return ReCloudResult(
        url: streamUrl,
        headers: {
          'Referer': '$baseUrl/',
          'Origin': baseUrl,
          'User-Agent': _userAgent,
        },
        tracks: tracks,
        intro: intro,
        outro: outro,
        category: cat,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReCloud] Extraction error: $e');
      }
      return null;
    }
  }
}
