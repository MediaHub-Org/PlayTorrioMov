import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/music/music_track.dart';

class MusicLibraryService extends ChangeNotifier {
  static final MusicLibraryService instance = MusicLibraryService._internal();
  MusicLibraryService._internal();

  static const String _likedTracksKey = 'music_liked_tracks_v3';
  static const String _userPlaylistsKey = 'music_user_playlists_v3';
  static const String _recentTracksKey = 'music_recent_tracks_v3';

  List<MusicTrack> _likedTracks = [];
  List<UserPlaylist> _userPlaylists = [];
  List<MusicTrack> _recentTracks = [];
  bool _initialized = false;

  List<MusicTrack> get likedTracks => _likedTracks;
  List<UserPlaylist> get userPlaylists => _userPlaylists;
  List<MusicTrack> get recentTracks => _recentTracks;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Liked Tracks
      final likedJson = prefs.getString(_likedTracksKey);
      if (likedJson != null) {
        final list = jsonDecode(likedJson) as List<dynamic>;
        _likedTracks = list
            .whereType<Map<String, dynamic>>()
            .map((t) => MusicTrack.fromJson(t))
            .toList();
      }

      // Load User Playlists
      final plJson = prefs.getString(_userPlaylistsKey);
      if (plJson != null) {
        final list = jsonDecode(plJson) as List<dynamic>;
        _userPlaylists = list
            .whereType<Map<String, dynamic>>()
            .map((p) => UserPlaylist.fromJson(p))
            .toList();
      }

      // Load Recent Tracks
      final recentJson = prefs.getString(_recentTracksKey);
      if (recentJson != null) {
        final list = jsonDecode(recentJson) as List<dynamic>;
        _recentTracks = list
            .whereType<Map<String, dynamic>>()
            .map((t) => MusicTrack.fromJson(t))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('MusicLibraryService init error: $e');
    }
  }

  bool isTrackLiked(String trackId) {
    return _likedTracks.any((t) => t.id == trackId);
  }

  Future<void> toggleLikeTrack(MusicTrack track) async {
    final idx = _likedTracks.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      _likedTracks.removeAt(idx);
    } else {
      _likedTracks.insert(0, track);
    }
    notifyListeners();
    await _saveLikedTracks();
  }

  Future<void> addToRecent(MusicTrack track) async {
    _recentTracks.removeWhere((t) => t.id == track.id);
    _recentTracks.insert(0, track);
    if (_recentTracks.length > 50) {
      _recentTracks = _recentTracks.sublist(0, 50);
    }
    notifyListeners();
    await _saveRecentTracks();
  }

  Future<UserPlaylist> createPlaylist(String title) async {
    final pl = UserPlaylist(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'My Playlist' : title.trim(),
      createdAt: DateTime.now().toIso8601String(),
      tracks: [],
    );
    _userPlaylists.insert(0, pl);
    notifyListeners();
    await _saveUserPlaylists();
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _userPlaylists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _saveUserPlaylists();
  }

  Future<void> addTrackToPlaylist(String playlistId, MusicTrack track) async {
    final idx = _userPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final pl = _userPlaylists[idx];
      if (!pl.tracks.any((t) => t.id == track.id)) {
        pl.tracks.add(track);
        notifyListeners();
        await _saveUserPlaylists();
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final idx = _userPlaylists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      _userPlaylists[idx].tracks.removeWhere((t) => t.id == trackId);
      notifyListeners();
      await _saveUserPlaylists();
    }
  }

  Future<void> _saveLikedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_likedTracks.map((t) => t.toJson()).toList());
      await prefs.setString(_likedTracksKey, json);
    } catch (_) {}
  }

  Future<void> _saveUserPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_userPlaylists.map((p) => p.toJson()).toList());
      await prefs.setString(_userPlaylistsKey, json);
    } catch (_) {}
  }

  Future<void> _saveRecentTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_recentTracks.map((t) => t.toJson()).toList());
      await prefs.setString(_recentTracksKey, json);
    } catch (_) {}
  }
}
