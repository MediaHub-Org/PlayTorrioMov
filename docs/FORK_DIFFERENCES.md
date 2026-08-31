# Fork Differences — vs `ayman708-UX/PlayTorrioV3`

What this fork (`MediaHub-Org/PlayTorrioMod`) does differently from the original
upstream repo, as of the last sync (`upstream/main` @ `cd10d6c`, upstream's v1.0.8,
merged into this fork's `main`). The fork is level with upstream: zero
commits behind.

Most of upstream's own features (Trakt/Simkl sync, the Debrid/download
engine, `AppThemeService`, the per-content-type "player studio" settings)
are now **shared** — pulled in by that merge. This doc covers what's left:
things this fork built that upstream doesn't have, and the handful of
upstream pieces this fork deliberately didn't carry over.

## Navigation architecture

Upstream's navigation is a single scrollable **HomePage** with a
macOS-style **LiquidDock** for switching between content areas, plus
per-page floating glass app bars (each screen draws its own logo/back
button/search/settings row since there's no persistent chrome).

This fork replaced that entirely with three top-level hubs and a
persistent global bar:

- **Watch / Listen / Read** hubs (renamed from Media/Music/Books to verbs),
  each with its own set of sections (chips), switched via a horizontal
  `SectionTopBar` under a slim global `TopBar` (logo + hub switcher +
  settings) that never disappears.
- No `HomePage`, no `LiquidDock`, no per-page app bars — every hub section
  is a `HubSection` in `HubController`, rendered inside a nested
  `Navigator` so pushed detail pages stay under the persistent TopBar
  instead of taking over the screen.
- `SectionedHubScaffold` is the shared shell for hubs whose sections are a
  flat switch (Watch, Read); Listen (`music_page.dart`) is a deliberately
  different shape (ambient background, keyboard shortcuts, drawer/modal
  overlays) and isn't forced into that shell.

Because of this, upstream's "Home Page UI & Themes" appearance-settings
page (hero spotlight, recommendation sliders, card density for a page that
no longer exists) wasn't carried over — there's no home feed to configure.
`ContinueWatchingSlider` itself was kept and is used inside the Anime
section instead.

## Content this fork has that upstream doesn't

- **Books** (Read hub): search libgen.li, download, read in-app via a
  webview-based epub reader (chapter-by-chapter, `file://` URLs so
  relative image/CSS resolve naturally). Ported from
  `ayman708-UX/PlayTorrioV2`'s books feature and restyled.
- **Podcasts** (Listen hub): search via the iTunes Search API, episodes
  streamed from each show's own RSS feed. Original build — PlayTorrioV2
  has no podcast feature to port from, and upstream V3 doesn't have one.
- **IPTV multi-view**: a grid button in the Live TV app bar plays up to 4
  channels at once (tap to swap audio focus). Scoped to channels with an
  already-cached stream — see `ROADMAP.md` for why fresh-scan support
  wasn't attempted.
- **Local JSON backup/export** (Settings → General & Data): the entire
  `SharedPreferences` store as one versioned file, restore from it later.
- **TMDB cast enrichment**: photos/character names filled in from the
  user's own free TMDB key when an addon only supplies plain name strings.
- Decade filter + sort on Movies/Series, genre filter on Anime, both on a
  shared `FilterDropdown` widget.

## Upstream features this fork adapted rather than kept as-is

- **Settings page**: adopted upstream's modular hub-plus-category-pages
  structure, but this fork's Backup/TMDB/keyboard-shortcuts sections
  didn't fit any existing category page, so they live in a new
  `general_settings_page.dart` rather than being dropped.
- **Collection page's downloads tab**: rewritten against upstream's new
  `DownloadTask`/`DownloadService` API (5 Debrid providers, real
  progress/status) in place of the old single-provider stub this fork
  had before the merge.
- **Trakt sync button** on the Collection page (manual sync trigger +
  syncing spinner) was removed — upstream's new modular `TraktService`
  has no reactive `isSyncing`/`manualSync()` equivalent to hang it off of.
  Auth-gated scrobbling itself (start/pause/stop) still works everywhere
  it's wired.

## Architecture cleanup unique to this fork

Not upstream-facing, but not upstream's either — dedup work done this
session, documented in `CHANGELOG.md` under "Architecture":

- `HorizontalSliderScroll` mixin (`MovieSliderSection`/`IptvSliderSection`
  scroll-arrow logic)
- `InteractiveCardShell` (`MovieCard`/`IptvChannelCard` hover/press physics)
- `HeroCarouselAutoRotate` mixin (anime/IPTV hero carousel timers)
- `SectionedHubScaffold` (Watch/Read hub shells)
- `_MusicModalShell` (the four music detail pages' shared wrapper)

## Deliberate divergences from upstream v1.0.7 / v1.0.8

Upstream's two latest releases were merged in full except for these, each a
considered call rather than a merge accident:

- **The advanced player settings stay.** Upstream v1.0.7 deleted the whole
  decoder/buffer/performance settings system (`video_player_settings_page.dart`,
  1,235 lines, plus 491 lines of `PlayerSettings`) in favour of hardcoded mpv
  defaults with `hwdec: auto-safe`. This fork keeps it, because that is where
  the Android black-screen fix lives: with `enableAndroidSurfaceProducer:
  false`, plain `mediacodec` decodes to a Surface nothing attaches, and the
  explicit `mediacodec-copy` is what makes video appear. Losing the settings
  page would also remove user control this fork's users already have.
- **Upstream's torrent tuning was taken, and it overrode ours.** The same
  release fixed something this fork had backwards: torrent playback used to
  skip mpv's cache entirely, on the theory that TorrServer's own read-ahead
  made it redundant. Upstream — whose author wrote the torrent engine —
  pointed out that TorrServer serves a file that is still downloading, so it
  *will* stall, and an mpv with no cache and a 30s timeout dies on the first
  gap. Their generous cache, 60s timeout and reconnect flags are now in, with
  buffer sizes still following the user's preset.
- **Discord Rich Presence is off by default.** Upstream ships it on. It
  publishes the title of whatever you are watching, reading or listening to
  to everyone who can see your Discord profile; for a client that plays
  torrented and scraped content, that is not something to start doing on a
  user's behalf unasked. The Settings toggle is unchanged — only the default.
  Pinned by `test/services/discord_rpc_default_test.dart` so a future merge
  cannot quietly flip it back.
- **Upstream's PDF / MOBI / FB2 reader pages were not restored.** This fork's
  Read hub is EPUB-only (`lib/pages/read/book_reader_page.dart`), and its
  book search filters libgen results to EPUB, so upstream's `pdfrx`,
  `dart_mobi` and `fb2_parse` readers would have nothing to open. This is a
  real capability gap rather than a preference — see `ROADMAP.md`.
- **Version, bundle id and product name are this fork's**, not upstream's, so
  the merge never carries `1.0.8`, `com.playtorrio` or `playtorrio.exe` back
  in.

## Known-not-carried-over

- Upstream's "Home UI & Themes" appearance page — no home feed to
  configure (see Navigation architecture above).
- The `HomePageSettings` service and everything downstream of it
  (recommendation-slider position/style toggles for the old home feed).
- Four old test files that tested pre-merge API shapes this fork no
  longer has (`debrid_service_test.dart`, `download_service_test.dart`,
  `collection_page_test.dart`, `recommendation_sliders_test.dart`) —
  removed rather than left broken; real coverage for the new
  Debrid/Download architecture is open follow-up work, not faked.

## Still open (tracked in `ROADMAP.md`)

Comics data source, cloud sync for the backup, Music/Radio/Audiobook
filters (blocked on missing genre data), and a full QA pass on
mobile/tablet/TV.
