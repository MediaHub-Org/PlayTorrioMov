import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'podcast_service.dart';

/// Persists the user's liked/subscribed podcasts so they can be shown in the
/// Listen hub's Library section. Mirrors [AudiobookLibraryService]'s shape.
class PodcastLibraryService extends ChangeNotifier {
  static final PodcastLibraryService instance = PodcastLibraryService._internal();
  PodcastLibraryService._internal();

  static const String _likedKey = 'podcast_liked_v1';

  List<PodcastResult> _liked = [];
  bool _initialized = false;

  List<PodcastResult> get liked => _liked;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_likedKey);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _liked = list
            .whereType<Map<String, dynamic>>()
            .map((e) => PodcastResult.fromJson(e))
            .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('PodcastLibraryService init error: $e');
    }
  }

  bool isLiked(String id) => _liked.any((p) => p.id == id);

  Future<void> toggleLike(PodcastResult podcast) async {
    final idx = _liked.indexWhere((p) => p.id == podcast.id);
    if (idx >= 0) {
      _liked.removeAt(idx);
    } else {
      _liked.insert(0, podcast);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_liked.map((p) => p.toJson()).toList());
    await prefs.setString(_likedKey, json);
  }
}
