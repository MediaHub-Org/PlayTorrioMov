import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class MegaPlayTrack {
  final String file;
  final String label;
  final String kind; // 'captions', 'subtitles', 'thumbnails'
  final bool isDefault;

  MegaPlayTrack({
    required this.file,
    required this.label,
    required this.kind,
    this.isDefault = false,
  });

  factory MegaPlayTrack.fromJson(Map<String, dynamic> json) {
    return MegaPlayTrack(
      file: json['file']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Unknown',
      kind: json['kind']?.toString() ?? 'subtitles',
      isDefault: json['default'] == true,
    );
  }
}

class MegaPlayResult {
  final String url;
  final Map<String, String> headers;
  final List<MegaPlayTrack> tracks;
  final Map<String, dynamic>? intro;
  final Map<String, dynamic>? outro;
  final String category; // 'sub' or 'dub'

  MegaPlayResult({
    required this.url,
    required this.headers,
    this.tracks = const [],
    this.intro,
    this.outro,
    required this.category,
  });
}

class MegaPlayExtractor {
  static final MegaPlayExtractor instance = MegaPlayExtractor._internal();
  MegaPlayExtractor._internal();

  static const String baseUrl = 'https://megaplay.buzz';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  static const Map<String, String> _commonHeaders = {
    'authority': 'megaplay.buzz',
    'accept-language': 'en-US,en;q=0.9',
    'cache-control': 'no-cache',
    'pragma': 'no-cache',
    'sec-ch-ua': '"Brave";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-gpc': '1',
    'cookie': 'SITE_TOTAL_ID=ce655f0eea754f2888ea98ded373e3b5',
    'user-agent': _userAgent,
  };

  final http.Client _client = http.Client();

  /// Scrapes the video stream and subtitles for an Anilist Anime ID and Episode.
  Future<MegaPlayResult?> extract({
    required int anilistId,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    try {
      final cat = category.toLowerCase() == 'dub' ? 'dub' : 'sub';
      final playerUrl = '$baseUrl/stream/ani/$anilistId/$episodeNumber/$cat';

      final playerHeaders = {
        ..._commonHeaders,
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'referer': 'https://megaplay.buzz/api',
        'sec-fetch-dest': 'iframe',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
      };

      final playerResponse = await _client.get(
        Uri.parse(playerUrl),
        headers: playerHeaders,
      );

      if (playerResponse.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[MegaPlay] Failed player HTML: ${playerResponse.statusCode}');
        }
        return null;
      }

      var html = playerResponse.body;
      var doc = html_parser.parse(html);

      var dataId = doc.getElementById('megaplay-player')?.attributes['data-id'] ??
          doc.querySelector('[data-id]')?.attributes['data-id'];
      var currentDomain = baseUrl;
      var currentReferer = playerUrl;

      if (dataId == null || dataId.isEmpty) {
        final iframeSrc = doc.querySelector('iframe')?.attributes['src'];
        if (iframeSrc != null && iframeSrc.isNotEmpty) {
          final iframeUri = Uri.parse(
            iframeSrc.startsWith('//')
                ? 'https:$iframeSrc'
                : (iframeSrc.startsWith('http')
                    ? iframeSrc
                    : '$baseUrl$iframeSrc'),
          );
          currentDomain = '${iframeUri.scheme}://${iframeUri.host}';
          currentReferer = iframeUri.toString();

          final iframeHeaders = {
            ..._commonHeaders,
            'authority': iframeUri.host,
            'accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'referer': playerUrl,
            'sec-fetch-dest': 'iframe',
            'sec-fetch-mode': 'navigate',
            'sec-fetch-site': 'cross-site',
            'upgrade-insecure-requests': '1',
          };

          final iframeRes = await _client.get(iframeUri, headers: iframeHeaders);
          if (iframeRes.statusCode == 200) {
            html = iframeRes.body;
            doc = html_parser.parse(html);
            dataId = doc.querySelector('[data-id]')?.attributes['data-id'];
            if (dataId == null || dataId.isEmpty) {
              final match = RegExp(r'''data-id="(\d+)"''').firstMatch(html);
              dataId = match?.group(1);
            }
          }
        }
      }

      if (dataId == null || dataId.isEmpty) {
        if (kDebugMode) debugPrint('[MegaPlay] Could not extract data-id');
        return null;
      }

      final sourcesUrl =
          '$currentDomain/stream/getSources?id=$dataId&id=$dataId';
      final sourcesHeaders = {
        ..._commonHeaders,
        'authority': Uri.parse(currentDomain).host,
        'accept': 'application/json, text/javascript, */*; q=0.01',
        'referer': currentReferer,
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'x-requested-with': 'XMLHttpRequest',
      };

      final sourcesRes = await _client.get(
        Uri.parse(sourcesUrl),
        headers: sourcesHeaders,
      );

      if (sourcesRes.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[MegaPlay] Failed sources response: ${sourcesRes.statusCode}');
        }
        return null;
      }

      final sourcesJson = jsonDecode(sourcesRes.body);
      if (sourcesJson is! Map ||
          sourcesJson['sources'] is! Map ||
          sourcesJson['sources']['file'] == null) {
        if (kDebugMode) debugPrint('[MegaPlay] No file in sources JSON');
        return null;
      }

      final streamFileUrl = sourcesJson['sources']['file'].toString();
      final streamHeaders = {
        'Referer': '$currentDomain/',
        'Origin': currentDomain,
        'User-Agent': _userAgent,
        'Cookie': _commonHeaders['cookie']!,
      };

      final tracks = <MegaPlayTrack>[];
      if (sourcesJson['tracks'] is List) {
        for (final t in sourcesJson['tracks']) {
          if (t is Map<String, dynamic>) {
            tracks.add(MegaPlayTrack.fromJson(t));
          }
        }
      }

      Map<String, dynamic>? intro;
      if (sourcesJson['intro'] is Map) {
        intro = Map<String, dynamic>.from(sourcesJson['intro']);
      }

      Map<String, dynamic>? outro;
      if (sourcesJson['outro'] is Map) {
        outro = Map<String, dynamic>.from(sourcesJson['outro']);
      }

      return MegaPlayResult(
        url: streamFileUrl,
        headers: streamHeaders,
        tracks: tracks,
        intro: intro,
        outro: outro,
        category: cat,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MegaPlay] Scrape error: $e');
      return null;
    }
  }
}
