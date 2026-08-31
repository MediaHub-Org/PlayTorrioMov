<p align="center">
  <img src="assets/icon.png" alt="PlayTorrioMod logo" width="160"/>
</p>
<p align="center">
  <h1 align="center">PlayTorrioMod</h1>
  <h3 align="center"><em>Watch, Listen, Read — one app, every format</em></h3>
</p>

<p align="center">
  A Flutter media hub that pulls movies, series, anime, live TV, music, radio,
  podcasts, audiobooks, books, comics and manga into a single interface —
  from Stremio-compatible addons, torrent swarms, and the open web.
</p>

<p align="center">
  <a href="https://github.com/MediaHub-Org/PlayTorrioMod/releases"><img height="20" src="https://img.shields.io/github/v/release/MediaHub-Org/PlayTorrioMod?include_prereleases&style=flat&color=7C5CFF" alt="Latest release"/></a>
  <img height="20" src="https://img.shields.io/badge/LICENSE-GPL--3.0-4169A1?style=flat" alt="License"/>
  <img height="20" src="https://img.shields.io/badge/FLUTTER-3.44-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
  <img height="20" src="https://img.shields.io/badge/Android_iOS_Windows_macOS_Linux-000000?style=flat" alt="Platforms"/>
</p>

---

## Three hubs

Navigation is organised by what you want to do, not by file format. Every hub
shares the same search, filters, favourites and playback surface.

| Hub | Sections |
|:--|:--|
| **Watch** | Movies · Series · Anime · Live TV · Library |
| **Listen** | Music · Radio · Podcasts · Library |
| **Read** | Audiobooks · Books · Comics · Manga · Library |

On phones the section switcher collapses to a dropdown; tablets and desktops
get the full chip bar. See [UI & Design](docs/ui-design.md).

## Quick start

Requires the Flutter SDK (3.44 or later) and, for mobile builds, Xcode or the
Android SDK.

```bash
git clone https://github.com/MediaHub-Org/PlayTorrioMod.git
cd PlayTorrioMod
flutter pub get
flutter run
```

| Target | Command |
|:--|:--|
| Android | `flutter run -d android` |
| iOS | `flutter run -d ios` |
| Windows | `flutter run -d windows` |
| macOS | `flutter run -d macos` |
| Linux | `flutter run -d linux` |

On first launch the app installs the default Cinemeta addon and starts the
torrent engine. Nothing else needs configuring to start browsing.

Prebuilt installers and APKs for every platform are on the
[releases page](https://github.com/MediaHub-Org/PlayTorrioMod/releases). On
Android, prefer `arm64-v8a` unless you know you need otherwise — it is the same
build as the universal APK at a third of the size.

## Documentation

Everything beyond this page lives in [`docs/`](docs/).

| Document | What's in it |
|:--|:--|
| [Architecture](docs/architecture.md) | Layer diagram, project structure, the patterns the codebase leans on |
| [Streaming](docs/streaming.md) | Discovery pipeline, VOD scrapers, torrent engine, Stremio addons, subtitles |
| [Content sources](docs/content-sources.md) | Manga reader, audiobook aggregation, music streaming |
| [UI & design](docs/ui-design.md) | Design tokens, glassmorphism, responsive tiers |
| [Platforms & configuration](docs/configuration.md) | Platform support matrix and runtime settings |
| [Player](docs/player.md) | Playback engine, decoders, subtitle rendering |
| [Changelog](docs/CHANGELOG.md) | What shipped, when |
| [Roadmap](docs/ROADMAP.md) | What is still outstanding |
| [Fork differences](docs/FORK_DIFFERENCES.md) | How this fork diverges from upstream |
| [Audit](docs/AUDIT.md) | Findings log and their resolutions |
| [Contributing](docs/CONTRIBUTING.md) | How to propose a change |
| [Branching](docs/branching.md) | Branch model, contributing upstream, pulling upstream changes in |

## Building and releases

CI builds every platform. Pull requests run analysis, the test suite and an
Android APK; merges to `main` run the same checks and refresh the shared build
cache.

To cut a downloadable build without tagging a release, dispatch the
**Build and Release** workflow with a `release_tag` such as `v1.2.0` — it
publishes all six platforms. Leave `release_tag` empty to build every platform
and upload artifacts only.

Dispatched builds default to `dev_build`, which titles the release `(dev)` and
publishes it as a GitHub prerelease; the app shows the same marker next to its
version. Untick it once a build has been verified on a device. Tags matching
`v*` publish a full release; a tag carrying a semver prerelease suffix
(`v1.2.0-rc.1`) publishes as a prerelease.

Android release signing needs two repository secrets, and is what lets the
in-app updater replace an existing install — see
[release signing](docs/configuration.md#release-signing). Without them builds
still succeed, signed with a throwaway debug key.

## Credits

PlayTorrioMod is a fork of [PlayTorrioV3](https://github.com/ayman708-UX/PlayTorrioV3)
by [Ayman](https://github.com/ayman708-UX), who created the original
application — the Stremio addon integration, the VOD scraper system, the
torrent streaming engine, the audiobook aggregator, the manga reader, the music
integration and the subtitle system, across five platforms.

This fork reorganises navigation into the three hubs above and continues from
there; see [fork differences](docs/FORK_DIFFERENCES.md) for the specifics.

---

<p align="center">
  <sub>Licensed under GPL-3.0 · Built with Flutter and Dart · Playback via media_kit and libmpv</sub>
</p>
