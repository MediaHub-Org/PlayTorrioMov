import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book/reading_progress.dart';

class ContinueReadingService {
  static const _storageKey = 'continue_reading_sessions_v1';

  static final ValueNotifier<List<ReadingProgress>> activeItems =
      ValueNotifier<List<ReadingProgress>>([]);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final list = jsonDecode(rawJson) as List<dynamic>;
        final rawItems = list
            .whereType<Map<String, dynamic>>()
            .map((j) => ReadingProgress.fromJson(j))
            .where((item) => item.md5.isNotEmpty)
            .toList();

        rawItems.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));

        // Deduplicate by book md5
        final deduped = <String, ReadingProgress>{};
        for (final item in rawItems) {
          if (!deduped.containsKey(item.md5)) {
            deduped[item.md5] = item;
          }
        }

        final items = deduped.values.toList();
        items.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
        activeItems.value = items;
      }
    } catch (e) {
      debugPrint('[ContinueReadingService] Init error: $e');
    }
  }

  static Future<void> saveProgress(ReadingProgress progress) async {
    try {
      final current = List<ReadingProgress>.from(activeItems.value);
      current.removeWhere((i) => i.md5 == progress.md5);
      current.insert(0, progress);

      // Keep top 50 recent books
      if (current.length > 50) {
        current.removeRange(50, current.length);
      }

      activeItems.value = current;

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(current.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[ContinueReadingService] Save progress error: $e');
    }
  }

  static ReadingProgress? getProgress(String md5) {
    try {
      return activeItems.value.firstWhere((i) => i.md5 == md5);
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeProgress(String md5) async {
    try {
      final current = List<ReadingProgress>.from(activeItems.value);
      current.removeWhere((i) => i.md5 == md5);
      activeItems.value = current;

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(current.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[ContinueReadingService] Remove progress error: $e');
    }
  }
}
