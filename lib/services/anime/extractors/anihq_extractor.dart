import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AniHQAnimeResult {
  final String url;
  final String server;
  final String quality;
  final Map<String, String> headers;

  AniHQAnimeResult({
    required this.url,
    required this.server,
    required this.quality,
    required this.headers,
  });
}

/// Pure-Dart AniHQ Stream Extractor for AnimeScraperService.
///
/// Ported 1-to-1 from Vyla AniHQ provider.
/// Resolves VOE streams from anihq.cc.
class AniHQExtractor {
  static final AniHQExtractor instance = AniHQExtractor._internal();
  AniHQExtractor._internal();

  static const _baseUrl = 'https://anihq.cc';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  String _cleanSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _rot13(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        out.writeCharCode(((code - 65 + 13) % 26) + 65);
      } else if (code >= 97 && code <= 122) {
        out.writeCharCode(((code - 97 + 13) % 26) + 97);
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  Future<Map<String, String>?> _extractVoe(http.Client client, String voeUrl) async {
    try {
      var res = await client.get(
        Uri.parse(voeUrl),
        headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
      ).timeout(const Duration(seconds: 8));

      var html = res.body;

      final redirectMatch = RegExp(r'''window\.location\.href\s*=\s*['"](https?://[^'"]+)['"]''').firstMatch(html);
      if (redirectMatch != null && redirectMatch.group(1) != null) {
        res = await client.get(
          Uri.parse(redirectMatch.group(1)!),
          headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
        ).timeout(const Duration(seconds: 8));
        html = res.body;
      }

      final scriptMatch = RegExp(r'''<script type="application/json">\["(.*?)"\]</script>''').firstMatch(html);
      if (scriptMatch == null || scriptMatch.group(1) == null) return null;

      var str = scriptMatch.group(1)!;
      str = _rot13(str);

      const junk = ['@\$', '^^', '~@', '%?', '*~', '!!', '#&'];
      for (final j in junk) {
        str = str.replaceAll(j, '');
      }

      final decoded1 = utf8.decode(base64.decode(base64.normalize(str)));

      final shifted = StringBuffer();
      for (var i = 0; i < decoded1.length; i++) {
        shifted.writeCharCode(decoded1.codeUnitAt(i) - 3);
      }

      final reversed = shifted.toString().split('').reversed.join('');
      final finalJsonStr = utf8.decode(base64.decode(base64.normalize(reversed)));

      final finalData = jsonDecode(finalJsonStr);
      if (finalData is Map && (finalData['file'] != null || finalData['source'] != null)) {
        final streamUrl = (finalData['file'] ?? finalData['source']).toString();
        return {'url': streamUrl};
      }
    } catch (_) {}
    return null;
  }

  Future<List<AniHQAnimeResult>> extract({
    required List<String> titleCandidates,
    required int episodeNumber,
    required String category, // 'sub' or 'dub'
  }) async {
    final results = <AniHQAnimeResult>[];
    final client = http.Client();

    try {
      final isDub = category.toLowerCase() == 'dub';
      final typeSuffix = isDub ? 'english-dubbed' : 'english-subbed';

      for (final title in titleCandidates) {
        final clean = _cleanSlug(title);
        if (clean.isEmpty) continue;

        final directUrl = '$_baseUrl/watch/$clean-episode-$episodeNumber-$typeSuffix/';

        var pageRes = await client.get(
          Uri.parse(directUrl),
          headers: {'User-Agent': _ua},
        ).timeout(const Duration(seconds: 5));

        var html = pageRes.body;

        if (pageRes.statusCode != 200) {
          final sUri = Uri.parse('$_baseUrl/search').replace(queryParameters: {'keyword': title});
          final sRes = await client.get(sUri, headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 6));
          if (sRes.statusCode == 200) {
            final sMatch = RegExp('''href="(https://anihq\\.cc/watch/[^"]+-episode-$episodeNumber-$typeSuffix/)"''', caseSensitive: false).firstMatch(sRes.body);
            if (sMatch != null && sMatch.group(1) != null) {
              final rRes = await client.get(Uri.parse(sMatch.group(1)!), headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 6));
              if (rRes.statusCode == 200) {
                html = rRes.body;
              }
            }
          }
        }

        final voeMatch = RegExp(r'''data-video=["'](https?://[^"']*voe[^"']*)["']''', caseSensitive: false).firstMatch(html) ??
            RegExp(r'''href=["'](https?://[^"']*voe[^"']*)["']''', caseSensitive: false).firstMatch(html);

        if (voeMatch != null && voeMatch.group(1) != null) {
          final voeUrl = voeMatch.group(1)!;
          final voeResult = await _extractVoe(client, voeUrl);
          if (voeResult != null && voeResult['url'] != null) {
            results.add(AniHQAnimeResult(
              url: voeResult['url']!,
              server: 'AniHQ (VOE)',
              quality: '1080p',
              headers: {'User-Agent': _ua, 'Referer': '$_baseUrl/'},
            ));
            break;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AniHQExtractor] error: $e');
    } finally {
      client.close();
    }

    return results;
  }
}
