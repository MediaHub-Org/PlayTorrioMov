<p align="center">
  <img src="assets/icon-playtorriomov.png" alt="PlayTorrioMov logo" width="160"/>
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

PlayTorrioMov is the primary app in the `MediaHub-Org` family — a
watch-only fork of [PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod)
(Movies, Series, Anime, Live TV, nothing else). The smaller codebase is
easier to keep consistent and has been working well, so this repo now
carries its own roadmap, changelog and docs instead of pointing back to
PlayTorrioMod for them.

## Sections

| Section             | Content                                       |
|:--------------------|:----------------------------------------------|
| **Movies & Series** | TMDB-catalog movies and series, one tap apart |
| **Anime**           | Its own catalog and scraper                   |
| **Live TV**         | IPTV channels                                 |
| **Library**         | Everything you've saved                       |

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

| Target  | Command                  |
|:--------|:-------------------------|
| Android | `flutter run -d android` |
| iOS     | `flutter run -d ios`     |
| Windows | `flutter run -d windows` |
| macOS   | `flutter run -d macos`   |
| Linux   | `flutter run -d linux`   |

On first launch the app installs the default Cinemeta addon and starts the
torrent engine. Nothing else needs configuring to start browsing.

Prebuilt installers and APKs for every platform are on the
[releases page](https://github.com/MediaHub-Org/PlayTorrioMov/releases). On
Android, prefer `arm64-v8a` unless you know you need otherwise — it is the same
build as the universal APK at a third of the size.

## Documentation

| Document                     | What's in it                                                            |
|:-----------------------------|:------------------------------------------------------------------------|
| [Roadmap](docs/ROADMAP.md)   | What is still outstanding, and this app's relationship to PlayTorrioMod |
| [Tasks](TASKS.md)            | Near-term checklist                                                     |
| [Changelog](CHANGELOG.md)    | Notable changes by version                                              |
| [Releases](docs/RELEASES.md) | Build/release process, Android signing                                  |

## Building and releases

CI builds every platform. Pull requests run analysis, the test suite and an
Android APK; merges to `main` run the same checks and refresh the shared build
cache. Full release-workflow and signing details are in
[docs/RELEASES.md](docs/RELEASES.md).

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
