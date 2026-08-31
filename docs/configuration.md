# Platforms & configuration

<!-- Extracted from README.md so the README stays an overview. -->

## Application identity

One identifier and one product name across every platform. Both are packaging
inputs, so changing either means changing the build scripts in step — they are
not driven from `AppInfo`.

| | Value | Set in |
|:--|:--|:--|
| Bundle / application id | `com.mediahub.playtorriomod` | `android/app/build.gradle.kts`, the two `project.pbxproj` files, `macos/Runner/Configs/AppInfo.xcconfig`, `linux/CMakeLists.txt` |
| Executable / bundle name | `PlayTorrioMod` | `windows/CMakeLists.txt`, `linux/CMakeLists.txt` (`BINARY_NAME`), `macos/.../AppInfo.xcconfig` (`PRODUCT_NAME`) |
| Display name | `AppInfo.name` | `lib/app_info.dart`, mirrored into `AndroidManifest.xml` and `ios/Runner/Info.plist` |

The Kotlin source package stays `com.example.playtorrio`. It is a namespace,
not an identifier anything outside the module sees, and renaming it moves
files for no user-visible gain.

## Platform Support

<table>
<tr><th>Platform</th><th>Status</th><th>Notes</th></tr>
<tr><td><b>macOS</b></td><td>Full support</td><td>Native desktop app. All features including torrent streaming and glassmorphism GPU effects. Primary development target.</td></tr>
<tr><td><b>iOS</b></td><td>Full support</td><td>Includes libass native framework for ASS/SSA subtitle rendering. All scrapers and streaming work.</td></tr>
<tr><td><b>Android</b></td><td>Full support</td><td>Min SDK 21 (Android 5.0). All features functional.</td></tr>
<tr><td><b>Linux</b></td><td>Full support</td><td>Native Linux desktop via GTK embedding. Torrent engine compiled for Linux.</td></tr>
<tr><td><b>Windows</b></td><td>Full support</td><td>Native Win32 desktop. All features functional.</td></tr>
<tr><td><b>Web</b></td><td>Experimental</td><td>Runs in Chrome but native plugins (libtorrent, fvp, libass) are unavailable. Limited to direct VOD streaming and metadata browsing.</td></tr>
</table>

<br/>

---

## Configuration

### pubspec.yaml — Key Dependencies

| Package | Version | Purpose |
|:--------|:--------|:--------|
| `flutter` | SDK | Core Flutter framework |
| `torrserver_flutter` | ^0.0.1 | Embedded TorrServer engine & HTTP streaming client |
| `fvp` | ^0.37.3 | FFmpeg-based video player with broad codec support |
| `video_player` | ^2.11.1 | Standard video playback widget |
| `liquid_glass_easy` | ^4.1.1 | GPU-accelerated glassmorphism shader effects |
| `cached_network_image` | ^3.4.1 | Image caching with placeholder and error states |
| `http` | ^1.2.2 | HTTP client for all API and scraper requests |
| `html` | ^0.15.5 | Server-side DOM parsing for web scrapers |
| `shared_preferences` | ^2.3.3 | Persistent key-value storage |
| `url_launcher` | ^6.3.2 | Open external URLs in browser |
| `archive` | ^4.0.9 | ZIP extraction for subtitle downloads |
| `path_provider` | ^2.1.6 | Platform-appropriate file paths |
| `photo_view` | ^0.15.0 | Pinch-to-zoom image viewing (manga reader) |
| `flutter_js` | ^0.8.1 | JavaScript runtime bridge for JS-based scrapers |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |
| `libass_plugin` | path: ./libass_plugin | Local iOS plugin for ASS/SSA subtitle rendering |

### Scraper Configuration — sources.json

```json
{
  "version": "1.0.0",
  "updated": "2026-08-09",
  "sources": [
    {"id": "flystream",     "name": "FlyStream",     "provider": "PlayTorrioHTTP", "script": "flystream.js"},
    {"id": "videasy",       "name": "Videasy",       "provider": "PlayTorrioHTTP", "script": "videasy.js"},
    {"id": "vidsrc",        "name": "VidSrc",        "provider": "PlayTorrioHTTP", "script": "vidsrc.js"},
    {"id": "multiembed",    "name": "MultiEmbed",    "provider": "PlayTorrioHTTP", "script": "multiembed.js"},
    {"id": "vidcore",       "name": "VidCore",       "provider": "PlayTorrioHTTP", "script": "vidcore.js"},
    {"id": "fourkhdhub",    "name": "4KHDHub",       "provider": "PlayTorrioHTTP", "script": "fourkhdhub.js"},
    {"id": "xdownloader",   "name": "XDownloader",   "provider": "PlayTorrioHTTP", "script": "xdownloader.js"},
    {"id": "knaben",        "name": "Knaben",        "provider": "PlayTorrio",     "script": "knaben.js"},
    {"id": "torrent_galaxy","name": "TorrentGalaxy", "provider": "PlayTorrio",     "script": "torrent_galaxy.js"}
  ]
}
```

### Glass Settings

```dart
// Toggle in Settings page — persisted to SharedPreferences
GlassSettings.enabled.value = true;   // Full liquid glass shaders
GlassSettings.enabled.value = false;  // Lightweight gradient fallback
```

### Launch Icons

The `flutter_launcher_icons` package generates app icons for all platforms from `assets/icon.png`. Configuration:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  windows:
    generate: true
    image_path: "assets/icon.png"
  image_path: "assets/icon.png"
  min_sdk_android: 21
```

<br/>

---

## Release signing

Only **Android** requires signing for the in-app updater to work. `OtaUpdate`
downloads the APK and hands it to the system package installer inside the app,
and Android refuses to replace an installed app whose signature does not match
— so an unsigned (debug-keyed) build cannot update a previous one. Every CI run
mints a fresh debug key, so without a stable release key each build is a
different signer and each update needs an uninstall.

Two repository secrets are required:

| Secret | Required | Notes |
|:--|:--|:--|
| `ANDROID_KEYSTORE_BASE64` | yes | The `.jks` keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | yes | Store password |
| `ANDROID_KEY_ALIAS` | no | Defaults to `playtorriomod` |
| `ANDROID_KEY_PASSWORD` | no | Defaults to the store password |

`keytool` allows one password to cover both the store and the key, and the
alias is fixed by convention, so the last two are only needed for a keystore
created with different values.

```bash
keytool -genkey -v -keystore playtorriomod-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias playtorriomod
base64 -w0 playtorriomod-release.jks > keystore.b64   # macOS: base64 -i
```

Add the secrets under Settings → Secrets and variables → Actions. **Keep the
`.jks` backed up** — without it no future build can update an existing install,
and the only recovery is changing `applicationId`, which orphans every install.

With no secrets set the build still succeeds using the debug key and emits a
warning annotation, so forks and local checkouts are never blocked.

### Other platforms

None of them need signing for updates, because none of them self-install:

| Platform | Updater behaviour | Signing buys |
|:--|:--|:--|
| Windows | Downloads the `.exe`, opens Explorer at it | An Authenticode certificate only removes the SmartScreen warning |
| Linux | Downloads the `.AppImage`, opens the folder | Nothing — AppImages are not signed |
| macOS | Opens the release page in a browser | Developer ID + notarization only removes the Gatekeeper warning |
| iOS | Opens the release page in a browser | iOS cannot self-install; distribution is sideload or the App Store |

There is no single credential that covers several of these: Android uses a Java
keystore, Windows an Authenticode certificate issued by a CA, and Apple
platforms a Developer ID tied to a paid Apple account. They are separate public
key infrastructures, so each would need its own secret if ever added.
