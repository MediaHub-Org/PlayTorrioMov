import 'package:flutter/material.dart';

/// The tabs every hub's Library has, in this order.
///
/// Before this existed each hub picked its own: Watch had My List / Watchlist /
/// History / Downloads, Read had Audiobooks / Books / Manga / History /
/// Downloads, and Listen had Songs / Podcasts / Playlists / Recent /
/// Downloads. Three different shapes, three different tab counts, and the same
/// concept ("what I saved") sitting under three different names — so moving
/// between hubs meant relearning the Library each time.
///
/// The first three are the app's three library states, the same ones
/// `LibraryActionsRow` writes on every details page, so a tab here means
/// exactly what the button there meant. That is why there is no longer a
/// generic "Saved" bucket: it needed a generic icon (`inventory_2`) precisely
/// because it held two unlike things, and its own doc comment admitted the
/// heart it wanted "overclaims". Splitting them lets each carry its real name
/// and its real icon.
///
/// Nothing can fall between them: `MyListService` deletes an item once all
/// three flags are false, so everything it stores carries at least one.
///
/// History was dropped 2026-09-02, and Continue on 2026-09-13: Continue
/// rendered `ContinueWatchingService.activeItems`, the identical deduped list
/// the Continue Watching row already shows, so the tab was a second window
/// onto the same thing.
///
/// [downloads] stays despite not being a library *state*. It is the only
/// place an in-app download can be seen or managed — `DownloadService` tracks
/// live progress/pause/resume, and app-private storage is not browsable — so
/// dropping it would strand downloads with no UI at all.
enum LibrarySection {
  /// Favourited. Independent of watch progress, so something can be both
  /// Watched and Liked. The only state Live TV channels can be in.
  liked('Liked', Icons.favorite_rounded),

  /// Kept to watch later. Mutually exclusive with [watched].
  watchlist('Watchlist', Icons.bookmark_added_rounded),

  /// Already seen. Mutually exclusive with [watchlist].
  watched('Watched', Icons.check_circle_rounded),

  /// Available offline.
  downloads('Downloads', Icons.download_rounded);

  final String label;
  final IconData icon;

  const LibrarySection(this.label, this.icon);

  /// Whether this tab filters [MyListService] by a flag, as opposed to
  /// [downloads], which reads a different store entirely.
  bool get isLibraryState => this != LibrarySection.downloads;
}
