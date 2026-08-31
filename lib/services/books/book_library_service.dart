import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'books_service.dart';

/// Persists the user's liked books so they can be shown in the Read hub's
/// Library section. Mirrors [AudiobookLibraryService]'s shape.
class BookLibraryService extends ChangeNotifier {
  static final BookLibraryService instance = BookLibraryService._internal();
  BookLibraryService._internal();

  static const String _likedKey = 'book_liked_v1';

  List<BookResult> _liked = [];
  bool _initialized = false;

  List<BookResult> get liked => _liked;

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
            .map((e) => BookResult.fromJson(e))
            .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('BookLibraryService init error: $e');
    }
  }

  bool isLiked(String editionId) => _liked.any((b) => b.editionId == editionId);

  Future<void> toggleLike(BookResult book) async {
    final idx = _liked.indexWhere((b) => b.editionId == book.editionId);
    if (idx >= 0) {
      _liked.removeAt(idx);
    } else {
      _liked.insert(0, book);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_liked.map((b) => b.toJson()).toList());
    await prefs.setString(_likedKey, json);
  }
}
