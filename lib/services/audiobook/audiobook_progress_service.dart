import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/audiobook/audiobook_model.dart';

class AudiobookProgress {
  final Audiobook audiobook;
  final List<AudiobookChapter> chapters;
  final int chapterIndex;
  final int positionMs;
  final int durationMs;
  final int lastListenedTimestamp;

  AudiobookProgress({
    required this.audiobook,
    required this.chapters,
    required this.chapterIndex,
    required this.positionMs,
    required this.durationMs,
    required this.lastListenedTimestamp,
  });

  String get key => audiobook.uuid.isNotEmpty ? audiobook.uuid : audiobook.title;

  Map<String, dynamic> toJson() => {
        'audiobook': audiobook.toJson(),
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'chapterIndex': chapterIndex,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'lastListenedTimestamp': lastListenedTimestamp,
      };

  factory AudiobookProgress.fromJson(Map<String, dynamic> json) => AudiobookProgress(
        audiobook: Audiobook.fromJson(json['audiobook']),
        chapters: (json['chapters'] as List).map((c) => AudiobookChapter.fromJson(c)).toList(),
        chapterIndex: json['chapterIndex'] ?? 0,
        positionMs: json['positionMs'] ?? 0,
        durationMs: json['durationMs'] ?? 0,
        lastListenedTimestamp: json['lastListenedTimestamp'] ?? 0,
      );
}

class AudiobookProgressService {
  static final AudiobookProgressService instance = AudiobookProgressService._internal();
  AudiobookProgressService._internal();

  static const String _storageKey = 'audiobook_continue_listening_v1';

  Future<void> saveProgress({
    required Audiobook audiobook,
    required List<AudiobookChapter> chapters,
    required int chapterIndex,
    required Duration position,
    required Duration duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllProgress();

      final key = audiobook.uuid.isNotEmpty ? audiobook.uuid : audiobook.title;
      all.removeWhere((p) => p.key == key);

      final newEntry = AudiobookProgress(
        audiobook: audiobook,
        chapters: chapters,
        chapterIndex: chapterIndex,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        lastListenedTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      all.insert(0, newEntry);

      if (all.length > 20) {
        all.removeRange(20, all.length);
      }

      final rawList = all.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, rawList);
    } catch (e) {
      print('[AudiobookProgressService] Error saving progress: $e');
    }
  }

  Future<List<AudiobookProgress>> getAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final List<AudiobookProgress> result = [];

      for (final str in rawList) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(str);
          result.add(AudiobookProgress.fromJson(decoded));
        } catch (_) {}
      }

      result.sort((a, b) => b.lastListenedTimestamp.compareTo(a.lastListenedTimestamp));
      return result;
    } catch (e) {
      print('[AudiobookProgressService] Error loading progress: $e');
      return [];
    }
  }

  Future<void> removeProgress(String audiobookKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getAllProgress();
      all.removeWhere((p) => p.key == audiobookKey);
      final rawList = all.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, rawList);
    } catch (e) {
      print('[AudiobookProgressService] Error removing progress: $e');
    }
  }
}
