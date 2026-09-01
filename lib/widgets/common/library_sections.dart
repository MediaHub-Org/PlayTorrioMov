import 'package:flutter/material.dart';

/// The three tabs every hub's Library has, in this order.
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
///
/// History was dropped 2026-09-02: it and [inProgress] rendered through the
/// same row list and looked like duplicates of each other, and Continue is
/// the more actionable of the two (resume something, not just audit a log).
enum LibrarySection {
  /// Everything the user deliberately kept: liked, favourited, bookmarked.
  ///
  /// A heart overclaims here -- it implies "liked" specifically, but this
  /// bucket also holds Watchlist. `inventory_2` reads as generic storage
  /// instead; the heart lives on the Liked chip inside this tab.
  saved('Saved', Icons.inventory_2_rounded),

  /// Partway through and resumable.
  inProgress('Continue', Icons.play_circle_outline_rounded),

  /// Available offline.
  downloads('Downloads', Icons.download_rounded);

  final String label;
  final IconData icon;

  const LibrarySection(this.label, this.icon);
}
