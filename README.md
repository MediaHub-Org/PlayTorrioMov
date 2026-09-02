<p align="center">
  <img src="assets/icon.png" alt="PlayTorrioMov logo" width="160"/>
</p>
<p align="center">
  <h1 align="center">PlayTorrioMov</h1>
  <h3 align="center"><em>Movies, Series, Anime & Live TV — one app</em></h3>
</p>

<p align="center">
  A Flutter media app that pulls movies, series, anime and live TV into a
  single interface — from Stremio-compatible addons, torrent swarms, and the
  open web. Forked from
  <a href="https://github.com/MediaHub-Org/PlayTorrioMod">PlayTorrioMod</a>
  with Music and Books removed — better served by dedicated apps.
</p>

<p align="center">
  <a href="https://github.com/MediaHub-Org/PlayTorrioMov/releases"><img height="20" src="https://img.shields.io/github/v/release/MediaHub-Org/PlayTorrioMov?include_prereleases&style=flat&color=7C5CFF" alt="Latest release"/></a>
  <img height="20" src="https://img.shields.io/badge/LICENSE-GPL--3.0-4169A1?style=flat" alt="License"/>
  <img height="20" src="https://img.shields.io/badge/FLUTTER-3.44-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
  <img height="20" src="https://img.shields.io/badge/Android_iOS_Windows_macOS_Linux-000000?style=flat" alt="Platforms"/>
</p>

---

> **This is a partial mirror fork of [PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod)** —
> watching content only (Movies, Series, Anime, Live TV), nothing else.
> PlayTorrioMod is the primary development repo: the roadmap, architecture
> notes, and all other documentation live there. This repo is a fraction
> mirror copy of it, source code only.

## Sections

| Section | Content |
|:--|:--|
| **Movies & Series** | TMDB-catalog movies and series, one tap apart |
| **Anime** | Its own catalog and scraper |
| **Live TV** | IPTV channels |
| **Library** | Everything you've saved |

On phones the sections sit in the bottom tab bar; tablets and desktops get a
chip row under the top bar.

## Quick start

Requires the Flutter SDK (3.44 or later) and, for mobile builds, Xcode or the
Android SDK.

```bash
git clone https://github.com/MediaHub-Org/PlayTorrioMov.git
cd PlayTorrioMov
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
[releases page](https://github.com/MediaHub-Org/PlayTorrioMov/releases). On
Android, prefer `arm64-v8a` unless you know you need otherwise — it is the same
build as the universal APK at a third of the size.

## Documentation

Architecture, streaming pipeline, content sources, UI design tokens, player
internals, roadmap, and contributing guidelines all live in
[PlayTorrioMod's own docs](https://github.com/MediaHub-Org/PlayTorrioMod/tree/main/docs) —
this fork doesn't carry a separate copy.

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
in-app updater replace an existing install. Without them builds still
succeed, signed with a throwaway debug key.

## Credits

PlayTorrioMov descends from [PlayTorrioV3](https://github.com/ayman708-UX/PlayTorrioV3)
by [Ayman](https://github.com/ayman708-UX), via
[PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod). Ayman created
the original application — the Stremio addon integration, the VOD scraper
system, the torrent streaming engine, the audiobook aggregator, the manga
reader, the music integration and the subtitle system, across five platforms.

PlayTorrioMov keeps the media half of that work and drops the rest: one hub,
the four sections listed above, and no hub switcher. Music, podcasts,
audiobooks, books, manga and comics live on in PlayTorrioMod for anyone who
wants them in one app.

---

<p align="center">
  <sub>Licensed under GPL-3.0 · Built with Flutter and Dart · Playback via media_kit and libmpv</sub>
</p>
