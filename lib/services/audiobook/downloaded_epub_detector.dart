import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../books/book_download_service.dart';
import 'epub_cover.dart';

/// Item representing a detected local EPUB file downloaded from the Books section or stored on disk.
class DetectedEpubBook {
  final String filePath;
  final String fileName;
  final String title;
  final int fileSizeBytes;
  final String? coverPath;
  final int? wordCount;

  DetectedEpubBook({
    required this.filePath,
    required this.fileName,
    required this.title,
    required this.fileSizeBytes,
    this.coverPath,
    this.wordCount,
  });
}

class DownloadedEpubDetector {
  static Future<List<DetectedEpubBook>> scanDownloadedEpubs() async {
    final results = <DetectedEpubBook>[];

    try {
      final booksDir = await BookDownloadService.instance.getBooksDirectory();
      if (!await booksDir.exists()) return results;

      final entities = booksDir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
          try {
            final len = await entity.length();
            if (len < 500) continue; // Skip corrupted / empty files

            final fileName = p.basename(entity.path);
            var title = p.basenameWithoutExtension(entity.path);
            title = title.replaceAll(RegExp(r'[._]'), ' ').trim();

            // Extract cover if available
            String? coverPath;
            try {
              final bytes = await entity.readAsBytes();
              final safeName = 'book_${fileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
              coverPath = await EpubCover.extractAndSave(
                epubBytes: bytes,
                saveAsName: safeName,
              );
            } catch (_) {}

            results.add(DetectedEpubBook(
              filePath: entity.path,
              fileName: fileName,
              title: title,
              fileSizeBytes: len,
              coverPath: coverPath,
            ));
          } catch (e) {
            debugPrint('[DownloadedEpubDetector] Error processing ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[DownloadedEpubDetector] scan error: $e');
    }

    return results;
  }
}
