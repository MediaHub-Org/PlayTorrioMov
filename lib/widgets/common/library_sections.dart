import 'package:flutter/material.dart';

/// The four tabs every hub's Library has, in this order.
///
/// Before this existed each hub picked its own: Watch had My List / Watchlist /
/// History / Downloads, Read had Audiobooks / Books / Manga / History /
/// Downloads, and Listen had Songs / Podcasts / Playlists / Recent /
/// Downloads. Three different shapes, three different tab counts, and the same
/// concept ("what I saved") sitting under three different names — so moving
/// between hubs meant relearning the Library each time.
///
/// A hub with several content types puts them behind a sub-tab inside
/// [saved], the same way Movies/Series and Comics/Manga share one hub section
/// rather than each claiming their own.
enum LibrarySection {
  /// Everything the user deliberately kept: liked, favourited, bookmarked.
  saved('Saved', Icons.favorite_rounded),

  /// Partway through and resumable.
  inProgress('Continue', Icons.play_circle_outline_rounded),

  /// What was played or read, whether or not it was finished.
  history('History', Icons.history_rounded),

  /// Available offline.
  downloads('Downloads', Icons.download_rounded);

  final String label;
  final IconData icon;

  const LibrarySection(this.label, this.icon);
}
