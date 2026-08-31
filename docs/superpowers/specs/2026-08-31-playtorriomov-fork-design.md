# PlayTorrioMov fork — design spec

Date: 2026-08-31

## Goal

PlayTorrioMod carries three content domains: Media (movies/series/anime/live-TV),
Books (books/audiobooks/manga/comics), Music (music/podcasts/radio). Music and
Books are better served by dedicated apps (Spotify, YouTube Music, WAVE-style
libtorrent music clients; Kindle/Play Books/Calibre/e-readers for reading) —
this app's value is the Media domain. PlayTorrioMod keeps all three domains and
continues its own separate polish track (out of scope here). A new sibling app,
**PlayTorrioMov**, is forked from it containing Media only, with simpler nav
since it no longer needs to fit three symmetric hubs side by side.

## Location & fork mechanics

- Filesystem copy of `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMod`
  into `D:\Workspaces\David7ce-user\MediaHub-Org\PlayTorrioMov` (not a git
  clone — fresh history, first commit "fork from PlayTorrioMod").
- Rebrand: `lib/app_info.dart` `AppInfo.name` → `PlayTorrioMov` (tagline
  author's call at implementation time). Android `applicationId` and Kotlin
  package `com.mediahub.playtorriomod` → `com.mediahub.playtorriomov`
  (including the Kotlin source directory move). iOS bundle id. Windows
  installer id in `installer/windows/setup.iss`. README.

## Module removal

Delete entirely (full file lists gathered via repo inventory — implementer
re-greps at execution time since file lists drift):

- **Music**: `lib/models/music/`, `lib/services/music/`, `lib/pages/music/`,
  `lib/pages/hub/music_hub.dart`, `lib/pages/settings/appearance/music_player_studio_page.dart`,
  `lib/widgets/music/`, `test/music_smoke_test.dart`
- **Podcasts**: `lib/services/podcast/`, `lib/pages/podcast/`
- **Audiobooks**: `lib/models/audiobook/`, `lib/services/audiobook/`,
  `lib/pages/audiobooks/`, `lib/pages/settings/appearance/audiobook_player_studio_page.dart`,
  `lib/widgets/audiobook/`, `test/audiobookbay_scraper_test.dart`
- **Books**: `lib/models/book/`, `lib/services/books/`, `lib/pages/read/`,
  `lib/pages/collection/books_library_page.dart`, `test/pages/book_reader_zip_slip_test.dart`
- **Manga**: `lib/models/manga/`, `lib/services/manga/`, `lib/pages/manga/`,
  `lib/pages/settings/appearance/manga_settings_page.dart`, `lib/widgets/manga/`
- **Comics**: `lib/pages/catalog/comics_page.dart` (its `.cbz`/`.cbr` flag in
  `book_result.dart` goes with Books)
- **Hub wrapper**: `lib/pages/hub/books_hub.dart`

Surgically edit (mixed keep/remove content, listed with what to strip):

- `lib/main.dart` — drop bootstrap of Audiobook/Reader/Manga/Music settings
  and services from the startup `Future.wait`
- `lib/pages/settings/appearance_settings_page.dart` — drop tiles for the
  three removed player-studio/settings pages
- `lib/pages/settings/about_settings_page.dart` — `_HubList` and its copy
  drop the Books/Music hub descriptions
- `lib/services/discord/discord_rpc_service.dart` — drop
  `setListeningAudiobook`/`setReadingBook`/`setReadingManga`/`setListeningMusic`
  and their call sites
- `lib/services/download/download_service.dart` — drop the `isAudiobook`
  extension branch
- `lib/widgets/common/universal_play_bar.dart` — drop `music`/`audiobook`/
  `podcast` source branches and the stale doc comment
- `lib/services/playback_coordinator.dart` — drop music-only like/artist-link
  logic and audiobook mentions in docs/params
- `lib/services/media_session/media_session_service.dart` — once
  Music/Podcasts/Audiobooks are gone this file has no remaining caller;
  delete it wholesale (confirm nothing else backs a now-playing notification
  through it first)
- `lib/widgets/common/like_button.dart` — generic component, just update the
  stale doc comment listing removed modules

pubspec.yaml: drop `audio_service` (only consumer was `media_session_service.dart`)
and `xml` (only consumers were podcast RSS parsing and EPUB unzipping — IPTV's
M3U/EPG parsing doesn't use it). Keep `archive` — also used by the movie/series
subtitle-zip extractor. Rewrite the package description string. Drop the
`dart_discord_presence` unused-PDF/MOBI/FB2-packages comment (moot once Books
is gone).

Android manifest: drop `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission, the
`AudioService` `<service>` block, the `MediaButtonReceiver` `<receiver>` block.
Verify `FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_DATA_SYNC`/`POST_NOTIFICATIONS`
aren't also needed by the download/update-notification path before touching
those. iOS: drop `UIBackgroundModes` → `audio` entry and its usage-description
string, after confirming Live TV doesn't rely on background audio-only
playback.

## Navigation — collapse the hub abstraction, don't just prune it

PlayTorrioMod's `AppHub` enum (media/books/music) exists because three hubs
each need a symmetric 4-section shape for the mobile pill row / desktop chip
row. PlayTorrioMov only has one hub, so the abstraction is dead weight, not a
subset to keep: per the ladder, delete the now-single-branch machinery rather
than leave a 1-item enum/switch standing.

- `HubPage` renders `MediaHub`'s content directly — no `IndexedStack`, no hub
  switch.
- `HubController` drops the hub dimension entirely (`_currentHub`,
  `setHub`, the `AppHub`-keyed switches in `currentSections`/
  `currentSectionId`/`setCurrentSection`); keeps only section state
  (`_mediaSection`, `_watchType`, their getters/setters).
- `lib/utils/app_hub.dart` (`AppHub` enum) deleted.
- `lib/widgets/common/adaptive_nav_shell.dart`'s `_MobileHubPills` deleted —
  nothing to switch between.
- `lib/widgets/common/top_bar.dart` — same trim if it independently
  enumerates `AppHub` (verify at implementation time; not confirmed in this
  pass).

Final top-level sections, renamed from today's Media-hub set:

| id | label | content |
|---|---|---|
| `watch` | **Movies & Series** | today's `Movies/Series` pill catalog, unchanged — chosen over "Home" because every sibling tab names its content type and "Home" would be the only one that doesn't, and it wrongly implies a mixed-recommendation dashboard this tab isn't |
| `anime` | Anime | unchanged — kept as its own top-level tab rather than folded into a Movies/Series/Anime 3-way pill, because Anime is a genuinely different catalog (own scraper, own metadata shape, own detail page, own genre taxonomy) and folding it in would misrepresent it as "just a movie filter" |
| `iptv` | Live TV | unchanged |
| `collection` | Library | unchanged |

Search stays an icon (`page_search_button.dart` → `search_page.dart` overlay),
not promoted to a fifth tab: it's an action reachable from anywhere at zero
nav-slot cost, not a place to browse, and PlayTorrioMod's own mobile-polish
goal argues against spending a scarce tab slot on it. (Decided against the
`Home / Search / Live TV / Library` alternative considered during design.)

Since only one hub remains, the "every hub has exactly four sections" mobile
constraint (`hub_controller.dart`'s doc comment) no longer applies for its
original reason, but four is still kept here because it's the right count on
its own merits for this content — not preserved by inertia.

## Verification

- `flutter analyze` clean
- `flutter test` (after removing the two module-specific test files listed
  above)
- Manual launch on Windows (this dev machine): confirm Movies & Series,
  Anime, Live TV, Library all open, and there's no dead hub-pill UI left
  over from the collapsed `AppHub` abstraction

## Ongoing maintenance after the fork

This is not a one-time split. PlayTorrioMod stays the primary development
repo (it also tracks its own upstream). Media-domain changes (movies/series/
anime/live-TV/library — the code this fork copies) keep landing in
PlayTorrioMod first; PlayTorrioMov receives them adapted/mirrored over,
manually, since the two nav layers diverge (three-hub abstraction vs the
collapsed single-hub one above). Books/Music-only changes in PlayTorrioMod
have nothing to port. No automated sync tooling is being built for this —
out of scope for this spec, revisit if manual porting becomes painful.

## Explicitly out of scope

The PlayTorrioMod-side UI wishlist (Library simplify, settings/section mobile
layout, general UI polish, welcome content on search-only pages, A-Z sort
removal on Movies/Series, grouped-page naming, Music nav rework with
genre-as-pill/Radio) is separate work in the original repo, not touched by
this fork. Each item there gets its own bounded design when picked up.
