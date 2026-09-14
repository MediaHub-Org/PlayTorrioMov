import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'subtitle_payload.dart';
import 'package:flutter/foundation.dart';

class SubtitleExtractor {
  /// Downloads a file (ZIP, GZ, SRT, VTT, ASS) and extracts/cleans the subtitle on the fly.
  /// Converts legacy encodings (Windows-1256, CP1252, Latin-1, UTF-16) to standard UTF-8.
  /// Returns the absolute path to the local .srt, .vtt, or .ass file.
  static Future<String?> downloadAndExtract(
    String url, {
    Map<String, String>? headers,
    required String providerName,
  }) async {
    try {
      final reqHeaders = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
      };
      if (headers != null) {
        reqHeaders.addAll(headers);
      }
      if (!reqHeaders.containsKey('Referer') && url.contains('subdl.com')) {
        reqHeaders['Referer'] = 'https://subdl.com/';
      }

      final response = await http
          .get(Uri.parse(url), headers: reqHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[SubtitleExtractor] Download failed for $url (Status: ${response.statusCode})');
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      // Determine temp directory reliably
      String tempDirPath;
      try {
        final dir = await getTemporaryDirectory();
        tempDirPath = dir.path;
      } catch (_) {
        tempDirPath = Directory.systemTemp.path;
      }

      final targetDir = Directory('$tempDirPath/subtitles/$providerName');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}';

      // What the bytes actually are -- zip, gzip or bare, and in which
      // encoding -- is decided by SubtitlePayload, which needs neither the
      // network nor the disk and is tested without them.
      final payload = SubtitlePayload.decode(bytes, url: url);
      final utf8Bytes = utf8.encode(payload.text);

      final savePath = '${targetDir.path}/$fileName.${payload.extension}';
      final localFile = File(savePath);
      await localFile.writeAsBytes(utf8Bytes, flush: true);

      debugPrint('[SubtitleExtractor SUCCESS] Extracted subtitle to $savePath (${utf8Bytes.length} bytes)');
      return savePath;
    } catch (e, st) {
      debugPrint('[SubtitleExtractor ERROR] Subtitle extraction error ($providerName): $e\n$st');
    }
    return null;
  }
}
