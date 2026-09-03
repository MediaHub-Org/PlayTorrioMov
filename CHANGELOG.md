# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
  `video_player_settings_page.dart`)

### Fixed
- AniList catalog 403s — request now sends a browser-like User-Agent/
  Origin/Referer and a 15s timeout instead of the old custom UA (ported
  from upstream `cc07994`)
- IPTV player now actually applies `PlayerSettings`' video controller
  configuration instead of bare defaults

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
