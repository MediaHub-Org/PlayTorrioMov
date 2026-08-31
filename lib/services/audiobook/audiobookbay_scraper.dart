import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/audiobook/audiobook_model.dart';
import '../debrid/debrid_service.dart';
import '../stream/torrent_stream_service.dart';

class AudiobookBayScraper {
  static const String _baseUrl = 'https://audiobookbay.lu';

  /// Decodes HTML entities (&amp;, &#8217;, etc.) via a throwaway parse --
  /// avoids pulling in a dedicated unescape package for a handful of tags.
  static String _decodeEntities(String s) => html_parser.parseFragment(s).text ?? s;

  /// AudiobookBay's own listing HTML already carries real genre data in its
  /// "Category: X&nbsp; Y&nbsp;" line -- extracted here instead of trying to
  /// guess genre from title text against an external source.
  static List<String> _parseCategories(String block) {
    final match = RegExp(r'Category:(.*?)<br', dotAll: true).firstMatch(block);
    if (match == null) return const [];
    return match
        .group(1)!
        .split('&nbsp;')
        .map((c) => _decodeEntities(c).trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  static Future<List<Audiobook>> search(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/?s=${Uri.encodeComponent(query)}&cat=undefined%2Cundefined'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      final blocks = res.body.split('<div class="post">');
      final books = <Audiobook>[];

      for (int i = 1; i < blocks.length; i++) {
        final block = blocks[i];

        final RegExp titleExp = RegExp(
          r'<div class="postTitle">\s*<h2>\s*<a href="([^"]+)"[^>]*>([^<]+)</a>',
          caseSensitive: false,
        );
        final titleMatch = titleExp.firstMatch(block);
        if (titleMatch == null) continue;

        var url = titleMatch.group(1)!;
        if (url.startsWith('/')) url = '$_baseUrl$url';

        final RegExp imgExp = RegExp(r'<img[^>]*src="([^"]+)"', caseSensitive: false);
        final imgMatch = imgExp.firstMatch(block);
        var coverImage = imgMatch?.group(1) ?? '';
        if (coverImage.startsWith('/')) coverImage = '$_baseUrl$coverImage';

        books.add(
          Audiobook(
            uuid: 'abb_${url.hashCode}',
            audioBookId: url,
            dynamicSlugId: url,
            title: _decodeEntities(titleMatch.group(2)!.trim()),
            coverImage: coverImage,
            source: 'audiobookbay',
            pageUrl: url,
            categories: _parseCategories(block),
          ),
        );
      }
      return books;
    } catch (e) {
      debugPrint('AudiobookBay search error: $e');
      return [];
    }
  }

  static Future<List<AudiobookChapter>> getChapters(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      final RegExp hashExp = RegExp(
        r'Info Hash:</td>\s*<td[^>]*>\s*([a-fA-F0-9]{40})\s*</td>',
        caseSensitive: false,
      );
      final hashMatch = hashExp.firstMatch(res.body);
      if (hashMatch == null) return [];

      final infoHash = hashMatch.group(1)!;

      final RegExp trackerExp = RegExp(
        r'(?:Announce URL|Tracker):</td>\s*<td[^>]*>\s*([^<]+?)\s*</td>',
        caseSensitive: false,
      );

      final trackers = <String>{};
      for (final m in trackerExp.allMatches(res.body)) {
        final tr = m.group(1)!.trim();
        if (tr.startsWith('http') || tr.startsWith('udp')) {
          trackers.add(tr);
        }
      }

      // Generate base magnet URI
      final magnetUri = StringBuffer('magnet:?xt=urn:btih:$infoHash');
      for (final tr in trackers) {
        magnetUri.write('&tr=${Uri.encodeComponent(tr)}');
      }

      final magnetString = magnetUri.toString();

      // Extract files from HTML page
      final RegExp fileExp = RegExp(
        r"(?:<td>|<li>|<code>|<pre>|class=\x22torrent_files\x22|class=\x22file_list\x22|>|\n|^)\s*([a-zA-Z0-9_\-\.\s\(\)\[\]\,']+\.(?:mp3|m4b|m4a|aac|flac|ogg|opus|wav|wma))",
        caseSensitive: false,
      );

      final chapters = <AudiobookChapter>[];
      final seenFiles = <String>{};
      int fileIndex = 0;

      for (final m in fileExp.allMatches(res.body)) {
        final filename = m.group(1)!.trim();
        if (filename.isEmpty || !seenFiles.add(filename.toLowerCase())) continue;

        chapters.add(
          AudiobookChapter(
            title: filename,
            url: magnetString,
            isTorrent: true,
            torrentFileIndex: fileIndex,
          ),
        );
        fileIndex++;
      }

      // If HTML scraping couldn't find multi-file chapters, auto-expand via Debrid or local Torrent engine
      if (chapters.length <= 1) {
        try {
          final isDebrid = await DebridService().isDebridActiveForStreams();
          if (isDebrid) {
            final debridFiles = await DebridService().resolveMagnet(magnet: magnetString);
            if (debridFiles.isNotEmpty && debridFiles.length > 1) {
              chapters.clear();
              for (int i = 0; i < debridFiles.length; i++) {
                final fname = debridFiles[i].filename;
                chapters.add(
                  AudiobookChapter(
                    title: fname.split('/').last.split('\\').last,
                    url: magnetString,
                    isTorrent: true,
                    torrentFileIndex: i,
                  ),
                );
              }
            }
          } else {
            // Debrid is OFF -> try local torrent engine metadata to extract all audio files
            final torrentInfo = await TorrentStreamService().getTorrentMetadata(magnetString);
            if (torrentInfo != null &&
                torrentInfo.fileStats.isNotEmpty &&
                torrentInfo.fileStats.length > 1) {
              final audioFiles = torrentInfo.fileStats.where((f) {
                final l = f.path.toLowerCase();
                return l.endsWith('.mp3') ||
                    l.endsWith('.m4b') ||
                    l.endsWith('.m4a') ||
                    l.endsWith('.aac') ||
                    l.endsWith('.flac') ||
                    l.endsWith('.ogg') ||
                    l.endsWith('.opus') ||
                    l.endsWith('.wav');
              }).toList();
              if (audioFiles.isNotEmpty) {
                chapters.clear();
                for (final fileInfo in audioFiles) {
                  final name = fileInfo.path.split('/').last.split('\\').last;
                  chapters.add(
                    AudiobookChapter(
                      title: name,
                      url: magnetString,
                      isTorrent: true,
                      torrentFileIndex: fileInfo.id,
                    ),
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('AudiobookBay chapter auto-expansion error: $e');
        }
      }

      if (chapters.isEmpty) {
        chapters.add(
          AudiobookChapter(
            title: 'Full Audiobook Torrent',
            url: magnetString,
            isTorrent: true,
            torrentFileIndex: 0,
          ),
        );
      }

      return chapters;
    } catch (e) {
      debugPrint('AudiobookBay getChapters error: $e');
      return [];
    }
  }
}
