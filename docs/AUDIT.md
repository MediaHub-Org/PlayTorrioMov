# Codebase Audit — PlayTorrioMod

**Date:** 2026-08-29
**Method:** Four parallel read-only audits (security, correctness/reliability, architecture/code-quality, UX/design), each scoped to its own concern and cross-checked against `ROADMAP.md`/`CHANGELOG.md` to avoid re-reporting already-tracked or already-fixed items. All findings are file:line-cited against the actual codebase, not generic checklist advice.

This is a point-in-time snapshot, not a task list — treat it as a reference to pull from when deciding what to work on next, not something to blindly work through top to bottom. Some items may already be stale by the time you read this if the code has moved on.

---

## Priority summary

The items below are the ones worth looking at first — either because they're concretely exploitable/user-visible, or because they contradict something the project has explicitly committed to (the ROADMAP's own cross-content-type consistency principle).

| # | Finding | Domain | Why it matters |
|---|---|---|---|
| 1 | ~~EPUB reader: Zip Slip path traversal + WebView universal file access~~ **Fixed (`80eaa99`)** | Security | A crafted EPUB from a scraped book source can write outside its extract dir, then JS in the reader's `file://` WebView can read/exfiltrate arbitrary local files. Realistic exploit chain, not theoretical. |
| 2 | ~~Cloud backup can transmit all app secrets over plaintext HTTP~~ **Fixed (`9403d60`)** | Security | The backup envelope includes every SharedPreferences key (Trakt/Simkl tokens, WebDAV password) and the app doesn't enforce `https://` on the WebDAV URL. |
| 3 | ~~`MusicPlayerController`/`AudiobookPlayerScreen` create a new native `Player()` per track/chapter with no reentrancy guard~~ **Fixed (`07a6f74`)** | Correctness | Rapid skip-button taps race two loads; the loser's native player handle leaks and both tracks can audibly overlap. Reachable by ordinary use, not an edge case. |
| 4 | "Favorite/like" has 5 different icon/color/interaction schemes across content types | UX | Directly contradicts the ROADMAP's own stated principle that favorites/search/filters stay consistent across every section. Most visible inconsistency in the app. **Partially fixed** — liked-heart color unified to red `0xFFE50914` across Music and the universal play bar; the Movies/Series bookmark and Anime status-picker remain intentionally distinct (library/status concepts, not likes). |
| 5 | ~~Manga page has no error handling on load failure → infinite spinner~~ **Fixed (`07a6f74`)** | UX | A network/scrape failure leaves `_isLoading` stuck forever with no message and no retry — looks like the app hung. |
| 6 | `player_screen.dart` and `trakt_service.dart` are god classes mixing 4-7 unrelated concerns each | Architecture | 2272 and 1850 lines respectively; any change to one concern (e.g. subtitle sync) risks breaking an unrelated one (gesture handling) sharing the same class scope. |
| 7 | ~~TLS certificate validation disabled in 5 HTTP clients~~ **Fixed (`398e563`)** | Security | `badCertificateCallback = (cert, host, port) => true` accepts any cert for scraped downloads/subtitles — MITM can tamper with downloaded content. |
| 8 | Zero test coverage on the just-merged media_kit/libmpv engine, all playback controllers, and `trakt_service.dart` | Architecture | The single riskiest recent change (full video engine swap) and the most complex untested file in the repo both have no automated regression coverage. |
| 9 | ~~`ErrorView` widget exists and is used in Watch hub pages, but not in Manga/Music~~ **Fixed (`07a6f74`)** | UX | Same "consistent UX across sections" principle violation as #4 — the fix already exists in the codebase, it's just not applied everywhere. |
| 10 | ~~Plaintext credential storage (Trakt/Simkl tokens, WebDAV password)~~ **Fixed** | Security | No `flutter_secure_storage`/keychain use anywhere — all in `SharedPreferences`, readable via device/backup access. |

---

## 1. Security

### Network / scraper security

- **`lib/services/anime/extractors/tryembed_extractor.dart:57`, `lib/services/books/book_download_service.dart:94`, `lib/services/music/music_download_service.dart:332,354`, `lib/services/subtitles/providers/subtitlecat_provider.dart:16`, `lib/services/subtitles/subtitlecat_service.dart:48`** — **Fixed (`398e563`)**, was Medium-High. `HttpClient()..badCertificateCallback = (cert, host, port) => true` unconditionally accepted any TLS certificate for any host, enabling MITM tampering of downloaded book/music/subtitle content. The override was removed from all 5 clients; they now use `HttpClient`'s default certificate validation.
- **`lib/services/anime_arabic/mega_proxy.dart:37-46,124-200`** — **Low-Medium**. Loopback-only local HTTP server proxying/decrypting Mega downloads sets `Access-Control-Allow-Origin: *` (line 140) on all responses. Any web content running in a browser/WebView on the same machine can fetch the decrypted stream if it can guess the timestamp-based token — same class of issue behind several real "malicious webpage talks to localhost app" CVEs, though loopback binding limits remote exposure.
- **`lib/services/anime/extractors/anidb_extractor.dart:57-73`** — **Low**. Desktop path shells out to `curl.exe`/`curl` with the scraped URL as one argv element (not shell-interpolated, so no injection), but with no host/scheme allowlist on the URL being fetched. Consistent with the rest of the scraper layer's trust model (single-user client fetching for itself), not a distinguishable new risk.
- No SSRF sink found where the app acts as a proxy fetching on behalf of another party — scrapers fetch for the local user directly, so classic SSRF impact doesn't cleanly apply here.

### Credential / secret handling

- **`lib/services/trakt/trakt_service.dart:393-394`, `lib/services/simkl/simkl_service.dart:341`** — **Fixed**, was Medium. Trakt/Simkl access & refresh tokens were stored in plaintext via `SharedPreferences` (`StorageService.setTraktAccessToken`/`setSimklAccessToken`). Now routed through `SecureValueStore` (`lib/services/storage/secure_value_store.dart`), a thin wrapper over `flutter_secure_storage` (Keychain/Keystore/Credential Locker) that transparently migrates a legacy plaintext value on first read and deletes the plaintext copy. Falls back to plaintext only if no secure backend exists (e.g. a desktop target missing its keychain), so credentials are never silently dropped.
- **`lib/services/backup/cloud_backup_settings.dart:20-49`** — **Fixed**, was Medium. WebDAV username/password were stored in plaintext `SharedPreferences` (`cloud_backup_webdav_pass`). The password now goes through `SecureValueStore`; the URL/username (non-secret) stay in `SharedPreferences`.
- **`lib/services/backup/backup_service.dart:34-46,100-128`** — **Fixed (`9403d60`)**, was High. The backup envelope dumps *every* SharedPreferences key — including the plaintext Trakt/Simkl tokens above — into one JSON file/upload, and `uploadToCloud`/`downloadFromCloud` made a plain `http.put`/`http.get` with no scheme enforcement. Both now call `_assertSecureUri()` first, requiring `https://` unless the host is loopback/RFC1918-private/`.local` (self-hosted-on-LAN stays allowed, matches this feature's own audience) — a public `http://` URL now throws before any network call, surfaced through the existing upload/download error-toast UI with no UI changes needed.
- **`lib/services/scraper/sites/tmdb_helper.dart:5`, `lib/services/scraper/sites/videasy.dart:13`** (same key), **`lib/services/scraper/sites/xdownloader.dart:13`, `lib/services/audiobook/audiobook_scraper_service.dart:313`** — **Low**. Hardcoded API keys/bearer tokens committed in source. Look like shared/public keys for third-party scrape targets rather than the app's own developer credentials, but still committed secrets that anyone reading the repo can revoke or abuse.

### Torrent / P2P / TorrServer attack surface

- `lib/services/p2p/p2p_settings_service.dart` is a UI preference toggle only — the real engine is the external `torrserver_flutter` package (`pubspec.yaml:39`, `^0.0.5`) and its bundled binary, outside this repo's source. **Needs separate verification** (bind address, control-API auth) — not something citable from this codebase alone.
- `lib/services/stream/torrent_stream_service.dart` only talks to TorrServer through the plugin's typed API (magnet add/remove/stream URL) — no raw process invocation with unsanitized strings, no shell interpolation. No command-injection sink found in this repo's code.

### Deep link / URL scheme handling

- No custom URL scheme registered in `android/app/src/main/AndroidManifest.xml` or `ios/Runner/Info.plist` (`CFBundleURLSchemes` absent). The `stremio://` handling (`lib/services/addon/addon_manager.dart:79-83`, `lib/pages/player/watch_screen.dart:1594-1598`) is a plain string rewrite applied to a URL the user pastes/selects inside the app, not an OS-level inbound deep-link handler. **Nothing notable** — no external-app-triggered attack surface here.

### WebView usage (`flutter_inappwebview`)

- **`lib/pages/read/book_reader_page.dart:347-352`** — **Fixed (`80eaa99`)**, was High. `InAppWebView` was initialized with `javaScriptEnabled: true`, `allowFileAccessFromFileURLs: true`, and `allowUniversalAccessFromFileURLs: true`, loading `file://` HTML extracted from a downloaded EPUB — JS running in the `file://` origin got same-origin access to the entire local filesystem. Both flags are now `false`; chapter HTML's relative `<img>`/`<link>` references still resolve fine via normal same-origin `file://` navigation (the flags only matter for JS-initiated `fetch()`/XHR to *other* file:// origins, which this reader's injected JS never does).
- Only other `InAppWebView` usage in the tree is this reader; no other `evaluateJavascript`/`loadUrl` call builds scripts from unsanitized external strings elsewhere.

### File system / path handling

- **`lib/pages/read/book_reader_page.dart:104-117`** — **Fixed (`80eaa99`)**, was High — Zip Slip. The EPUB (a ZIP) was extracted entry-by-entry with `File('${extractDir.path}/$entryName')` where `entryName` came directly from the archive with no traversal check — a malicious EPUB entry like `../../../somefile` could write outside `extractDir`, chaining directly with the WebView finding above. Now goes through a standalone `safeExtractPath()` helper (normalize + `p.isWithin` check against the extract root) with a 6-case unit test (`test/pages/book_reader_zip_slip_test.dart`) covering relative entries, traversal, and absolute-path entries.
- `lib/services/download/download_service.dart:150` and `lib/utils/download/download_path_helper.dart:101-106` — download filenames go through `DownloadPathHelper.sanitizeFilename` (strips `\/:*?"<>|`); subtitle files use an app-generated timestamp filename, not scraped input. No traversal risk in these two paths.

### Android / iOS manifest permissions

- **`android/app/src/main/AndroidManifest.xml:31`** — **Low-Medium**. `android:usesCleartextTraffic="true"` allows plaintext HTTP app-wide. Consistent with scrapers needing HTTP, but broad rather than scoped to specific domains.
- **`ios/Runner/Info.plist:5-11`** — **Medium**. `NSAppTransportSecurity` → `NSAllowsArbitraryLoads: true` disables ATS entirely app-wide rather than via a scoped exception-domain list.
- Permission list itself (`INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE*`, `POST_NOTIFICATIONS`, scoped storage permissions with `maxSdkVersion`, `REQUEST_INSTALL_PACKAGES` for OTA updates) is reasonably matched to what the app does — no broad `MANAGE_EXTERNAL_STORAGE`, contacts, or location permissions found.

### Dependency risk

- **`pubspec.yaml:40-54,80-96`** — `media_kit`/`media_kit_video`/`media_kit_libs_video` pinned to the git fork `https://github.com/Predidit/media-kit.git` rather than the pub.dev-published package — the app's core playback engine now comes from an unofficial fork with no independent security review. Flagged as a supply-chain consideration, not a proven vulnerability.
- `torrserver_flutter: ^0.0.5` — low version number, narrowly-scoped community plugin wrapping a bundled binary that spawns a process. Same "trust a small third-party package" consideration; nothing concrete found to fault in how this repo uses it.

---

## 2. Correctness & reliability

### Resource leaks / races — new `Player()` per item, no reentrancy guard

- **`lib/services/music/music_player_controller.dart:173-293`** (`_loadAndPlayTrack`) — **Fixed (`07a6f74`)**, was High. Created a new `Player()` (line 207) with no generation guard. If a second call started before the first's `await MusicService.instance.getAudioStream(...)` (217) resolved — e.g. spamming the skip button — the second call's cleanup (192-200) disposed the *current* `_player`, but the first call's local `player` variable and the listeners it registered afterward (242-273) were untouched by that cleanup. Whichever call reached `_player = player` (282) last won; the other's native `Player()` was orphaned (leak), and both tracks could audibly overlap momentarily. Now each call captures an incrementing `_loadGeneration` counter; a call whose generation is stale by the time its awaits resolve disposes its own (still-local, not-yet-shared) player and subscriptions instead of touching `_player`/`_subscriptions`, so only the latest call ever wins and no call can cancel another's listeners.
- **`lib/pages/audiobooks/audiobook_player_screen.dart:120-310`** (`_initChapter`) — **Fixed (`07a6f74`)**, was Medium-High. Same shape and same fix: new `Player()` per chapter (line 218) with no guard against overlapping calls from rapid "next chapter" taps or `player.stream.completed` autoplay firing mid-skip, now covered by the same generation-guard pattern.
- By contrast, `player_screen.dart` and `iptv_player_page.dart` correctly use a single `late final Player` for the widget's lifetime — this bug was specific to the two controllers that (re)create a player per content item.

### Async-after-dispose

- **`lib/pages/player/player_screen.dart:909-965`** (`_loadSubtitle`) — **Fixed (`07a6f74`)**, was Medium. After two unguarded awaits (subtitle download at 924, file read at 937-938), called `_setSubtitleScale` (950), which did an unconditional `setState` with no `mounted` check anywhere in the chain. `_loadSubtitle` runs fire-and-forget from `_fetchInitialSubtitles` (747); if the user backed out of the player while a slow subtitle download was in flight, this threw unhandled after dispose. Added a `mounted` check right after the download resolves, before any further `_player`/widget-state access.
- **`player_screen.dart:986-990` (`_setSubtitleScale`) and `1069-1085` (`_applyVolume`)** — **Fixed (`07a6f74`)**, was Low-Medium. Neither checked `mounted` internally, unlike nearly every other `setState` call in the file — both now bail immediately if unmounted.

### Boundary bug

- **`player_screen.dart:518-533`** (`_onPlaybackUpdate`, auto-next-episode trigger) — **Fixed (`07a6f74`)**, was Low. `pos.inSeconds >= dur.inSeconds - 15 && pos.inSeconds > 0` had no meaningful lower bound on `dur` (only `dur.inSeconds > 0`). Any source reporting under 15 seconds of duration (bad metadata, a short clip, a live stream misclassified as VOD) made `dur.inSeconds - 15` negative, firing the "Up Next" dialog almost immediately after playback starts. Guard changed to `dur.inSeconds > 15`.

### Silent error-swallowing

- **99 occurrences of `catch (_) {}` / `catch (e) {}` with zero logging across 53 files** (counted via grep; a broader count including debug-print-only catches, covered separately below, puts the total closer to 234). Worst concentrations are in scraper core parsing loops, where a silently-caught failure is indistinguishable from "the site legitimately returned no results":
  - `lib/services/scraper/sites/downloadeverything.dart` — 5 occurrences (99, 212, 214, 276, 351), inside the HTML/JSON parsing loop that builds stream results.
  - `lib/services/scraper/sites/tmdb_helper.dart` — 4 (63, 80, 136, 170).
  - `lib/services/scraper/sites/videasy.dart` — 3 (170, 209, 255).
  - `lib/services/download/download_service.dart` — 5; `lib/services/iptv/iptv_network.dart` — 6.
  - `player_screen.dart` itself has 4, but these are minor native-property setters (204-208, 1865-1870, 1874-1879) and one file-resolution fallback (972-977) — not playback-critical.

### Verified — not a recurring bug

- The `addPostFrameCallback`-without-`scheduleFrame()` bug fixed earlier this session in `continue_watching_service.dart` does **not** recur elsewhere. All ~27 other `addPostFrameCallback` call sites app-wide (catalog/details/manga/anime/music pages, `main.dart`, various sliders and panels) fire from `initState`/`build`/a user-gesture callback where a frame is already guaranteed pending — genuinely safe, not the same latent bug.
- No high-confidence null-safety force-unwrap footguns found — every `!` traced in `player_screen.dart` was structurally guarded by an immediately-preceding null/`isNotEmpty` check at the same call site.

### Minor reentrancy

- **`lib/pages/iptv/iptv_player_page.dart`** (`_startWatchdog`) — **Fixed (2026-08-31)**, and worse than reported. The finding described the 3-second freeze watchdog racing a manual source switch. In fact three call sites entered `_initPlayer()` with no coordination between them — the watchdog, `_switchSource`, and the 1-second auto-failover timer — and only the watchdog had any guard (`!_isLoading`), which stopped it re-entering itself and nothing else. A source tap during a failover ran two `player.open()` calls against the same long-lived player, each having read `_activeHitIndex` at its own start, so whichever open landed last decided which channel you got; the first to finish cleared `_isLoading` while the second was still buffering, and a superseded call's error surfaced over a stream that was loading fine and kicked off a failover chain for a source nobody was watching. Now uses the same `_initGeneration` counter as `music_player_controller` and `audiobook_player_screen`: every entry takes a generation, and each await resumes only if it is still the current one.

---

## 3. Architecture & code quality

### God files / SOLID violations

- **`lib/pages/player/player_screen.dart:75-167`** — **High**. `_PlayerScreenState` holds 55+ raw fields spanning seven unrelated concerns in one class: media_kit player/video-controller wiring, subtitle state, skip-segment state, gesture state (volume/brightness swipe), auto-next-episode countdown state, menu/panel visibility, and audio HUD state — plus networking (`_fetchInitialSubtitles`), business logic (`_fetchSkipSegments`, `_savePlaybackProgress`), and a ~430-line `_buildControlsOverlay`. Nothing here is factored into separate widgets/controllers the way the other god files at least partially are.
- **`lib/services/trakt/trakt_service.dart:69`** — **High**. Single 1850-line class merging OAuth device-flow auth, token storage, scrobbling, generic sync actions (watchlist/collection/history/ratings/lists), raw HTTP wrappers, and read APIs (lists/calendar/playback-progress/watched-episodes). Should be split into at least `TraktAuthService` + `TraktSyncService` + `TraktLibraryService` — as-is, an auth bug and a caching bug touch the same file and the review diff is unreadable.
- **`lib/pages/music/music_page.dart`** — **Medium**. Not a single-class problem — it's ~25 private classes (artist detail, album detail, curated/user playlist details, expanded player, queue drawer, lyrics drawer, downloads modal) crammed into one 5211-line file instead of separate files under `pages/music/`. File-level cohesion is gone even though individual classes are reasonably scoped.
- **`lib/pages/details/details_page.dart:67`** — **Medium**. `_DetailsPageState` (~1860 lines) mixes metadata fetching, Trakt/Simkl sync calls, and a large tab-content `build()` tree — same shape as `player_screen.dart`, smaller scale.

### Duplicated logic across content types

- **`lib/services/audiobook/audiobook_library_service.dart`, `lib/services/books/book_library_service.dart`, `lib/services/podcast/podcast_library_service.dart`** — **High priority, low risk**. Byte-for-byte identical structure (init/isLiked/toggleLike/_save, `ChangeNotifier`, SharedPreferences JSON blob under a `_liked_v1` key) — only the model type and key string differ. ~170 lines of pure copy-paste across 3 files; a textbook `LikedItemsService<T>` base/mixin candidate.
- **`lib/services/anime/anime_library_service.dart`** — genuinely different (a watch-status state machine with per-item progress, not a simple liked-list) — correctly *not* the same shape, don't force it into a shared base.

### State management consistency

- Mixed persistence styles: 10 files `extends ChangeNotifier`, 25 files use raw `ValueNotifier<T>` fields, 51 files follow the `Service.instance` singleton shape — no single convention for how a service publishes state.
- **`lib/services/playback_coordinator.dart:12`** — **Medium**. `PlaybackCoordinator` is a static-only class mirroring playback state independently from each controller's own state; every controller must manually call `setPlaying`/`setProgress` to stay in sync (already tracked in ROADMAP as duplicated-sync debt). Confirmed here to actually be a **triple** duplication in `player_screen.dart:88-90`: local `_isPlaying`/`_position`/`_duration` fields duplicate both the media_kit `Player`'s own stream state *and* `PlaybackCoordinator`'s static copy — three sources of truth for the same three values.

### Error handling patterns

- 234 `catch (e)` blocks in `lib/`; ~63% do nothing but `debugPrint`/`print` and swallow the exception with no rethrow, no user-facing surfacing.
- **`lib/services/download/download_service.dart:92-94,99-104`** — **Medium-High**. Failed persisted-download load/save is silently swallowed — the user's download list can silently come back empty, or the user can believe a download saved when it didn't.
- **`lib/services/subtitles/subtitle_extractor.dart:109-119`** — **Medium**. Zip/gzip decode failures use bare `print()` (not even `debugPrint`) and silently move on — subtitle sync just no-ops with no feedback.
- Several subtitle providers (`subdl_provider.dart:185`, `wyzie_provider.dart:159/182`, `stremio_subtitle_provider.dart:219`) use raw `print()` inconsistently with the rest of the codebase's `debugPrint` convention.
- Counter-example done right: **`lib/services/backup/backup_service.dart`** has zero swallowing catch blocks — it `throw`s and lets the caller handle/surface the failure. Worth using as house style for the fixes above.

### Testing gaps

- `test/` has ~29 files against 141 Dart files in `lib/services/` — coverage concentrated in ~8-10 services (`continue_watching_service`, `my_list_service`, `backup_service`, `download_service`, `app_breakpoints`, one scraper, subtitle parsing, `stream_health_checker`, anime extractors) — under 10% of the service layer.
- **Zero coverage**: `trakt_service.dart` (1850 lines, zero tests), all playback controllers, `playback_coordinator.dart` itself, 18 of 19 scraper sites, and — **High priority** — the entire media_kit/libmpv engine swap has no automated regression coverage anywhere, despite being the single riskiest recent change and already flagged in the project's own history as needing real-device verification.

### Dead code / leftover cruft

- No `Legacy`/`Old`/`Deprecated`/`V1`-named classes found anywhere in `lib/` — clean on this front.
- No `fvp`/`mdk` remnants from the old video engine anywhere in `lib/` or `pubspec.yaml` — the media_kit/libmpv migration is a complete, clean cutover, not a partial one. (Positive finding, not debt.)

### Dependency direction / layering violations

- **`lib/pages/read/books_page.dart:476-537`** (`_DownloadDialogState._run()`) — **High**. Does a raw `http.Request`/streamed download with manual byte accumulation and progress `setState` directly in a page widget, duplicating functionality that already exists in `lib/services/download/download_service.dart` (which has proper pause/cancel/persist semantics). This book download bypasses the app's own download service entirely — no pause/resume, no persistence across restart, no dedup with the download manager UI.
- Other pages touching `Uri.parse`/`http` (`watch_screen.dart`, `player_screen.dart`, `iptv_multiview_page.dart`, `trakt_settings_page.dart`, `simkl_settings_page.dart`, `audiobook_player_screen.dart`) were spot-checked and are launching external URLs or parsing already-fetched URLs, not performing raw scraping from UI — not layering violations.

---

## 4. UX & design consistency

### "Favorite" control — 5 different schemes across content types — **Fixed (2026-08-31)**

Five content types each rendered the same boolean "like" their own way: two pill variants (Manga inline, Audiobooks via a private `_LikeButton`), a bare `IconButton` (Podcasts), and two list-row hearts (Books, Music), in three different reds. The colours were unified on 2026-08-29; the *controls* were not.

All of them now use `LikeButton` (`lib/widgets/common/like_button.dart`), in one of two styles.

The two styles looked like they contradicted each other — the pill fills red and turns its icon **white**, the bare icon turns **red**. They do not, and the rule is now written down in the widget rather than rediscovered per page: a filled pill needs a white icon to stay legible against its own red fill; a bare icon has no fill and so must carry the colour itself. Both are `kLikedColor`.

Deliberately **not** folded in, because they are not the same concept:

- **Movies/Series** "Add to Library" — library membership, and a bookmark rather than a heart because that is what it means.
- **Anime** status — a four-state picker (Watching / Plan to Watch / Completed / Dropped). Collapsing it to a heart would delete the feature.
- **The fullscreen music player's like** — routes through the studio's user-configurable hover physics, which `LikeButton` would drop. It uses `kLikedColor` and carries the same semantics, so it follows the rules without being the widget.

`LikeButton` also carries `Semantics(button, toggled, label)`, which none of the five had — the bare-icon style has no visible text, so a screen reader previously announced an unlabelled button.

`test/widgets/like_button_test.dart` fails on any new filled/outline heart ternary outside those exceptions.

Empty-state copy tone is still uneven: `type_catalog_page.dart` gives an actionable "No content found. Install more addons in Settings." while `manga_page.dart` and `podcast_details_page.dart` give a flat "No X found" with no next step, despite Manga being equally addon/scrape-dependent. **Still open, severity low-medium.**

### Error/empty/loading state coverage

- **`lib/pages/manga/manga_page.dart:116-142,144-160`** (`_loadInitialData`/`_loadMore`) — **Fixed (`07a6f74`)**, was High. No try/catch around the scrape calls. On a network/scrape failure the exception propagated unhandled, `_isLoading` never reset, and the UI stuck on `CircularProgressIndicator` forever — indistinguishable from a hang. Both now catch, and `_loadInitialData` surfaces `ErrorView` with a retry button when the list is empty.
- **`lib/pages/music/music_page.dart:148-192`** (`_loadMusicData`) — **Fixed (`07a6f74`)**, was Medium. Caught and correctly reset `_isLoading`, but only `debugPrint`'d the error — no user-facing message or retry. Now also surfaces `ErrorView` with retry when the home sections are empty.
- **`lib/widgets/common/error_view.dart`** (a shared error+retry widget) is used correctly in `type_catalog_page.dart:179`, `catalog_page.dart:215`, `discover_page.dart:80` — **Fixed (`07a6f74`)**, was High. Manga and Music now import it too. Its title was previously hardcoded to `"Could not load movies"`; added a `title` param (default unchanged, so the 3 existing call sites are unaffected) so Manga/Music show correct copy instead of misattributing the failure.
- `lib/widgets/search/magnet_files_view.dart:343-364` is a good counter-example (proper error state with "Try Again", distinct empty-state) worth pulling other pages toward.

### Accessibility

- **Zero occurrences of `Semantics(` or `semanticLabel` anywhere in `lib/`** (full-tree grep), despite `CHANGELOG.md:192` claiming *"Screen-reader (Semantics) labels on all player control buttons"* — **this claim does not hold today**. What actually exists is `tooltip:` strings on `IconButton`s, which Flutter does expose to screen readers as a side effect, but that's not the same mechanism the changelog describes. Worth either implementing real `Semantics` coverage or correcting the changelog claim.
- `lib/widgets/player/player_transport.dart` is genuinely well-covered by tooltips (11/11 `IconButton`s) — not a finding on its own.
- **`lib/widgets/common/universal_play_bar.dart:140-148`** — **Fixed (`07a6f74`)**, was Medium. The central Play/Pause `IconButton` had no `tooltip`, while the Like button above it (127) and Close button below it (152) both did — a screen-reader user got "Unlike"/"Close" announced but nothing for the main transport control. Added a `Play`/`Pause` tooltip matching the button's current state.
- No text-scaling accommodation anywhere (`main.dart:141` has no `builder:` clamp, zero `textScaler` usage app-wide). **`section_top_bar.dart:18`** fixes its chip bar to `height: 44` with default-size text inside — at a larger system text scale, chip labels would clip rather than reflow. **Severity: medium.**

### Color contrast / hardcoded colors

- **`anime_details_page.dart:589-600`** — **Low-medium**. The native-language subtitle under the anime title is `Colors.white.withValues(alpha: 0.5)` with no `Shadow`, directly below a title that does carry a drop shadow for legibility. The backdrop scrim only reaches ~42% opacity at that position — the unshadowed subtitle is the weak link in an otherwise-handled visual block.
- **`lib/widgets/movie/movie_card.dart:110-120`** — **Low**. Card title has no explicit color (inherits default) while the year/type row two lines below explicitly sets alpha values — inconsistent styling approach within one widget, though not a visible contrast bug on its solid dark background.

### Responsive breakpoint values genuinely disagree — **Fixed (2026-08-31)**

Eight pages asked "is this desktop?" against four different literals — `>= 900`, `>= 800`, `> 800`, `>= 750`, `> 700` — so at an 820px window the nav chrome rendered tablet while Discover, Catalog, Anime, IPTV and the details pages rendered desktop: a visible split down the middle of one screen.

All eight now ask `AppBreakpoints.of(context)`, whose 900 was already the canonical value and what the nav chrome used. Pages in the 800–899 band therefore now get the tablet layout they were always meant to have, rather than a desktop layout that disagreed with the chrome around it.

Deliberately left alone, with the reason recorded so they are not "fixed" later by mistake:

- **Grid column ramps** (`width < 600 ? 2 : width < 900 ? 3 : ...`). A grid legitimately has more breakpoints than the three nav tiers, and these already ramp at the canonical 600/900.
- **The fullscreen music and audiobook players.** They are full-screen takeovers that draw no shared chrome, so their cutoff cannot disagree with anything beside it, and they reflow a player rather than a page.

`test/services/breakpoint_consistency_test.dart` fails on any new 700/750/800 width literal outside those two files.

### Navigation / back-button consistency

- **`podcast_details_page.dart:64-78`** — **Medium**. Uses a bare `Scaffold(appBar: AppBar(...))` with the default Material back chevron in an opaque toolbar — every other detail page (`details_page.dart:599`, `anime_details_page.dart:359`, `manga_details_page.dart:997`, `audiobook_detail_page.dart:168`) uses a custom translucent circular button floating over the hero image instead. Podcasts is the visible outlier.
- **`audiobook_player_screen.dart:693`** — **Low-medium**. Explicitly branches `isDesktop ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded` for the same "leave fullscreen player" action — a back arrow on mobile, an X on desktop — while its Read-hub siblings (`book_reader_page.dart:413`, `manga_reader_page.dart:923`) both consistently use `arrow_back_rounded` regardless of platform.

### Text overflow / truncation

Spot-checked `movie_card.dart`, `manga_card.dart`, `audiobooks_page.dart`, and `magnet_files_view.dart` (the most unpredictable scraped text in the app — torrent titles/filenames) — all consistently pair `maxLines` with `TextOverflow.ellipsis`. **No gap found** — this is a genuinely well-handled pattern across the codebase.

---

## Notes on what's *not* in here

- Items already tracked in `ROADMAP.md` (the 52-file breakpoint-helper migration, `PlaybackCoordinator`'s per-controller sync duplication as a general pattern, the pending real-device QA pass, the media_kit engine swap's own "awaiting confirmation" status) are referenced above only where this audit found something *more specific* than what's already tracked — not re-litigated wholesale.
- Bugs already fixed this session (Windows close-crash, the `addPostFrameCallback`/`scheduleFrame()` gap, stale `_controller` references from the media_kit merge) are confirmed *not* to recur elsewhere, not re-reported.
- `torrserver_flutter`'s bundled native binary and the P2P engine's actual bind-address/auth behavior are outside this repo's source and need separate verification — flagged, not investigated further here.
