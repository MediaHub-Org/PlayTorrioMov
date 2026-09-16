import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// The Library's three tabs, in this order.
///
/// Before this existed each hub picked its own: Watch had My List / Watchlist
/// / History / Downloads, Read had Audiobooks / Books / Manga / History /
/// Downloads, and Listen had Songs / Podcasts / Playlists / Recent /
/// Downloads. Three different shapes, three different tab counts, and the same
/// concept ("what I saved") under three different names.
///
/// It then spent a while as the app's four library *states* -- Liked,
/// Watchlist, Watched, Downloads -- one tab each. That stopped scaling the
/// moment collections arrived: a user with six collections would have had ten
/// tabs, and a pill row that scrolls is a pill row nobody reads to the end of.
///
/// So the states moved down a level. [collections] holds them as cards next to
/// the user's own collections -- the arrangement Spotify and YouTube Music use,
/// where "Liked Songs" is pinned first and looks like the playlists beside it
/// -- and the tab bar is left holding the three genuinely different things you
/// can want from a Library: what you saved, what you were in the middle of,
/// and what is on the device.
enum LibrarySection {
  /// Everything saved, as square cards: the three built-in shelves first,
  /// then the user's collections. See [LibraryShelf].
  collections('Collections', Icons.grid_view_rounded),

  /// What is part-watched. Back as a tab after being dropped on 2026-09-13
  /// for duplicating the home row: with the states gone from the tab bar
  /// there is room for it, and the Library is where someone looks for
  /// "what was I watching?" when the home row has already scrolled past it.
  continueWatching('Continue', Icons.play_circle_outline_rounded),

  /// Available offline. Not a library *state*: it reads `DownloadService`,
  /// and it is the only place an in-app download can be seen or managed --
  /// app-private storage is not browsable -- so dropping it would strand
  /// downloads with no UI at all.
  downloads('Downloads', Icons.download_rounded);

  final String label;
  final IconData icon;

  const LibrarySection(this.label, this.icon);

  /// The label to render, translated (#68). The enum is `const`, so it cannot
  /// hold a context-dependent string itself -- this resolves it at the point
  /// of display instead.
  ///
  /// Goes through `context.l10n`, which falls back to English when no
  /// [AppLocalizations] delegate is in scope -- several existing widget tests
  /// pump these in a bare `MaterialApp` with no delegates registered. See
  /// `lib/l10n/l10n.dart` for why that fallback exists.
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      LibrarySection.collections => l10n.libraryTabCollections,
      LibrarySection.continueWatching => l10n.libraryTabContinue,
      LibrarySection.downloads => l10n.libraryTabDownloads,
    };
  }
}

/// The built-in shelves, pinned as cards before the user's own collections.
///
/// These are the three states `LibraryActionsRow` writes on every details
/// page, so a card here means exactly what the button there meant. Nothing can
/// fall between them: `MyListService` deletes an item once all three flags are
/// false, so everything it stores carries at least one.
///
/// They are *states*, not collections -- one flat list, one state per title,
/// [watchlist] and [watched] mutually exclusive, all three synced to Trakt and
/// Simkl. A collection has none of those constraints. They share a card shape
/// because they are both "a list you can open", and nothing more.
enum LibraryShelf {
  /// Favourited. Independent of watch progress, so something can be both
  /// watched and liked. The only state a Live TV channel can be in.
  liked(
    'Liked',
    Icons.favorite_rounded,
    Color(0xFFE5395A),
    'Nothing liked yet',
    'Tap the heart on anything and it lands here.',
  ),

  /// Kept to watch later. Mutually exclusive with [watched].
  watchlist(
    'Watchlist',
    Icons.bookmark_added_rounded,
    Color(0xFF4E8CFF),
    'Nothing on your watchlist',
    'Add something to watch later and it lands here.',
  ),

  /// Already seen. Mutually exclusive with [watchlist].
  watched(
    'Watched',
    Icons.check_circle_rounded,
    Color(0xFF00D294),
    'Nothing marked watched yet',
    'Mark something watched and it lands here.',
  );

  final String label;
  final IconData icon;

  /// Tints the card. Fixed rather than themed so the three stay told apart at
  /// a glance in a grid -- and [watched] is the same green the details page's
  /// own Watched button uses.
  final Color color;

  final String emptyTitle;
  final String emptySubtitle;

  const LibraryShelf(
    this.label,
    this.icon,
    this.color,
    this.emptyTitle,
    this.emptySubtitle,
  );

  /// The card's label, translated (#68). Same fallback contract as
  /// [LibrarySection.localizedLabel].
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      LibraryShelf.liked => l10n.libraryShelfLiked,
      LibraryShelf.watchlist => l10n.libraryShelfWatchlist,
      LibraryShelf.watched => l10n.libraryShelfWatched,
    };
  }

  /// The empty-state heading, translated (#68).
  String localizedEmptyTitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      LibraryShelf.liked => l10n.libraryEmptyLikedTitle,
      LibraryShelf.watchlist => l10n.libraryEmptyWatchlistTitle,
      LibraryShelf.watched => l10n.libraryEmptyWatchedTitle,
    };
  }

  /// The empty-state line beneath the heading, translated (#68).
  String localizedEmptySubtitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      LibraryShelf.liked => l10n.libraryEmptyLikedSubtitle,
      LibraryShelf.watchlist => l10n.libraryEmptyWatchlistSubtitle,
      LibraryShelf.watched => l10n.libraryEmptyWatchedSubtitle,
    };
  }
}
