# Changelog

All notable changes to PlayTorrio V3 will be documented in this file.

## [unreleased] — 2026-08-22

### Move the artifact actions onto Node 24 — 2026-08-31
- **I got this wrong twice before getting it right.** First I wrote that the release job ran a step on "the deprecated Node 20" — an assumption. Then I checked the actions' own `action.yml`, found `upload-artifact@v5` and `download-artifact@v5`/`v6` all declaring `using: node20`, and concluded there was nothing to fix, since bumping within those majors changed nothing.
- **The v1.1.3 release run settled it**: `##[warning]Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on Node.js 24: actions/upload-artifact@v5`. The runner is already overriding them, and GitHub says that override is temporary. That is exactly the "revisit only if a release run actually warns" condition the roadmap entry named.
- The fix is a *higher major*, not a different v5. Verified from each action's own `action.yml`: `upload-artifact@v6` and `download-artifact@v7` declare `node24`. Both are post-v4, so they remain a compatible pair — the only documented artifact incompatibility is v4-and-above being unable to read `upload-artifact@v3` or below.
- `checkout@v5`, `cache@v5` and `setup-java@v5` did not appear in the warning and are already on Node 24; they stay.
- Roadmap item 8 now tracks the real dated fuse instead: every Android build warns that the app and six plugins apply the Kotlin Gradle Plugin, and that *"future versions of Flutter will fail to build"* because of it.
### One like control instead of five (AUDIT: favorite schemes, High) — 2026-08-31
- **Five content types each rendered the same boolean "like" their own way**: two pill variants (Manga inline, Audiobooks via a private `_LikeButton`), a bare `IconButton` (Podcasts), and two list-row hearts (Books, Music). The colours were unified on 2026-08-29; the controls were not.
- All now use `LikeButton`, in one of two styles.
- **The two styles only looked contradictory.** The pill fills red and turns its icon *white*; the bare icon turns *red*. That is correct, and the reason is now in the widget rather than rediscovered per page: a filled pill needs a white icon to stay legible against its own fill, while a bare icon has no fill and must carry the colour itself. Both use `kLikedColor`.
- **Not folded in, because they are different concepts**: Movies/Series' "Add to Library" (library membership, hence a bookmark); Anime's four-state status picker (collapsing it to a heart would delete the feature); and the fullscreen music player's like, which routes through the studio's configurable hover physics — it uses `kLikedColor` and the same semantics without being the widget.
- **Gained accessibility none of the five had**: `Semantics(button, toggled, label)`. The bare-icon style has no visible text, so a screen reader previously announced an unlabelled button.
- A test fails on any new filled/outline heart ternary outside those exceptions. Its first draft flagged a sub-tab icon and an empty-state glyph — matching the *ternary* rather than the icon name is what distinguishes a toggle from decoration.
### Remove the Music Player Studio's Mini Bar half — 2026-08-31
- **It configured a widget that does not exist.** The studio's "Mini Bar" target let you pick a preset, drag components into an order and watch a live preview, then told you it was "set as active bottom bar". This fork replaced upstream's per-page mini players with the shared `UniversalPlayBar`, which reads none of `MusicSettings` — so none of it ever reached the screen.
- Wiring it up instead was the other option and was rejected: the bar is shared across music, video, audiobooks and podcasts, so a music-only component order would make it rearrange itself whenever you switched source type. The one-shared-bar architecture is the fork's design; a music-only mini-player customiser contradicts it.
- Removed the Fullscreen/Mini switcher, the mini preview card and its component builder, `MusicMiniPlayerPreset`, `selectedMiniPreset`, `componentOrderMini`, `reorderMiniComponents` and `setSelectedMiniPreset` — 280 lines. The Fullscreen studio, which genuinely works (`music_page.dart` reads `selectedFullscreenPreset`), is untouched.
- `settings_are_wired_test.dart` no longer needs its two exemptions, so the rule is now unconditional: every persisted setting is read by something.

### One answer to "is this desktop?" (AUDIT: breakpoint values disagree) — 2026-08-31
- **Eight pages asked the question against four different literals** — `>= 900`, `>= 800`, `> 800`, `>= 750`, `> 700`. At an 820px window the nav chrome rendered tablet while Discover, Catalog, Anime, IPTV, the details page and the Arabic anime details page rendered desktop: a visible split down the middle of one screen.
- All eight now ask `AppBreakpoints.of(context)`. Its 900 was already canonical and already what the nav chrome used, so the outliers moved up to it rather than the shared value moving down for them. Pages in the 800–899 band now get the tablet layout they were meant to have instead of a desktop one that disagreed with the chrome around it.
- **Not touched, deliberately**: grid column ramps (`width < 600 ? 2 : width < 900 ? 3 : …`) — a grid legitimately has more breakpoints than three nav tiers, and those already ramp at the canonical values — and the fullscreen music and audiobook players, which draw no shared chrome so cannot disagree with anything beside them.
- A test fails on any new 700/750/800 width literal outside those two files. The first draft of it flagged the grid ramps too; narrowing it to the values that actually drifted is what makes it a rule rather than a nuisance.

### One row implementation instead of two — 2026-08-31
- **`AnimeSliderSection` and `BrowseScaffold`'s row were the same widget written twice**: same `MovieCardSizing`, same `SectionHeader`, same hover-revealed `SliderArrow`, same 0.8-viewport scroll step. Two adjacent screens, free to drift apart on card size, spacing or arrow behaviour with nothing to stop them.
- Extracted `BrowseRowView<T>` as the one implementation. `BrowseScaffold` builds its rows from it; `AnimeSliderSection` is now a 40-line wrapper that supplies `AnimeCard`. Net −300 lines across the two files.
- **Arrows are now gated on hover alone**, dropping the width check in one copy and the `defaultTargetPlatform` check in the other. Both were proxies for "has a pointer", and wrong in opposite directions: a Windows tablet in touch mode got arrows it could not hover, an Android device with a mouse got none. A touch device never fires `onEnter`, so hover answers the question directly.
- The existing "mobile gets no scroll arrows" test caught the change, as intended. It now asserts the stronger property — that an un-hovered arrow sits *off-screen* rather than merely absent — since asserting absence was asserting the old width check rather than the behaviour.
- **Migrating the anime page itself onto `BrowseScaffold` was dropped**, and the roadmap records why: `AnimeSliderSection` is also used by `anime_search_page`, so converting only the anime page would have left two row implementations on adjacent screens — the exact problem this change removes.

### Fix the IPTV player opening two streams at once (AUDIT #minor-reentrancy) — 2026-08-31
- **Three call sites entered `_initPlayer()` with no coordination**: the 3-second freeze watchdog, `_switchSource` when the user picks another source, and the 1-second auto-failover after an error. Only the watchdog had a guard, and `!_isLoading` only stopped it re-entering *itself*.
- Tapping a source during a failover therefore ran two `player.open()` calls against the same long-lived player, each having read `_activeHitIndex` at its own start — so whichever `open()` landed last decided which channel you actually got. The first to finish cleared `_isLoading` while the second was still buffering, and a superseded call's error surfaced over a stream that was loading fine, starting a failover chain for a source nobody was watching.
- Now uses the same `_initGeneration` counter as `music_player_controller` and `audiobook_player_screen`: every entry takes a generation and each await resumes only if it is still current. Third player to get this treatment; the pattern is now the house answer for "one long-lived player, several things that reopen it".

### Remove files that cannot build, run, or be reached — 2026-08-31
- **`web/`** — 6 files of `flutter create` scaffolding for a platform the app cannot target: `media_kit`/libmpv, `torrserver_flutter` and `flutter_inappwebview` have no web support, no CI job builds it, and the platform matrix has never listed it.
- **`bin/inspect.dart`** — an 84-line scratch script that scrapes one hardcoded WeebCentral manga URL. Referenced by nothing but the architecture doc's file tree.
- **`assets/subfont.ttf`** — byte-identical duplicate of `assets/fonts/subfont.ttf` (157 KB), shipped twice in every build. `PlayerSettings` already tried the `fonts/` copy first, so the fallback path was dead too.
- **`docs/superpowers/`** — 780 lines of agent task-lists for the design-system and nav work, all shipped, and now actively misleading: the plan describes keeping `TopBar` on tablet/desktop, which the hub-pill restructure replaced. What shipped is in the CHANGELOG.
- Kept `docs/AUDIT.md` despite its age — most of its findings (accessibility, contrast, breakpoint disagreements, god files, testing gaps) are still open. Only its title was stale, still saying PlayTorrioV3.

### Delete 184 lines of settings that were never read — 2026-08-31
- **Found by asking a question the last two bugs suggested**: `enableNetworkReconnect` and then `hardwareAudioClock` were both stored, restored on launch and exposed as settings, yet never applied to anything. Two of the same bug is a pattern, so all 130 persisted settings were checked mechanically.
- **19 more were dead.** `MusicSettings` and `AudiobookSettings` each carried a full ambient-light block (enable/pattern/intensity/speed), plus card density, lossless badges, liquid glass, drawer toggles and player-chrome flags; `IptvSettings` carried an ambient-light toggle. Every one had a pref key, a notifier, a loader line, a setter and a reset line — and no UI writing it and nothing reading it. They read as copy-paste of `MangaSettings`, where the same settings genuinely work (UI plus a consumer in `manga_page.dart`).
- `test/services/settings_are_wired_test.dart` now walks every settings service and fails on a persisted value nothing outside its own file reads. Settings that are deliberately applied in-file (`audioDelayDefault`, `hardwareAudioClock`) are listed explicitly with a note saying where.

### Merge upstream v1.0.7 + v1.0.8 — the fork is level again — 2026-08-31
- **Took**: Discord Rich Presence (`discord_rpc_service.dart`, wired into 10 call sites), the IPTV portal/network work and its new `defaultScrapeSource` setting, `watch_screen`'s copy-magnet button, the `stream_model` additions, torrent-stream and sources-panel tweaks, updater wakelock protections.
- **Upstream fixed something this fork had backwards.** Torrent playback used to skip mpv's cache entirely, on the theory that TorrServer's own read-ahead made it redundant. Upstream — whose author wrote the torrent engine — points out that TorrServer serves a file that is *still downloading*, so it will have gaps, and an mpv with no cache and a 30s timeout dies on the first one. That is plausibly part of the "stream error / stuck" symptom torrent playback showed. Their generous cache, 60s timeout and reconnect flags are now in; buffer sizes still follow the user's preset rather than being hardcoded.
- **Kept the advanced player settings.** Upstream v1.0.7 deleted the entire decoder/buffer/performance system — `video_player_settings_page.dart` (1,235 lines) plus 491 lines of `PlayerSettings` — in favour of hardcoded defaults with `hwdec: auto-safe`. This fork keeps it, because that is where the Android black-screen fix lives: with `enableAndroidSurfaceProducer: false`, plain `mediacodec` decodes to a Surface nothing attaches, and the explicit `mediacodec-copy` is what makes video appear.
- **Fixed a dead setting found while merging**: `hardwareAudioClock` was stored, restored and exposed in the UI but never applied to a player, so turning it off did nothing. It now sets `video-sync`.
- **Discord Rich Presence defaults to off.** Upstream ships it on; it publishes the title of whatever you are watching, reading or listening to, to everyone who can see your Discord profile. For a client that plays torrented and scraped content that is not a default to inherit. The Settings toggle is untouched — only the default — and a test pins it so a future merge cannot flip it back silently.
- **Not restored**: upstream's PDF/MOBI/FB2 reader pages and their four packages. This fork's Read hub is EPUB-only and its book search filters libgen to EPUB, so those readers would have nothing to open. Recorded in the roadmap as a real capability gap, not a preference.
- Identity files (version, bundle id, product name, installer, workflow) resolved to this fork's throughout, so the merge never drags `1.0.8`, `com.playtorrio` or `playtorrio.exe` back in.

### One Library shape across all three hubs — 2026-08-30
- **Each hub's Library had invented its own tabs.** Watch had My List / Watchlist / History / Downloads (4), Read had Audiobooks / Books / Manga / History / Downloads (5), Listen had Songs / Podcasts / Playlists / Recent / Downloads (5). Three shapes, three tab counts, and "what I saved" living under three different names — so moving between hubs meant relearning the Library each time.
- All three now build from one `LibrarySection` enum: **Saved · Continue · History · Downloads**, in that order, with the same labels and icons. A test asserts the enum's shape and that no page hand-rolls a tab list again, which is how they drifted apart before.
- **Watch**: Watchlist stopped being its own tab. A watchlist entry is just a My List item with `isWatchlist` set, so it is now a toggle beside the type chips — which also makes "series I bookmarked" expressible, where two separate tabs could not compose. Continue reads `activeItems`, History reads `historyItems`; both render through one row builder so they cannot drift visually.
- **Read**: audiobooks, books and manga became a sub-tab inside Saved, the pattern already used for Movies/Series and Comics/Manga. Continue and History read the same reading log split on progress — past 95% counts as finished, since readers rarely close a book on the exact last page.
- `SectionSubTabs` now scrolls instead of overflowing. It was written for two-way splits; a three-way one with longer labels ("Audiobooks / Books / Manga") overflowed a 320px phone by 122px, which paints the striped overflow warning over the control. Regression-tested at 320px and again at a 1.6x text scale.
- **Listen**: songs, podcasts and playlists became a sub-tab inside Saved. Music has no half-listened track to resume, so Continue shows the current play queue — the closest real equivalent, and something the Library previously offered no way to see at all.

### Desktop scroll arrows and row subtitles in the shared browse layout — 2026-08-30
- **Horizontal rows on desktop could only be scrolled by dragging.** Anime's own slider had hover-revealed arrows; Movies/Series, on the shared `BrowseScaffold`, had none — the same content, two different affordances depending on which section you were in.
- `BrowseScaffold` rows now carry their own `ScrollController` and fade in the existing shared `SliderArrow` on hover, on pointer devices only. The hero gained the same pair. Touch widths get neither: a swipe already works, and a permanent arrow just covers the artwork.
- Each row is its own widget so one row scrolling does not rebuild the others.
- `BrowseRow` gained an optional `subtitle`, which `SectionHeader` already rendered.
- **This was the blocker on migrating Anime**, whose hero and rows have both features. Books was checked and ruled out instead: `BookResult` has no cover URL at all, so a hero and poster rows would be blank rectangles — the text-row list is right for cover-less metadata. Manga's grid is infinite-scrolling with a user-configurable card density, which fixed rows would remove. Both recorded in the roadmap so they are not re-proposed.

### Media session: playback in the Android shade and iOS lock screen — 2026-08-30
- **Audio played with no system media session attached**: starting a track and pulling down the Android notification shade showed nothing, so the only way to pause was to return to the app — and with no foreground service, Android was free to kill the process the moment the app was backgrounded.
- Added `MediaSessionService` (`lib/services/media_session/media_session_service.dart`), backed by `audio_service`, which publishes whatever `PlaybackCoordinator` has active to the notification shade, lock screen, Control Center, and Bluetooth/headset buttons — and reflects those buttons back as coordinator calls.
- **The handler deliberately owns no player.** `audio_service` normally *is* the player, but every source here already has its own controller and the coordinator already knows which one is active. So one handler covers music, podcasts and audiobooks at once, rather than each growing a session of its own.
- `PlaybackCoordinator` gained `onNext`/`onPrevious` (plus `canSkipNext`/`canSkipPrevious`). A source with nothing to skip to — a single video, a live channel, a podcast episode — leaves them null and the skip buttons disappear rather than appearing dead. Music forwards them to its queue; audiobooks gained `nextChapter`/`previousChapter`, with the usual "restart the chapter unless you are near its start" behaviour on skip-back.
- The universal play bar shows the same skip pair, so the in-app bar and the shade offer the same controls instead of diverging.
- Android: `MainActivity` now extends `AudioServiceActivity` so tapping the notification returns to the running app rather than starting a second copy; manifest gained the `AudioService` service, the `MediaButtonReceiver`, and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (required from Android 14). iOS already declared the `audio` background mode.
- Initialisation failure is non-fatal — a missing session costs the notification controls, not startup.

### Delete 3,769 lines of unreachable code — 2026-08-30
- Twelve files in `lib/` were imported by nothing. Each had been superseded and left behind rather than removed, so anyone reading the tree had to work out which of two implementations was live:
  - `services/books/epub_parser_service.dart` (1,246 lines) — `pages/read/book_reader_page.dart` parses EPUB inline with `archive` + `xml`; this parallel parser was never wired to it.
  - `pages/downloads/downloads_page.dart` (652) — the Library's own Downloads tab (`collection_page.dart`) replaced it. `utils/platform/open_file_location_helper.dart` was orphaned with it.
  - `widgets/anime/anime_hero_spotlight.dart` (393) — superseded by `BrowseScaffold`'s shared hero.
  - `widgets/player/player_sub_style_bar.dart` (158) — superseded by `player_sub_style_modal.dart`, which the player and settings both use.
  - `services/trakt/trakt_list_source.dart` (329), `services/trakt/trakt_episode_model.dart` (117), `services/simkl/simkl_list_source.dart` (285), `services/simkl/simkl_menu_helpers.dart` (321) — the live Trakt/Simkl paths go through `TraktService`/`SimklService`.
  - `services/books/bookracy_service.dart` (135), `services/anime/anime_stream_service.dart` (35), `models/debrid/debrid_account.dart` (54).
- Dropped `photo_view` (arrived with the upstream engine merge, imported nowhere) and demoted `video_player_platform_interface` to the transitive dependency it already was. `pubspec.lock` shows no other version movement.
- `media_kit_libs_video` and `media_kit_libs_windows_video` stay declared despite never being imported — they exist to pull native assets in, not to be used from Dart.

### One bundle identifier and one product name across all five platforms — 2026-08-30
- **iOS, macOS and Linux still identified the app as `com.example.playtorrio`** — the `flutter create` placeholder — while Android had already moved to `com.mediahub.playtorriomod`. `com.example.*` is reserved for samples, App Store submission rejects it, and it collided with upstream's own builds.
- All five now use `com.mediahub.playtorriomod`.
- The executable inside every bundle was `playtorrio` / `playtorrio.exe`, and the macOS bundle was `playtorrio.app`, which CI renamed to `PlayTorrioMod.app` after the fact. Renamed at the source instead — `BINARY_NAME`, `PRODUCT_NAME`, the Windows `project()` and version resources, the Inno Setup `MyAppExeName`, the AppImage `AppRun` — so the two post-build `mv` steps could go. Windows Explorer's file properties now read `PlayTorrioMod` instead of `playtorrio`.
- iOS `CFBundleDisplayName` was `Playtorrio` and `CFBundleName` was `playtorrio`; both now read `PlayTorrioMod`. The macOS copyright string no longer credits "com.example".
- The Kotlin source package stays `com.example.playtorrio` — it is a namespace, not an identifier anything outside the module sees, and renaming it moves files for no user-visible gain. Documented in `docs/configuration.md` along with a table of where each identity value lives.

### Version 1.1.3, published with a (dev) marker — 2026-08-30
- **The app could report four different versions depending on where you looked**: releases went out as `v1.1.3-alpha.1`/`.2` while `pubspec.yaml` still said `1.1.2+10`, and Settings, Updates and About each fell back to a hardcoded `1.0.6` when `package_info_plus` could not read the platform bundle.
- Dropped the alpha suffix — these are ordinary versions now — and bumped to `1.1.3+11`. `AppInfo` gained `channel` (`'dev'`), `versionLabel()` and fallbacks a test pins to `pubspec.yaml`, so all three screens render `1.1.3 (dev)` from one place. Clear `AppInfo.channel` once a release has been verified on hardware.
- About rewritten from marketing prose into something a tester can act on: a testing-build notice, what the three hubs contain, how content is sourced, and links to the repo, a new issue, and the upstream project.
- `build.yml`: `alpha_tag` → `release_tag`, plus a `dev_build` toggle (default on) that titles the release `(dev)` and publishes it as a prerelease. The Windows installer no longer stamps a branch name as its version on a plain dispatch.

### Unify liked-heart color across content types (AUDIT.md #4) — 2026-08-29
- **The "like" heart used a different color depending on where it appeared**: Music used pink `0xFFFF4B72` and the universal play bar used purple `0xFF7C5CFF`, while Books/Podcasts/Manga/Audiobooks all used red `0xFFE50914` — directly contradicting the ROADMAP's cross-section consistency principle. Unified every liked-heart to red `0xFFE50914` (Music page, music player studio previews, and the universal play bar). The Movies/Series bookmark and Anime status-picker stay as-is — those are library/status concepts, not likes.

### Move credentials into secure storage (AUDIT.md #10) — 2026-08-29
- **Trakt/Simkl access & refresh tokens and the WebDAV cloud-backup password were stored in plaintext `SharedPreferences`** — readable via device/backup access. Now routed through a new `SecureValueStore` (`lib/services/storage/secure_value_store.dart`), a thin wrapper over `flutter_secure_storage` (Keychain/Keystore/Credential Locker depending on platform).
- **Transparent migration**: on first read, a legacy plaintext value under the same key is copied into secure storage and the plaintext copy deleted — existing installs don't lose saved credentials on upgrade. Falls back to plaintext only if no secure backend exists (e.g. a desktop target missing its keychain), so a credential is never silently dropped.
- `StorageService` (Trakt/Simkl tokens) and `CloudBackupSettings` (WebDAV password) now read/write through `SecureValueStore`; non-secret values (URLs, usernames) stay in `SharedPreferences`.
- `MyListService.initialize()` now awaits its initial cloud sync so the My List page's "Syncing…" state resolves deterministically (also fixes a widget-test `pumpAndSettle` hang introduced by the extra async hop in secure-storage reads).
- Added `test/flutter_test_config.dart` with an in-memory `FlutterSecureStoragePlatform` fake so plain `test()`s that reach a secure-storage read don't fail on a missing platform channel.

### Manga staff photos (ROADMAP #2) — 2026-08-29
- **Re-examined the "blocked" reasoning and found a real path**: Anime's cast+staff photos work via an exact AniList numeric id lookup (`fetchAnimeDetails`) — no matching risk at all. Manga has no such id (its catalog comes from a plain HTML scrape, weebcentral.com), so getting photos means fuzzy-matching a title against AniList's separate `type: MANGA` search — the actual risk the ROADMAP flagged, confirmed real via a live AniList query.
- Added `AnilistService.fetchMangaStaff(title)`: searches AniList by title, then only accepts the match if the manga's own title *normalized-exact-matches* (case/punctuation/whitespace-insensitive) one of AniList's romaji/english/native/userPreferred titles — never a "closest guess". Returns `null` (no photos shown, falls back to the existing text-only author) on anything less than a confident match, same risk-averse shape as Books/Podcasts falling back gracefully rather than guessing.
- `MangaDetailsPage` gained a "Staff" row (reusing `AnimeStaff`/`CachedNetworkImage`, same visual pattern as Anime's staff row) between Synopsis and Chapters, loaded async and simply absent when no confident match exists.
- Audiobooks stays blocked on this same ROADMAP item — no equivalent photo source exists for narrators (see ROADMAP for what was checked).

### Closed, unreproducible — mobile section chips overlapping the page search icon — 2026-08-27
- Retested by actually running the Windows build at a resized 390px phone-width window (screenshots via `PrintWindow`, live-driven) across Movies, Audiobooks, and Anime — one page per composition shape. `SectionTopBar` and each page's own icon row sit in separate rows via `SectionedHubScaffold`'s `Column[SectionTopBar(), Expanded(section)]` — no Z-overlap is structurally possible there. The chip strip does clip at 390px (trailing chip cut off, reachable by scrolling) — expected horizontal-scroll behavior, not a collision. Reopen with the exact device/width/font-scale if seen again.

### Merge upstream's fvp/mdk → media_kit+libmpv engine swap (6 commits) — 2026-08-28
- **A materially bigger merge than prior ones**: upstream fully replaced the video playback engine — `fvp`/`mdk` and `libass_plugin` are gone, replaced with `media_kit`/`media_kit_video` (a `Predidit/media-kit` fork adding native libmpv streaming headers). Flagged the scope and risk to the user before proceeding (this touches the single most-used feature, not just additive chrome); they chose full adoption over deferring it. Also bundled in the same commits: a new EPUB→audiobook TTS generation feature (`paper2audio_service.dart`, `custom_audiobook_service.dart`, `generate_audiobook_screen.dart`), torrent streaming/seeking fixes, and player UI polish.
- **`lib/services/stream/local_stream_proxy.dart` is deleted upstream** — its HTTP-header-injection workaround is unneeded now that libmpv sets custom headers natively. Removed its now-dangling references from `WindowService`'s close-shutdown sequence and the old fallback path in `player_screen.dart`.
- **Found real breakage beyond the marked conflicts**: `player_screen.dart`, `iptv_player_page.dart`, `music_player_controller.dart`, and `audiobook_player_screen.dart` each had stale `_controller`/`_videoPlayerController` (the old `VideoPlayerController`/fvp field) references sitting in regions git's 3-way diff never flagged, because only HEAD had touched them (PlaybackCoordinator wiring, the auto-next-episode dialog trigger, the volume-boost drag gesture) while upstream's rewrite left that exact region alone — caught via `flutter analyze` after resolving the actual conflict markers, not by the markers themselves. Adapted each to media_kit's `Player` API instead of dropping the feature; preserved ContinueWatchingService history-resume, the auto-next dialog, and PlaybackCoordinator progress sync (universal play bar) across video/IPTV/music, rewired onto `_player.stream.position`/`.playing` listeners.
- `pubspec.yaml`: dropped `libass_plugin` (native code deleted upstream, mpv's built-in libass supersedes it) for upstream's `photo_view`; pinned `wakelock_plus` back to `^1.3.3` since `media_kit_video`'s git fork pins it there (the `^1.5.2` bump from the earlier dependency cleanup made pub's solver unsatisfiable).
- Verified: `flutter analyze` clean, `flutter test` 139/145 (same 6 pre-existing failures, untouched by this merge), `flutter build windows` succeeds with the new engine, and 3 automated launch/close cycles against the built exe all exit cleanly — the close-crash fix above still holds under the new engine.

### Fix real access-violation crash on Windows app close — 2026-08-28
- **Root cause found and confirmed fixed, not just theorized**: reproduced the "Unknown error" dialog live via an automated close-cycle test (launch the Release exe, `PostMessage(WM_CLOSE)`, watch the process). Windows Event Viewer's Application log showed the real fault every time: `Exception code: 0xc0000005` (access violation) in `flutter_windows.dll` during shutdown. Traced it to `window_manager`'s native `destroy()` (`windows/window_manager.cpp`): it calls `PostQuitMessage(0)` directly, which tears down the Win32 message loop immediately — before the engine's own plugins (video decoder threads, WebView2, etc.) get their normal teardown, racing them into a use-after-free.
- `WindowService._shutdownAndClose()` now calls `setPreventClose(false)` + `windowManager.close()` instead of `destroy()` — `close()` posts a real `WM_SYSCOMMAND/SC_CLOSE`, which re-enters the engine's own `WM_CLOSE → DestroyWindow → WM_DESTROY` chain (the same one a normal close goes through), giving plugins their expected shutdown order. The resulting second `onWindowClose()` re-entry is a no-op via the existing `_isClosing` guard.
- Verified with 3 fresh automated close cycles post-fix: clean process exit each time, zero new WER `Application Error` events (previously: 100% reproducible on every close).

### Merge upstream/main (15 commits), drop dead book-reader dependencies — 2026-08-28
- **Reconciled `ayman708-UX/PlayTorrioV3` upstream onto this fork's hub architecture** (commit `4d522f2`): video player engine settings (decoder presets/buffer resilience), P2P streaming, custom background wallpaper, new scrapers, stremio scheme support, Windows/iOS release tooling — all merged in. Kept our `AdaptiveNavShell`/`HubPage` navigation over upstream's re-introduced HomePage/LiquidDock shell and its duplicate, unrouted `lib/pages/books/` tree; restored `AnimatedAmbientBackground` (six real pages and the new wallpaper feature depend on it) trimmed of the deleted `HomePageSettings` coupling; adopted upstream's richer `PlayerSettings` (decoder/buffer engine) merged with our `autoNextEnabled` toggle; accepted the ~20-file services/utils/models domain-folder reorg. Verified: `flutter analyze` clean, `flutter test` 139/145 (6 pre-existing failures, unrelated to this merge). Full rationale in the merge commit message.
- **Removed `pdfrx`, `dart_mobi`, `fb2_parse`, `flutter_widget_from_html_core` from `pubspec.yaml`**: dead weight left behind by the dropped upstream `books/` tree (its PDF/MOBI/FB2 reader) — nothing in this fork's `lib/` imports any of them; our own EPUB reader (`lib/pages/read/book_reader_page.dart`) and book downloads (always `.epub`, see `BookProgressService`) don't need them. `flutter pub get` also dropped 3 further transitive-only packages (`pdfium_dart`, `pdfium_flutter`, `pdfrx_engine`).

### Add favorites to Books/Podcasts groundwork corrections, Comics addon route ruled out — 2026-08-27
- **Comics (ROADMAP #6)**: checked whether a Stremio-style comics addon could work as a replacement source, per the user's ask. It can't — confirmed via the public addon directory (stremio-addons.net) that Stremio's client has no comics-reader UI at all, so there's no "comics" content type in its addon ecosystem to begin with. Categories there are Movies/Series/Live TV/Torrents/Usenet/Anime/Music/etc. — no Comics. Stays blocked, but now for a clearer reason: this needs a genuinely different distribution model, not an addon search.

### Real genre filter for Audiobooks (ROADMAP #5) — 2026-08-27
- **Better than the Open Library plan first considered**: while verifying that approach (title-matching against Open Library's `search.json` API) a look at AudiobookBay's raw listing HTML found it already carries real genre data in its own `Category: X&nbsp; Y&nbsp;` line — parsed here directly instead. Zero extra network round-trips, no title-matching risk at all (exact data the uploader tagged, not a guess from a title). `Audiobook` gained a `categories` field; `AudiobookBayScraper` extracts and HTML-entity-decodes it per listing (also fixed the existing, unrelated bug where titles kept raw entities like `&#8217;` unescaped).
- `AudiobooksPage` gets a real `FilterDropdown` (matching Movies/Series/Anime's pattern) that narrows the current search results by category — synchronous, no loading state needed since the data's already in hand. The pre-existing "genre" chips (`_categories`/`_selectCategory`) are left as-is: they're honestly just curated search shortcuts (audiobookbay has no browse-by-genre endpoint to back a real chip-based browse), not a filter, so they don't overlap with this.
- Covers AudiobookBay only, one of 8 aggregated scraper sources in `AudiobookScraperService` — results from the other 7 simply won't have a category to filter by, degrading gracefully (they just won't match any genre filter, same as an unfetched item would). New live test `test/audiobookbay_scraper_test.dart` verifies real results carry parsed categories.

### Cloud backup via WebDAV (ROADMAP #8) — 2026-08-27
- **`BackupService` gained a cloud transport**: `uploadToCloud`/`downloadFromCloud` PUT/GET the exact same JSON envelope `export()`/`import()` already write locally, to a WebDAV endpoint the user points at their own server (Nextcloud, etc.) via plain HTTP + Basic Auth — no vendor lock-in, no request-signing dependency to add. Scoped to WebDAV only for v1, not the S3 option also named in ROADMAP: same data, far less code, matches this app's audience (self-hosted-tool users likely already run a WebDAV server) better than adding AWS SigV4 signing for a feature nobody's asked for yet. New `CloudBackupSettings` (URL/username/password, mirrors `TmdbSettings`'s shape) and a "Cloud Backup (WebDAV)" section in `GeneralSettingsPage` alongside the existing local Export/Import, same Connect/Disconnect convention as the TMDB section. Untested against a live WebDAV server — no credentials available in this environment; `export()`/`import()`'s existing test coverage still passes since the envelope-building logic was only extracted into a shared helper, not changed.

### Merge `ContinueWatchingService`/`PlaybackHistoryService` (ROADMAP #2) — 2026-08-27
- **Investigated first (not simple duplication), then merged with the user's go-ahead to verify live.** `ContinueWatchingService` (Home page's "Continue Watching" row) carries saved source/quality/addon info for exact resume without rescraping, syncs to Trakt/Simkl, and deliberately purges anything ≥90% watched — it's "pick up where you left off," not a log. `PlaybackHistoryService` (the old, now-deleted service) was minimal but did **not** purge finished items, and its `getProgress` was also the *only* resume-position fallback when opening the player from any entry point other than the Continue Watching row. It also deduped by episode id, not by show, so multiple episodes of the same show could appear as separate History rows.
- `ContinueWatchingService` gained a second persisted list, `historyItems` — keyed per-episode via a new `_historyKeyOf` (not deduped per-show like `activeItems`), never purged when finished, populated by every `saveProgress()` call alongside the existing per-show `activeItems` write. New `getHistoryProgress(id)` and `removeHistoryItem(item)` cover the two capabilities the old service provided. `CollectionPage`'s History tab now reads `historyItems` instead; `player_screen.dart`'s resume-fallback seek and its old redundant `_onPlaybackUpdate`-based write (a second, less reliable position-based writer duplicating the 5-second timer's job) now both go through `ContinueWatchingService`. `PlaybackHistoryService`/`PlaybackHistoryItem` deleted entirely.
- **Found and fixed a real latent bug along the way**: every `WidgetsBinding.instance.addPostFrameCallback` write in this file (`saveProgress`, `syncCloudSessions`, `removeItem`, and the new `_saveHistoryItem`) relied on some *other* UI activity happening to schedule a frame — with no frame pending, the callback would never fire and the write would silently never apply. Masked in production by ambient rebuilds during video playback, but real; each site now also calls `scheduleFrame()` explicitly. Caught by writing `test/services/continue_watching_service_test.dart` (replaces the deleted `playback_history_service_test.dart`), which failed until this was added.
- Not yet verified on a live device — resume across movie/series/anime/torrent paths needs a manual pass.

### Add favorites to Podcasts (ROADMAP #2) — 2026-08-27
- **Podcasts was the only Listen-hub subcategory with no favorite/subscribe concept**: new `PodcastLibraryService` (mirrors `AudiobookLibraryService`/`BookLibraryService`'s shape). `PodcastResult` gained `toJson`/`fromJson` for persistence. A heart icon in `PodcastDetailsPage`'s app bar toggles the like — the natural spot, matching Audiobooks/Manga's "like lives on the detail page" convention. A new "Podcasts" tab in Music's own Library view (`_buildLibraryView`) shows the liked list alongside Liked Songs/Playlists/Recent, tapping opens `PodcastDetailsPage`.

### Add favorites to Books (ROADMAP #2) — 2026-08-27
- **Books was the only Read-hub subcategory with no like/favorite feature**: new `BookLibraryService` (mirrors `AudiobookLibraryService`'s shape exactly). A heart icon on each `_BookRow` in `books_page.dart` (search results and the "Recently Added" browse grid both use it) toggles the like; a new "Books" tab in `BooksLibraryPage` shows the liked list, matching the existing Audiobooks/Manga tabs. Tapping a liked book resumes reading if it's already downloaded (cross-referencing `BookProgressService`), otherwise points back to Books to search and download it — Books has no dedicated detail page to route to, unlike Audiobooks/Manga, so this reuses the same "file missing" fallback pattern already added for the History tab.

### Surface Anime's watchlist, delete its dead progress tracker (ROADMAP #2) — 2026-08-27
- **`AnimeLibraryService.watchlist` had zero readers anywhere**: the only UI touching it was a status picker on the anime detail page (Watching/Plan to Watch/Completed) — setting a status was a write into a void. Added an Anime tab to the Watch hub's `CollectionPage`, reading `AnimeLibraryService.instance.watchlist`, rendered with the existing `AnimeCard`, routing to `AnimeDetailsPage` (not `DetailsPage`, which expects a `Movie`/`MovieDetail` shape anime doesn't have). Long-press to remove, matching the existing My List/Watchlist tabs' convention.
- Deleted `AnimeLibraryService.updateProgress`/`_progressMap`/`recentHistory`/`getProgress`/`_saveHistory` — confirmed dead, anime resume already runs entirely through the shared `ContinueWatchingService`. Its one caller (`anime_stream_sheet.dart`, on every stream start) was writing placeholder values (`positionSeconds: 1, durationSeconds: 1440`) nothing ever read; removed along with the now-unused `_library` field.

### Fix Read hub Library History tab (ROADMAP #2) — 2026-08-27
- **`BooksLibraryPage`'s History tab was reading the wrong data source**: it pulled from `PlaybackHistoryService`, written to only by the Watch hub's video player (`player_screen.dart`) — never by audiobook or book playback — so the tab was always empty despite being labeled "Audiobooks you listen to will appear here." Rewired to merge the three real, already-working progress sources: `AudiobookProgressService`, `BookProgressService`, and Manga's own continue-reading history, sorted by recency into one list. Resume reuses each subcategory's existing playback/reader entry point (`AudiobookPlayerController.play`, `BookReaderPage`, `MangaReaderPage`); a book whose downloaded file is missing shows a snackbar pointing back to Books instead of replicating the full re-download dialog.

### Nest Genres into Movies/Series and Music (ROADMAP #3) — 2026-08-27
- **Movies/Series**: `TypeCatalogPage` gained a Genre `FilterDropdown` beside the existing decade/sort ones, populated from the same per-type genre aggregation `GenresPage` used to do. Selecting a genre calls `AddonManager.fetchByGenre()`, filters returned sections by `contentType == widget.type`, flattens+dedupes `Movie` items into the list, and composes with the existing decade filter/sort — same combinable-filter pattern Anime's genre filter already uses. The top-level `Genres` chip is gone from the Watch hub (`HubController.currentSections`), `media_hub.dart`'s routing case removed, and the now-fully-unreachable `GenresPage` deleted. `DiscoverPage`'s `isGenre` mode is untouched — it's still reachable from detail-page genre tags, a separate caller.
- **Music**: genre browsing moved from a top-level `Genres` chip to an inline "🎵 Genres" row inside the main Music tab's feed (same spot as Trending Artists/New Releases), reusing the real genre→artist browsing shipped earlier today. Tapping a genre swaps the tab content to the artist grid regardless of which tab was active; the back arrow returns to it. The `Genres` entry is gone from `HubController.currentSections` for the Listen hub, and the now-redundant standalone genre-grid view was folded into the new inline row instead of existing as two destinations for the same data.

### Real Music genre browsing — 2026-08-27
- **Music genre filter, half of ROADMAP #6**: the Listen hub's "Genres" tab (`music_page.dart`) previously showed 12 hardcoded mood tiles whose tap just filled the search box and ran a text search — not real genre browsing. Replaced with `DeezerApiClient.getGenres()`/`.getGenreArtists()`, existing methods (and the `MusicGenre` model) that were already wired to Deezer's real public genre API but had zero call sites anywhere in the app. Tiles now show each genre's actual art; tapping one fetches real artists in that genre and shows them in-place (back arrow to return), tapping an artist reuses the existing, unchanged `_openArtistModal` artist-detail flow. `MusicService` gained a `fetchGenreArtists()` wrapper; its dead, search-hack-based `fetchGenreTracks()` was removed as directly superseded. Radio's identical hardcoded-tile pattern (`_buildRadioView`) was left alone — confirmed separately that it isn't a filterable catalog and a genre filter doesn't apply there regardless of data source.

### Anime director & staff photos — 2026-08-27
- **Director/staff row on anime detail pages (ROADMAP #2, narrowed)**: `AnimeMedia` gained a `staff` field (new `AnimeStaff` model — id, name, image, role), populated from AniList's `staff(sort: RELEVANCE)` edges in `AnilistService.fetchAnimeDetails` — the same GraphQL API already supplying the existing "Characters & Cast" row, just not previously queried for staff. `AnimeDetailsPage` renders it as a new "Staff" row beneath Characters & Cast, shown only when staff data exists.
- Manga and Audiobooks stay out of scope: manga is scraped from plain HTML with only a text author (no photo, and fuzzy-matching titles against AniList carries real mismatch risk); the `Audiobook` model has no author/narrator field at all. Both remain **blocked** on source data — see ROADMAP #2.

### Read-hub section order — 2026-08-27
- **Sorted the Read hub's section chips (ROADMAP #0)**: `HubController.currentSections` for `AppHub.books` now lists Audiobooks, Books, Comics, Manga (alphabetical), Library last — was Manga, Comics, Books, Audiobooks, Library. Default landing section (`_booksSection`) and `BooksHub`'s fallback `switch` case moved from `manga` to `audiobooks` to match the new first chip, same convention the Watch hub already follows (default section = first chip).

### Books browse view + dependency cleanup — 2026-08-27
- **Books section (ROADMAP #2, feasibility confirmed then shipped)**: `BooksService.browseRecent()` scrapes libgen.li's own "recently added" feed (`index.php?req=mode:last&curtab=f`) — verified live to return real, current listings in the same table format `search()` already parses, so the row-parsing logic was extracted into a shared `_parseResults()` instead of duplicated. `BooksPage` shows this as a "Recently Added" grid before a search is performed, closing the last "search-only, no browse view" gap among Read-hub sections.
- Removed `cupertino_icons` and `photo_view` from `pubspec.yaml` — zero usages anywhere in `lib/` or `test/`. `libass_plugin` also shows zero Dart-level usage but is a local packaging shim bundling a prebuilt `ass.framework` for iOS via the Flutter plugin mechanism, not dead code — kept.
- Fixed a duplicate `video_player_platform_interface` import in `player_screen.dart` found during the audit.

### Consistent page-enter transitions — 2026-08-27
- Full inventory of all ~64 `Navigator.push`-family call sites (ROADMAP #2) found most page families were already internally consistent (anime details always `CinematicSlideRoute`, search always `LiquidRevealRoute`, several utilitarian sections deliberately bare) — the actual visible inconsistency was narrower: 4 cases where the *same* target page got a different transition depending on which caller pushed it.
- `IptvPlayerPage`, `SettingsPage`, and `DiscoverPage`: the one bare outlier at each now matches the transition the rest of that target's callers already used (`LiquidRevealRoute` in all three cases).
- `WatchScreen`/`PlayerScreen` launches (11 sites across `continue_watching_service.dart`, `watch_screen.dart`, `magnet_files_view.dart`, `downloads_page.dart`, `search_page.dart`): converged on `CinematicSlideRoute` rather than the prior majority-bare — "start watching" is one conceptual action regardless of entry point (Play button, continue-watching resume, search direct-play, a downloaded file, a magnet link).
- Deliberately left alone: Music, Settings sub-pages, Books, and Podcasts all stay uniformly bare — consistently untransitioned isn't a bug, and whether to add transitions there is a separate design call, not this fix.

### Cleanup — 2026-08-27
- Deleted `lib/models/download/download_item.dart`'s `DownloadItem` — zero references anywhere, superseded by `DownloadTask` when the download manager was rewritten (merged from upstream, see below).
- `AppRadii` (added with the frontend nav-chrome work, previously unused) now has a real consumer: `hub_page.dart`'s content-panel corner radius.
- `AdaptiveNavShell`'s mobile top bar now reuses `SidebarLogo` instead of reimplementing its icon-loading call.
- `TopBar` now reads hub labels/icons from `AppHub.navLabel`/`.navIcon` instead of its own separate hardcoded list — one source of truth instead of two. `TopBar`/`SectionTopBar` also now reference `AppSpacing`/`AppRadii` wherever their existing values actually matched the token scale (16px padding, 12px radius).
- Also deleted the merged-and-stale `upstream-merge-attempt` git branch/worktree from an earlier merge pass.

### Navigation & play bar — 2026-08-27
- **Music detail pages use a back arrow, not a close X**: `_MusicArtistDetailPage`/`_MusicAlbumDetailPage`/`_MusicCuratedPlaylistDetailPage`/`_MusicUserPlaylistDetailPage` are real pushed routes, same as `DetailsPage`/`AudiobookDetailPage`, but used a modal-style close icon. Swapped to the same back-arrow convention every other detail page follows.
- Investigated Radio/Podcasts' missing back button: both are peer-tab switches inside `MusicPage` (same model as Movies/Series/Anime's section chips), not pushed routes — ruled working-as-designed, no back button needed. Books' lack of a browse view (search-only) is a separate, real gap, tracked in ROADMAP.
- **Like button on the universal play bar**: `PlaybackCoordinator.activate()` gained optional `isLiked`/`onToggleLike` callbacks (music tracks only). `UniversalPlayBar` shows a heart whenever the active source supports it, wired to `MusicLibraryService.isTrackLiked`/`toggleLikeTrack`, so a track can be liked without opening the full player.
- **Download button on each source card**: `WatchScreen`'s source-selection list (where a `StreamSource` is already resolved per row before playback) gained a download icon next to the play chevron, calling `DownloadService.startDownload` directly — mirrors the existing in-player download button's dedup/folder-picker/snackbar logic, but lets a user queue a download without opening playback first.

### Fixed — 2026-08-26
- **"Unknown error" dialog on Windows app close**: `WindowService` never intercepted the close event, so the OS killed the process while `LocalStreamProxy`'s loopback HTTP server (and other background services) were still live. Now calls `windowManager.setPreventClose(true)` on init and runs a real shutdown sequence in a new `onWindowClose` handler (`PlaybackCoordinator.stopActive()`, `LocalStreamProxy.instance.stop()`, `TorrentStreamService().stop()`, then `windowManager.destroy()`) before actually closing.

### Merged upstream (round 2) — 2026-08-26
- Reconciled 5 more upstream commits (`d552781`..`18e1910`) into `pr/navigation-cleanup`: a SubtitleCat subtitle provider, a rewritten player keyboard/volume system (arrow-key volume with HUD, mouse-wheel scroll volume, M/space/K/J/L shortcuts, proper text-input passthrough via `Focus` instead of `KeyboardListener`), true borderless OS fullscreen, a new Arabic anime section (`AnimeSearchPage`, `AnimeArabicDetailsPage`, `AnimeArabicStreamSheet`), new anime extractors (AniDB, MegaPlay, ReCloud, TryEmbed, replacing AllAnime/Anikoto/Miruro), a media-title cleaner, `torrent_stream_service`, magnet/stream-link paste detection in search, and updated app icons across platforms.
- Kept our nav architecture over upstream's per-page Home-Page-style chrome (dropped their Floating Glass App Bar and Liquid Dock navbar from `anime_page.dart`/`iptv_page.dart` again); merged rather than replaced where both sides added real, compatible features — our genre filter alongside their Arabic-mode browsing in `anime_page.dart`, our brightness/volume drag gestures alongside their keyboard/scroll-wheel volume in `player_screen.dart`, our `SearchScope` content-type scoping alongside their broader unscoped-search default.
- Caught and fixed a genuine upstream bug via its own new widget test: `AnimeSearchPage`'s `late bool _isArabicMode` was never initialized from `widget.initialArabicMode`, crashing on open.
- Verified clean: `flutter analyze` 0 errors, 141/147 tests passing (6 known pre-existing failures unrelated to this branch), Windows release build succeeds.

### Frontend nav chrome — 2026-08-26
- Added `AppBreakpoints`/`ScreenTier` (mobile/tablet/desktop, 600/900 cutoffs) as the single source of truth for responsive tiers, and `AppSpacing`/`AppRadii` as a shared 8pt-grid token scale — both follow `AppThemeService`'s existing static-service pattern.
- Added `AdaptiveNavShell`: `HubPage` now shows a thumb-reachable bottom tab bar on mobile (matching Netflix/Disney+/Stremio's mobile nav placement) instead of the same top-anchored `TopBar` used on every screen size. Tablet/desktop keep `TopBar` unchanged; the play bar's bottom margin on tablet also tightened from a leftover 76px to the correct 16px it already used on desktop.
- Additive-only pass: no existing service, model, or scraper touched; `TopBar`/`SectionTopBar` reused as-is. Full design and what's intentionally deferred (opportunistic migration of the 52 files with ad-hoc breakpoint checks, restyling `TopBar` onto the new tokens) is in `docs/superpowers/specs/2026-08-26-frontend-design-system-design.md`.

### Merged upstream — 2026-08-25
- Reconciled `ayman708-UX/PlayTorrioV3` main (8 commits since the last merge) with this fork's navigation restructure and everything shipped this session. Brings in: a full Trakt/Simkl cloud-sync rewrite, a download manager with a 5-provider Debrid engine (Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link), an app-wide `AppThemeService` color-palette system, per-content-type player customization (`AudiobookSettings`/`MusicSettings`/`MangaSettings`/`IptvSettings` "player studio" pages), a modularized settings page (401-line hub + category sub-pages, replacing the 1503-line monolith), and various player/scraper fixes.
- Kept our hub navigation, `PlaybackCoordinator` fixes, and this session's UI decisions (volume slider not shuffle, real pages not modals) layered inside upstream's new architecture rather than reverted by it. Dropped the old HomePage/LiquidDock-specific pieces (already removed from our nav) and ~1750 lines of now-dead pre-refactor UI superseded by upstream's own extracted widget files. Full resolution notes and per-file decisions are in the merge commit (`207a779`).
- Verified clean: `flutter analyze` 0 errors, full test suite passes, Windows release build succeeds.

### Fixed
- **Black screen on Windows launch**: the bottom play-bar was built by a `ListenableBuilder` sitting directly as a `Stack` child, returning `SizedBox.shrink()` normally but a bare `Positioned` when the Listen hub was active. Flutter's `Stack` doesn't handle a child flipping between Positioned and non-Positioned across rebuilds; it corrupted the whole window's paint — app was fully built underneath (confirmed via widget-tree dump) but rendered solid black. Fixed by wrapping it in a stable outer `Positioned`.
- Corrupted `scripts/run_windows.bat` (stray characters had mangled `if`/`echo`/`pushd` into invalid batch syntax).
- **Movies and Series showing identical content**: `TypeCatalogPage` only fetched in `initState()`, and switching the Watch section chip reused the same `State` instead of remounting — `widget.type` changed but the loaded list never refreshed. Gave each instance a `ValueKey(type)`.
- **Play bar Stop button didn't actually stop playback**: it reused the same "pause because another source took over" callback as the real Stop action, so the bar hid but the underlying music/audiobook controller kept playing in memory. Added a distinct `onFullStop` to `PlaybackCoordinator`, and a real `stop()` on `MusicPlayerController`/`AudiobookPlayerController` that disposes the controller and releases resources.
- **Anime hub failing to load**: `AnimePage` fetched 8 independent AniList queries through a single all-or-nothing `Future.wait` — any one failure blanked the whole page. Each section now catches its own error and degrades to empty instead of failing the page.
- **Album play/pause button had no animation**: replaced the instant `Icon` swap with `AnimatedIcons.play_pause` via `TweenAnimationBuilder`.
- **Gradle build noise on cross-drive setups**: Kotlin's incremental-compilation cache threw "different roots" errors when the project and pub cache live on different drives (harmless — build still completed — but surfaced as a false error in IDE Gradle integrations). Disabled via `kotlin.incremental=false`.
- **TopBar reading as hidden on detail pages**: it's structurally outside the nested navigator and can never actually be covered, but `DetailsPage`'s background (`0xFF0B0D12`) is nearly identical to the bar's own (`0xFF0B0D15`), separated only by an 8%-opacity 1px border — the boundary was invisible, not the bar. Raised the border contrast and added a drop shadow so it reads as a distinct bar over any page content.
- **Artist/Album/Curated-Playlist/User-Playlist opening as a fixed ~720×640 centered popup** instead of a real screen, inconsistent with every other detail view (`DetailsPage`, `AudiobookDetailPage`). Promoted all four to real pushed pages (`Navigator.push`, `Scaffold`-based). User playlist detail now derives its track list reactively from `MusicLibraryService` instead of holding a stale snapshot, so removing a track updates the page live.

### Live TV
- Added **Live TV** as a new section in the Watch hub (`lib/pages/iptv/`), wired through `HubController` alongside Movies/Series/Anime/Genres/Library.
- Added **multi-view**: a grid-view button in the Live TV app bar picks up to 4 channels and plays them at once, tap a tile to swap audio focus. Deliberately scoped to channels that already have a cached stream URL (`IptvChannelResultsStore`) instead of triggering fresh scans -- `IptvController`'s scan flow only tracks one active channel at a time, and extending that shared singleton to N concurrent scan contexts was a real risk to the existing single-channel flow for a first version. Each tile owns and disposes its own `VideoPlayerController` directly and the grid bypasses `PlaybackCoordinator` (several simultaneous video sources don't fit its single-active-source model), stopping whatever else was playing on entry instead.

### Books
- Added a **Books** section to the Read hub: search libgen.li (a live LibGen mirror, epub-only results), download, and read in-app. Ported from `ayman708-UX/PlayTorrioV2` (`books_service.dart`, `book_progress_service.dart`, `book_reader_screen.dart`) and restyled to match V3. The reader unzips the epub once, parses the OPF manifest/spine into a chapter list, and loads each chapter's own HTML file into a webview via a `file://` URL so relative image/CSS references resolve naturally. Chapter/scroll progress persists so "Continue Reading" survives restarts. New deps: `flutter_inappwebview`, `xml`; verified `flutter_inappwebview` actually compiles and links on Windows desktop via a full release build before landing, since webview plugins are historically the least reliable thing on that platform. V2's "focus mode" (one-line-at-a-time reading overlay) was left out as a scope cut for a first version.

### Podcasts
- Added a **Podcasts** section to the Listen hub: search via the iTunes Search API (free, no key) for discovery, then read episodes straight from each show's own RSS feed -- the standard way every podcast app sources audio. `PodcastPlayerController` mirrors `AudiobookPlayerController`'s `PlaybackCoordinator` wiring but simpler (one episode at a time, no chapters). PlayTorrioV2 has no podcast feature at all, so this is an original build, not a port.

### Backup & Restore
- Added **local JSON export/import** for user data (Settings → Backup & Restore): reads/writes the entire `SharedPreferences` store as one flat, versioned JSON file, so no per-service serializer was needed for the ~15 independent services that hold user data. Envelope schema is deliberately transport-agnostic so cloud sync later is a matter of shipping the same JSON elsewhere.

### Filters
- Added a **decade filter + sort dropdown** (Title A–Z/Z–A, Newest, Oldest) to the Movies and Series catalogs (`TypeCatalogPage`, shared by both). Decade options are derived from whichever years are actually present in the loaded catalog, so the dropdown never offers an empty result.
- Added a **genre filter to Anime**: picking a genre swaps the curated homepage rows for a single filtered grid (via `AnilistService.fetchByGenre`); picking "All Genres" reverts to the curated rows untouched. Extracted the filter dropdown button into a shared `lib/widgets/common/filter_dropdown.dart` used by both Movies/Series and Anime.

### Navigation
- **Moved Audiobooks from Listen to Read.** `AppHub`'s own doc comment already said Audiobooks belonged in the Read hub -- it had just drifted into Music's section list during the restructure. Now a real Read hub section (Manga, Comics, Audiobooks, Library) instead of nested inside the Music page's own tab switch.

### Cast
- Added **TMDB cast enrichment**: photos and character names for movies/series when an addon only supplies plain name strings, using the user's own free TMDB API key (Settings → TMDB). No-ops entirely with no key configured, and skips the network call when the addon's own cast data already has photos.

### Architecture
- `CollectionPage` now builds on the shared `LibraryTabs`/`LibraryEmptyState` widgets instead of hand-rolling its own `TabController`/`Scaffold`/`AppBar`/`TabBar` and empty-state layout, matching `BooksLibraryPage`. Also removed a dead leftover back button (`HubNavigator.goHome()`) from before the navigation restructure -- it re-selected the hub the page was already embedded in, a functional no-op, and no other Watch hub section has one.
- Extracted `_MusicModalShell` (the dimmed-backdrop + glass panel wrapper) out of all four music detail modals (Artist/Album/Curated Playlist/User Playlist) -- they were hand-duplicating that ~15-line shell exactly. Left each modal's actual header/body alone since the Artist modal's banner header is genuinely different from the other three's row header, rather than forcing all four into one over-parameterized widget.
- Extracted a `HorizontalSliderScroll` mixin out of `MovieSliderSection`/`IptvSliderSection`'s duplicated scroll-arrow logic, and found `MovieSliderSection` had its own private `_SliderArrow` -- a byte-for-byte duplicate of the already-shared `common/slider_arrow.dart` that `IptvSliderSection` was already using. Removed the duplicate and fixed that shared widget's deprecated `withOpacity()` calls now that it's the single canonical copy.
- Extracted `InteractiveCardShell` out of `MovieCard`/`IptvChannelCard`'s identical hover/press interaction physics (170ms easeOutCubic scale + lift, same everywhere but the press-scale value). Both cards no longer need their own hover/press state, so both went from `StatefulWidget` to `StatelessWidget` as a result.
- Extracted a `HeroCarouselAutoRotate` mixin out of the anime and IPTV hero carousels' duplicated `PageController` + auto-rotate `Timer` bookkeeping (pause-on-hover, advance-on-interval, dispose). Left height formulas, arrow-button styling, and desktop-detection strategy alone -- those are genuine per-carousel design differences, not copy-paste duplication -- and kept rotation interval/animation duration/curve as caller-supplied parameters so each carousel's exact existing feel was preserved.
- Extracted `SectionedHubScaffold` out of `MediaHub`/`BooksHub`'s identical `Scaffold > Column[SectionTopBar(), Expanded(section)]` shell + `HubController` listener wiring. Left `MusicHub`/`music_page.dart` alone -- its body is a `Stack` carrying ambient background glow, a keyboard listener, and drawer/modal overlays, a genuinely different shape, not a copy of this one -- and fixed `MusicHub`'s doc comment, which still described a sidebar/bottom-nav layout removed earlier this session.

### Player
- Trimmed the player down to standard controls: removed the Stop button from the bottom play bar and the Shuffle toggle from the expanded music player, added a volume slider (there was previously no volume UI at all, only a keyboard mute shortcut) in Shuffle's old spot. Previous/Play-Pause/Next/Repeat unchanged.
- True-centered the Watch/Listen/Read tabs in the top bar (`Stack` with the logo pinned left, tabs centered via `Center()`, Settings pinned right) -- they previously sat wherever a `Spacer()` pushed them, off-center relative to the window.
- **Search integrated into Music** instead of sitting as its own chip among content categories in the Listen hub's section bar. Music's search stays inline (its own tab/text field, not a pushed page like other hubs) -- only how you reach it changed, via a search icon next to the section bar.

### Navigation — global top bar + section chip bar
- Added a slim global **TopBar** (logo + **Watch / Listen / Read** hub switcher + a **Settings** button) pinned to the top of the window, so the app icon stays visible on every hub.
- **Removed the per-hub left sidebars** (Media, Books, Music) — they duplicated the section chip bar. Section switching is now done entirely by the **Section top bar** (horizontal chips) under the TopBar.
- Hubs renamed to verbs: **Watch** (Movies, Series, Anime, Genres, Library), **Listen** (Music, Search, Genres, Radio, Audiobooks, Library), **Read** (Manga, Comics, Library).
- **Audiobooks** moved from Read into Listen; the Listen chip order is Music, Search, Genres, Radio, Audiobooks, Library.
- The Listen home section is **Music**, so it reads cleanly as **Listen › Music** (matching **Watch › Movies**).
- **Removed the mobile bottom section-navs** (Media, Books, Music) — the global TopBar + Section chip bar now substitute them on all screen sizes.
- Added a **Section chip bar** — a horizontal bar at the top of every hub's content area for switching sections.
- Search is **per-page/scoped**: Movies/Series, Genres, Manga, Anime, Music, and Audiobooks each own a scoped search entry point; Music also gained a real search field.
- Movies and **Series now show different, correctly-typed content** (item type from addon, falling back to the catalog type, filtered on read).
- Fixes: Anime back button, no stray back buttons on top-level sections, consistent detail-page behavior (inline via nested navigator), consistent player expand/fullscreen.

### Navigation & Hub Architecture
- Shared TopBar + AppDock hosted in a single HubPage container (IndexedStack).
- Restructured to 3 content hubs — Media (Movies/Series/Anime), Books (Audiobooks/Manga), Music — each with a left sidebar and contextual collection.
- Settings moved to the TopBar gear icon (no longer a dock hub).
- TV D-pad keyboard navigation: arrow keys move focus between hubs, Enter/Space activates, visible focus ring.
- TV remote Back/Exit (Escape) pops the current route.
- TopBar and AppDock hidden during the intro splash.
- Back button on hub pages returns to the primary "Movies & Series" hub (no black screen).

### Player
- Volume & brightness swipe gestures: vertical swipe on left half = volume, right half = brightness, with on-screen indicator.
- Auto-Next Episode dialog: end-of-credits detection, 10s countdown, Play Next / Cancel, auto-play next episode.
- New PlayerSettings service with persisted Auto-Play Next toggle in Settings.
- Keyboard focus management: Space = play/pause, arrows = seek, M = mute, F = aspect, Esc = back.
- Screen-reader (Semantics) labels on all player control buttons.
- **Live progress bar** in the bottom play bar (Listen) and the expanded now-playing player (progress/seek stay in sync during playback).

### Collection & Services
- Unified Collection hub consolidating My List, Watchlist, History, and Downloads.
- Debrid integration (Real-Debrid, Torbox) with token verification in Settings.
- Download service with persistent queued state.
- Playback history service for continue-watching.
- Rich cast & crew with TMDB headshots.
- Trakt scrobbling and sync.

### Desktop
- Minimum window size enforced on Windows and macOS to prevent layout collapse.

### Playback Coordination
- New global `PlaybackCoordinator` ensures only one source plays at a time across music, video, and audiobooks — starting any playback stops the others.

### Global Shortcuts
- Music transport shortcuts (Space/K, J, L, M) now work app-wide via a new `GlobalShortcuts` wrapper, not just inside the Music page.

### Media Hub
- New **Genres** section in the Media sidebar aggregates genres from all active addons and lets you browse by genre.

### Search
- Search is now scoped to the currently selected section (Movies, Series, Anime, etc.) via a `SearchScope` registry, with a scoped hint and empty-state label.

### TV / Remote
- Pressing **Tab** focuses the bottom dock from anywhere, giving TV remotes an easy way to reach the hub switcher without scrolling through content.

### Navigation & Library
- Bottom dock reordered to **Media – Music – Books**.
- "My Collection" renamed to **Library** across hubs.
- Books hub now has its own **Library** showing liked manga and liked audiobooks.
- Like buttons added to manga and audiobook detail pages (persisted locally).
- Escape no longer pops the root HubPage (prevents black screen); it only pops when a route exists.
- Music album/playlist/artist modals now reflect live play/pause state on their play buttons and track rows.

### Universal Play Bar
- New **universal play bar** shown across all three hubs (Media, Books, Music) above the dock.
- Reflects whatever is currently playing (music, video, or audiobook) with cover, title, subtitle, play/pause, and stop controls.
- Tapping the bar expands the full music player; the Music page's old floating mini-player was removed to avoid duplication.

### Navigation & Search Polish
- Music sidebar title no longer hidden behind the shared TopBar (added top padding).
- Music sidebar/mobile nav now clears active search when switching tabs, so Browse/Radio/Library actually navigate (previously the search view blocked them).
- TopBar search placeholder is now dynamic per section (e.g. "Search Movies...", "Search Music...").
- Audiobooks section no longer shows its own title/search bar (search is handled by the parent section).
- Genres page filters out year-like entries (e.g. "2024") so only real genres are shown.
- New shared `LibraryTabs` component; Books Library now uses it with Manga / Audiobooks / History tabs.

### Unified Header & Navigation
- Replaced the logo + search-bar TopBar with a new **AppHeader**: three hub buttons (Media / Music / Books), a section dropdown, a search icon, and a settings icon.
- Removed the PlayTorrio logo/name from the header; the active section name is shown via the dropdown.
- Removed the per-hub mobile bottom navs (Media, Books, Music); section switching now happens in the header dropdown.
- Added a shared `HubController` so the header, sidebars, and hubs stay in sync.
- Repositioned the bottom dock: on mobile it appears at the top (below the header); on desktop it stays at the bottom, offset right so it never overlaps the left sidebar.
- ROADMAP updated: removed completed tasks, added full liquid-glass theming as a future task.

### Header Refinement
- Restored the **PlayTorrio logo + name** at the top left of the header.
- Removed the section dropdown from the header (sections are switched via the left sidebar).
- Removed the old bottom dock entirely; hub switching is now done via the header hub buttons.
- Search is now an **input bar** in the header, next to the hub buttons.
- Page content now renders inside a dedicated box between the header and the left panel, so it never overlaps either.

### Cleanup & Responsive Header
- Removed unused `AppDock` and `LiquidDock` widgets; moved the `AppHub` enum to its own file.
- Fixed the extra black gap on the left (content no longer double-offsets past the hub's own sidebar).
- Restored mobile bottom section navs for Media, Books, and Music.
- Books Library tabs reordered to **Audiobooks, Manga, History**.
- Header is now responsive: on mobile it shows an icon logo, a hub dropdown, and a search icon; on desktop it shows the full logo, hub buttons, and a search input bar.

### Inline Detail Pages & Cleanup
- Removed the per-page search/settings headers from the Music page (now covered by the global header).
- Added a **Shortcuts** button to the Media and Books left sidebars (Music already had one).
- Each hub now runs in its own nested `Navigator`, so detail pages (movies, artists, albums, manga, etc.) render **inside the content area** — keeping the left sidebar and top header visible — instead of taking over the full screen or appearing as popups.
- Fullscreen playback (video, book, song with cover) still uses the root navigator as before.

### Music Library & Play Bar
- Music Library now uses the shared `LibraryTabs` design with **Liked Songs / Playlists / Recent** tabs, matching the Media and Books libraries.
- Universal play bar repositioned: on desktop it sits above the bottom offset right of the left sidebar; on mobile it sits above the bottom section nav (no overlap).
- Added a **close** button to the universal play bar (dismisses the bar without stopping playback).
- Fullscreen playback (video player, audiobook player, manga reader) now explicitly uses the root navigator so it opens fullscreen only when actually inside the content.

### Background Audiobook Playback
- Audiobooks now start playing in the **background** from the detail page and "continue listening" — the bottom play bar appears instead of a fullscreen player.
- Tapping the bottom play bar opens the fullscreen audiobook player.
- Added a singleton `AudiobookPlayerController` for background playback.
- Single-source playback is enforced app-wide via the `PlaybackCoordinator` (never multiple audios/videos at once).

### Inline Detail Pages & Cleanup
- Anime details now render **inside the content box** (maintaining the lateral panel) instead of as a centered popup.
- Removed the anime page's internal logo/search/settings header (now covered by the global header).
- Movies and Series sections now set the correct content type on each item, so series are treated as series (not movies).

## [0.0.2] — 2026-08-11

### Added
- Stremio-compatible addon protocol with catalog browsing, search, and metadata enrichment
- 9 VOD stream scrapers (FlyStream, Videasy, VidSrc, MultiEmbed, VidCore, 4KHDHub, XDownloader, Knaben, TorrentGalaxy)
- Native libtorrent streaming engine with intelligent file selection and real-time stats
- 9-source audiobook aggregator with torrent and direct streaming support
- WeebCentral manga reader with horizontal/vertical modes, zoom, and progress tracking
- Octave music streaming with library management, playlists, and keyboard shortcuts
- Subdl subtitle download and extraction with multi-language support
- Glassmorphism UI system with GPU shader effects and performance fallback toggle
- Custom route transitions (LiquidRevealRoute, CinematicSlideRoute)
- Responsive card layout adapting to phone, tablet, and desktop widths
- macOS-style liquid dock navigation
- 5-platform support (iOS, macOS, Android, Linux, Windows)
- Audiobook sleep timer and variable playback speed
- "More Like This" recommendations via BestSimilar scraper
- Search relevance scoring with exact-match-first ranking
- Progressive content loading across all sections