import 'package:flutter/material.dart';

/// The top-level content hubs in the app.
enum AppHub {
  media, // Movies, Series, Anime
  books, // Audiobooks, Books, Manga
  music; // Music, Radio, Podcasts (future)

  /// Label shown in nav chrome (TopBar, and the mobile bottom tab bar).
  String get navLabel => switch (this) {
        AppHub.media => 'Watch',
        AppHub.books => 'Read',
        AppHub.music => 'Listen',
      };

  /// Icon shown in nav chrome.
  IconData get navIcon => switch (this) {
        AppHub.media => Icons.movie_filter_rounded,
        AppHub.books => Icons.auto_stories_rounded,
        AppHub.music => Icons.music_note_rounded,
      };
}
