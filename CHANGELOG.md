# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.3.0+17] - 2026-09-08

### Added
- Google Cast support in the video player (Android/iOS) — needs
  real-device verification before it can be considered done
- New HindMoviez scraper site
- Castilian (Spain) vs. Latino (Latin America) Spanish audio-dub
  detection, with their own badges

### Changed
- Video player UI simplified: play/pause and ±10s seek moved to a
  centered overlay; playback speed and aspect ratio consolidated
  behind one Settings button; fullscreen and duplicate Episodes
  buttons removed (both already reachable another way); download
  button removed (still available before playback starts)
- Double-tap now seeks ±10s on the left/right thirds of the video on
  touch platforms, keeping double-tap-to-fullscreen on the middle
  third and on desktop
- Swipe-to-adjust volume/brightness removed on mobile (hardware
  buttons and the OS already do this) — unchanged on desktop

### Fixed
- Arabic anime catalog and search scraping, following the source
  site's changed HTML structure
- Header pill controls (genre/decade/sort filters, search, Live TV's
  icon buttons) now keep a minimum 40×40 tap target even when
  icon-only, instead of shrinking to ~31px

## [1.2.1+16] - 2026-09-06

### Fixed
- The genre/decade/sort/search header on Movies, Series, Anime, and Live
  TV no longer stays pinned to the screen while the page scrolls
  underneath it
- The search icon, and Live TV's whole header, now match the same pill
  design used everywhere else instead of a bare icon and a bespoke
  gradient "glass" look
- Extra empty space above Library's header on mobile
- Tapping the video no longer toggles play/pause — it only shows/hides
  the controls now, same as before that was added; it conflicted with
  double-tap-to-fullscreen and added input latency for no real benefit
  over the dedicated play/pause button
- Gap between the back button and the search field on Search, Catalog,
  and Anime Search
- Row titles ("Popular", "New", ...) no longer sit flush against the
  card row underneath them

## [1.2.0+15] - 2026-09-06

### Added
- Audio dub/language detection and filtering for stream sources, player
  error filtering, and stream health checks — ported from upstream
  `ayman708-UX/PlayTorrioV3` (`ad0e40d`, `6c4d0cf`)
- Stremio catalog-extra and collection addon support — ported from
  upstream `f1f1310`
- Movies and Series split into two full top-level navigation sections
  (previously shared one section behind an internal pill toggle)
- Live TV channels can be favorited (heart on the channel card and in
  the channel detail sheet); favorited channels surface in Library
  under a new Live TV chip
- A Watched toggle chip in Library, alongside Watchlist
- One shared genre-tag pill row (`GenreTagRow`), filter/search pill row
  (`PillFilterHeaderBar`), and back button (`GlassBackButton`) — each
  replacing several hand-rolled, slightly-inconsistent implementations
  across Movies/Series/Anime/Anime-Arabic/Search/Catalog/Discover/IPTV
- A 760×600 minimum desktop window size, so the window can't be shrunk
  into the cramped mobile breakpoint

### Fixed
- The 5-section navigation bar no longer gets hidden behind Details,
  Search, Catalog, Discover, or Settings on tablet/desktop
- The Settings gear icon no longer drifts position between mobile,
  tablet, and desktop, or as the window is resized within a tier
- A catalog fetch failure (e.g. a transient network error) no longer
  silently looks like "no content" — it now surfaces a retryable error
- Subtitle translation language list trimmed from ~110 languages to a
  curated ~34 commonly-used set
- Android back button not popping pages pushed in the hub content area —
  `NestedNavigator` now handles the system back gesture via
  `NavigatorPopHandler`

### Changed
- New app icon, `assets/icon.png`, regenerated across all platforms

### Removed
- Custom Background & Wallpaper and Liquid Glass Setup — both leftover
  from PlayTorrioMod (the app this repo forked from); Liquid Glass
  themed a bottom dock that doesn't exist in this single-hub app, and
  its toggle defaulted off with no way to enable it, so every gated
  code path was already dead
- Library's own local search bar, superseded by the same per-page
  search icon every other page already uses

## [1.1.6+14] - 2026-09-04

### Added
- 30 new torrent/stream scraper sites and 7 new anime extractors, ported
  from upstream `ayman708-UX/PlayTorrioV3` (commit `b0aecf5`) side by side
  with Mov's own existing, non-overlapping set — see
  [ROADMAP.md](docs/ROADMAP.md#upstream-tracking) for the full list and
  what was deliberately left out
- `stream_model.dart` getters (`quality`, `isHDR`, `codec`, `fileSize`,
  `sizeBytes`, `qualityRank`) now memoized instead of recomputing regexes
  on every access; new `seeders` getter
- Android "Direct Surface" player rendering toggle (`player_settings.dart`,
  `video_player_settings_page.dart`), now reachable from Settings

### Fixed
- AniList catalog 403s — request now sends a browser-like User-Agent/
  Origin/Referer and a 15s timeout instead of the old custom UA (ported
  from upstream `cc07994`)
- IPTV player now actually applies `PlayerSettings`' video controller
  configuration instead of bare defaults
- `app_info.dart` fallback version had drifted from `pubspec.yaml`

### Removed
- Dead code: `AnimeDetailsModal`, `MyListPage`, `ProfileRuntime` (a
  hardcoded-always-true guard) and its `profile_async_authorization.dart`
  re-export shim, the unused `flutter_inappwebview` dependency
- Duplicated desktop-Chrome User-Agent literal across 51 scraper/extractor
  files, collapsed into one shared constant

### Cleared
- `AppInfo.channel`'s `(dev)` marker — this release is the first to ship
  as a full, non-prerelease build; see ROADMAP.md § Blocked on a device

## [1.1.5+13] - 2026-09-02

### Added
- Watchlist / Watched / Like three-state buttons for Movies & Series
  (ported from PlayTorrioMod)
- `MediaSessionService` restored — Android/iOS lock-screen, notification and
  Bluetooth media controls for video playback
- Movies & Series browse page: inline type-switch pill, Continue Watching
  slot, Latest Releases row, Series-only upcoming calendar row, optional
  overlay header
- CI: release artifact filenames stamped with the app version

### Fixed
- Video player tap-to-play/pause and the volume-scroll menu conflict
- Library tap-to-details and Saved-tab poster sizing
- Details pages no longer block hub pill / bottom-bar navigation
- Anime hero carousel height brought in line with Live TV's
- Movies & Series hero reads the addon's own `background` field instead of
  cropping the portrait poster
- Grid covers no longer grow unbounded on wide desktop windows (7-column
  cap past 1600px)
- Windows "Unknown hard error" on close — candidate fix ported from
  PlayTorrioMod (`PlaybackCoordinator.disposeForShutdown()`), not yet
  verified close-while-playing on hardware
- Universal play bar suppressed during video playback (each source already
  opens a full-screen `PlayerScreen` with its own transport controls)
- `TorrentStreamService` kills an orphaned `torrserver.exe` before starting

### Changed
- `torrserver_flutter` 0.0.5 → 0.0.6 (PID-file tracking, real `GET
  /shutdown` call replacing the REST-echo orphan probe)
- Library's Saved tab dropped the heart icon and History tab
- Anime's language toggle became a flag+name dropdown
- `LibraryTabs` switched from an underline tab bar to `PillTabRow`

## [1.0.0] - 2026-08-31

### Changed
- Forked from [PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod)
  as a watch-only app: Movies, Series, Anime, Live TV
- Removed Music, Podcasts, Audiobooks, Books, Manga, Comics modules and
  their settings tiles
- Collapsed the three-hub abstraction (`AppHub`, hub-pill nav) into a
  single Media hub
- Renamed package to `playtorriomov`; rebranded platform identity files
  (Android, iOS, Windows, macOS, Linux)
- Dropped `audio_service`/`xml` dependencies no longer needed post-fork

[1.1.5+13]: https://github.com/MediaHub-Org/PlayTorrioMov/releases
[1.0.0]: https://github.com/MediaHub-Org/PlayTorrioMov/commit/cc3a1b3
