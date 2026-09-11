# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.5.4+23] - 2026-09-11

### Fixed
- Settings' desktop/tablet layout showed categories as a 2-3 column grid;
  every category is now stacked one per row on every screen size, like
  mobile already was

## [1.5.3+22] - 2026-09-10

### Fixed
- The Linux window's title bar used the stock Flutter template's default: a
  native `GtkHeaderBar` with a hardcoded title, styled by whatever GTK
  theme happens to be available — inside a Flatpak sandbox, not
  necessarily the host's own theme, and unrelated to the app's own dark
  UI either way. It was also taller than a plain title bar. Now always
  renders a plain title, letting the window manager/compositor draw its
  own (themed, slimmer) decoration — confirmed by building and actually
  running the window on this machine

## [1.5.2+21] - 2026-09-10

### Fixed
- The Flatpak still didn't start after 1.5.1's libsecret fix: "Failed to
  create AOT data / Invalid ELF path specified". Flutter's Linux embedder
  resolves `data/` and `lib/libapp.so` relative to `/proc/self/exe`'s own
  directory (confirmed straight from the engine source, and from the
  executable's own `RUNPATH: $ORIGIN/lib`) — the manifest installed them
  as siblings of `/app/bin/` instead of inside it, so the executable could
  never find its own assets. Fixed by installing everything the exe needs
  under `/app/bin/` alongside it, the same layout `flutter build linux`
  already produces
- Every back button's vertical position is now standardized on the same
  shared inset (`AppSpacing.floatingTopInset`) — it previously varied by a
  few px depending on which page you opened it from. Details and Anime
  Details still float the button directly over their full-bleed hero
  rather than inside a header bar like every other page — a deliberate
  difference for that layout, not left over from this fix

## [1.5.1+20] - 2026-09-10

### Added
- Download resilience: an HTTP or HLS-segment download that drops mid-way
  or closes just short of the expected size now auto-reconnects (up to 5
  attempts) instead of failing outright
- A "Copy Stream URL" button in the player, next to Cast

### Changed
- Leaving the player no longer force-exits fullscreen if the app was
  already fullscreen before it opened (e.g. kiosk mode) — only fullscreen
  the player itself entered. F11 now also toggles fullscreen, alongside F

### Fixed
- The Flatpak package failed to launch at all: "error while loading
  shared libraries: libsecret-1.so.0: cannot open shared object file".
  `flutter_secure_storage_linux` needs libsecret, which isn't part of the
  base Freedesktop runtime — now built and bundled as its own module
- The Flatpak's metainfo version was hand-written and already stale
  (showing 1.3.0 for a 1.5.0 install); now stamped from the same
  resolved version every other platform's filename uses

## [1.5.0+19] - 2026-09-10

### Added
- **Built-in Providers** settings page: each built-in scraper now has its
  own switch, so you can cut the source list down to the handful that work
  for you instead of waiting on all 48. Torrent providers are marked, and
  say when the P2P master switch has silenced them. The roster is generated
  from the scrapers the app actually registers, not a written-down list, so
  porting or dropping a scraper adds or removes its row with nothing else
  to update
- A Flatpak build and packaging manifest for Linux, alongside the existing
  AppImage and tar.gz

### Changed
- Anime's page now uses `BrowseScaffold`, the same hero + row + loading/error
  arrangement Movies and Series already use, instead of its own hand-rolled
  hero carousel and state machine. No card's look or size changed — Anime's
  rows already used the shared `BrowseRowView`/`AnimeCard`, so this only
  consolidated the page chrome around them
- Live TV's channel row (`IptvSliderSection`) now renders through the same
  shared `BrowseRowView` every other row uses, instead of its own copy of
  the scroll arrows, hover state and section header. Channel cards keep
  their own logo/banner shape — `BrowseRowView` can now take a row-specific
  card sizing instead of always using the poster one
- Every page with its own back button (Details, Search, Settings, and
  everything else routed through `pushPage`) now renders fullscreen,
  covering the hub's top bar and section chips, instead of showing both at
  once
- Settings redesigned: every category tile is now the same shape and size
  (icon, title, a short badge, chevron) — no subtitle sentence, no header
  intro card. Trakt.tv and Simkl merged into one "Sync" category; App
  Updates folded into About; the P2P master switch moved into Built-in
  Providers, next to the rows it silences; Discord Rich Presence moved into
  General & Data. Remaining categories sort A-Z, About last. Tablet/desktop
  shows them as a centered grid instead of a single narrow column
- The repository's default branch is now `main`, not `master`
- Release builds now warn in CI when no `ENV_FILE`/`DOTENV` secret is
  set, instead of silently producing artifacts with an empty `.env` —
  which is what every release so far has shipped, leaving Trakt, Simkl,
  Discord Rich Presence and TMDB cast photos inert in the binaries
- A failed Windows release build now re-runs the failing CMake INSTALL
  target verbosely, so the underlying error is in the log. `flutter
  build` summarises MSBuild's output, so the v1.4.0 build failed twice
  showing only `MSB3073` with no reason

### Fixed
- Settings could open twice from a fast double-click on the gear icon
  (easy to do with a mouse), stacking two instances — back had to be
  pressed twice to actually leave
- A pushed `v1.2.0` tag now publishes as a full release. Both the release's
  `prerelease` flag and its "(dev)" title came from
  `github.event.inputs.dev_build != 'false'`, and that input is an empty
  string on a tag push — so every tagged release would have been labelled
  an untested dev prerelease. The title, the badge and the channel compiled
  into the binaries are now all read from one resolved value
- An unverified build now actually says so. `dev_build` only ever set the
  GitHub release's title and prerelease flag; the binary carried a
  hardcoded empty channel, so Settings, Updates and About reported a dev
  prerelease as a verified release and hid the prerelease badge. The
  marker is now baked in by the build from the same condition that sets
  the release flag, so the two cannot disagree

## [1.4.0+18] - 2026-09-09

### Added
- Seed count and a P2P/HTTP indicator on every stream-source picker
  (Movies, Series, Anime, Arabic Anime, and the in-player panel) — the
  seed count was already being parsed out of source titles and then
  never shown
- Support for a TMDB API key baked into the build, so cast photos and
  character names work on a fresh install instead of only after the
  user registers and pastes their own key (which still takes
  precedence). See `TMDB_API_KEY` in docs/RELEASES.md

### Changed
- Audio track selection moved behind the video player's settings gear,
  alongside playback speed and aspect ratio, instead of its own button
  in the transport bar. The row is hidden for media with only one audio
  track
- The genre/decade/sort/search filters now stay on one line and stay
  put while the page scrolls, with the hero carousel starting just
  below them. They previously wrapped onto a second row on phones and
  scrolled away with the hero
- Live TV's header moved onto the same shared pill bar as every other
  section, instead of its own SafeArea and padding
- One page transition everywhere. The 750ms circular reveal is gone —
  it revealed from a tap position most call sites never had, including
  the poster tap it was designed for
- One page gutter, `AppSpacing.pageInset` (16/20/24, mobile first),
  replacing the 8/16/18/20/24/28/48 spread across filter bars, back
  buttons, header rows, section titles, card rows and grids

### Fixed
- Anime Details now picks its layout from the window width like every
  other page, instead of from the platform — a desktop window dragged
  narrow kept desktop metrics (38px titles, a 1440px content cap) while
  Movie Details beside it switched to mobile ones
- Backing out of the video player no longer exits the app when playback
  was started from an anime episode's source sheet
- The TMDB key shipped with a build is now actually used — cast
  enrichment still checked only for a user-entered key, so the built-in
  one never took effect
- Audio Sync Offset is reachable again for media with a single audio
  track; it lives in the audio menu, which was being hidden in exactly
  that case
- Wrong seed counts on source badges: titles like `[12/12]` or
  `Files: 3` were read as seed counts, and the `25/3 peers` form
  reported the leecher count instead of the seeds
- The filter bar no longer counts the status bar twice on notched
  phones, which cost ~50px of every browse page
- Row titles no longer shift sideways when real content replaces the
  loading skeleton
- Resuming from Continue Watching now opens straight into the player.
  It was pushed inside the hub's navigator, so the section top bar and
  sidebar stayed drawn around a fullscreen video screen
- The "Resuming..." spinner not closing, and popping the page under
  the Continue Watching row instead of itself
- Anime Details' back button sitting under the status bar on phones
  with a notch
- The torrent icon in the player's sources panel disagreeing with its
  own P2P badge for a magnet link carrying no separate infoHash

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
