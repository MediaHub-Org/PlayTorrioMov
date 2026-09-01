# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in the GitHub release notes;
this file stays about what is left.

Last reconciled against the tree: **2026-09-02** (v1.1.3+11, dev channel).
Forked from `MediaHub-Org/PlayTorrioMod` on 2026-08-31; first manual
Media-domain port from there done 2026-09-02 (see below).

**Ported 2026-09-02** from PlayTorrioMod's own same-day work: Details pages
no longer block hub pill/bottom-bar navigation (a pushed detail page's
`NestedNavigator` now pops to root when the active section changes — adapted
here for the single-hub shape, one navigator instead of three); Library's
Saved tab dropped the heart icon (`Icons.inventory_2_rounded`) and its
History tab (Continue covers the same ground without the duplicate row
list); Anime's language toggle became a flag+name `FilterDropdown`; Anime's
hero carousel shrunk from up to 920px tall on desktop to Live TV's ~560px
range; Movies & Series' hero now reads the addon's own `background` field
instead of force-cropping the portrait poster. **Not ported**: the
Watchlist/Watched split (item 8 below) — PlayTorrioMod's own version of that
turned out to depend on an `isWatched` field and status-picker UI that
predates this fork and was never ported either, so it needs that
prerequisite first, not just today's chip change.

## Sibling app: PlayTorrioMod

This app is a Media-only fork of `MediaHub-Org/PlayTorrioMod` (Movies &
Series, Anime, Live TV, Library — Music and Books removed, better served by
dedicated apps). PlayTorrioMod stays the primary development repo and keeps
tracking its own upstream (`ayman708-UX/PlayTorrioV3`); this app gets
Media-domain changes ported over from there manually, not by `git merge` —
the two repos' navigation shapes no longer match (PlayTorrioMod: three hubs
switched by `AppHub`; this app: the single hub below, `AppHub` doesn't
exist here), so a straight merge would not apply cleanly even if attempted.

**Resolved 2026-09-01: `MediaSessionService` restored.** Forking out
Music/Books had also deleted it, but it turned out to be generic — it
mirrors `PlaybackCoordinator` for *any* playback source, not
Music-specific — so video playback here had lost its Android/iOS
lock-screen, notification and Bluetooth media controls for no reason tied
to the actual fork goal (dropping Music/Books content, not video
infrastructure). Re-added `audio_service`, the service file (identity
strings adjusted for this app), the Android manifest's
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission + `AudioService`/
`MediaButtonReceiver` entries, and iOS's `audio` background mode.
`flutter analyze` clean, `flutter test` 196/196 passing.

## Navigation principle

One hub, four sections, the fourth always Library:

| Section | Content |
|:--|:--|
| **Movies & Series** | TMDB-catalog movies and series, one tap apart |
| **Anime** | Its own catalog and scraper |
| **Live TV** | IPTV channels |
| **Library** | Everything you've saved |

Phones show sections in the bottom tab bar; tablet and desktop show them as
a chip row under the top bar. Search stays an icon, not a section — it's an
action reachable from anywhere, not a place to browse, and doesn't compete
for the same scarce nav real estate the four sections above use.

There used to be three hubs here (Watch/Listen/Read, à la PlayTorrioMod) —
the hub-switching machinery (`AppHub` enum, hub-pill nav) was deleted
outright when Music and Books were forked out, not left around as a
one-branch abstraction. Any proposal to bring back multiple hubs should be
weighed against why they were removed (see the fork's design spec under
`docs/superpowers/specs/`), not just re-added by habit.

## Blocked on a device

Nothing in this group can be closed from CI. Every item is implemented and
passing `flutter analyze` + the test suite; none has been run on hardware.

| # | Area | What specifically needs checking |
|---|------|-----------------------------------|
| 1 | **media_kit/libmpv playback** | Torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture. Needs a hands-on pass across movie / series / anime / IPTV. The `mediacodec-copy` fix for the Android black screen is part of this. |
| 2 | **Resume across sources** | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths is unconfirmed on a device. |
| 3 | **QA on all five platforms** | Mobile, tablet, desktop, TV. TV needs its own D-pad/remote-input pass. Most work to date has only been exercised on Windows desktop and in CI. |

Once a build has actually been through this, clear `AppInfo.channel` and the
`(dev)` marker disappears from the app and from release titles.

## Code and consistency

| # | Task | Why it is still open |
|---|------|------------------------|
| 4 | **Anime and Movies/Series now share one row; the pages still differ** | The row is done: `BrowseRowView` is the single implementation, `BrowseScaffold` builds its rows from it and `AnimeSliderSection` wraps it, so card size, spacing, header and arrows cannot drift. Migrating the anime *page* itself onto `BrowseScaffold` was **dropped as not worth it**: `AnimeSliderSection` is also used by `anime_search_page`, so converting only the anime page would leave two row implementations on adjacent screens — worse than before. Converting both is two large pages of churn for a layout that now already matches. What the anime page still has of its own is a hero carousel and a `ContinueWatchingSlider` slot; revisit only if a third page wants that arrangement. |
| 5 | **Some files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | Inherited from PlayTorrioMod's own count of 35 call sites — likely fewer now that the Music/Books files carrying some of them are gone, exact count not re-audited. No shared risk, no user-visible bug. Migrate opportunistically when a file is touched for another reason, not as a batch pass. |
| 6 | **Kotlin Gradle Plugin will break future Flutter builds** | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit. |

## Known bugs

| # | Bug | Notes |
|---|-----|-------|
| 7 | **"Unknown hard error" on Windows after closing the app** | Reported against PlayTorrioMod 2026-08-31 (see its own `ROADMAP.md`). Unconfirmed here specifically, but this app shares the same Windows runner code, so worth checking once PlayTorrioMod's is root-caused. |

## Requested UI work

| # | Task | Notes |
|---|------|-------|
| 8 | **Icon-button consistency, plus a Watchlist/Watched pair** | Requested 2026-08-31 (against PlayTorrioMod, applies equally here). The heart/like icon (`LikeButton`, `lib/widgets/common/like_button.dart`) is already unified — see its own doc comment. What's being asked now is broader: audit every content-action icon button (like, add-to-library/bookmark, watchlist, watched) for one consistent visual language, and add a distinct Watchlist ("plan to watch") vs. Watched (completed) pair for Movies & Series — today it only has the single "Add to Library" bookmark toggle, while Anime already has a four-state picker (Watching/Plan to Watch/Completed/Dropped). Needs a short design pass before implementation: is Watchlist/Watched a third state bolted onto the existing Library bookmark, or a separate concept end-to-end? |
| 9 | **Remove A-Z title sort on Movies & Series** | Requested 2026-08-31. Find the sort control on `TypeCatalogPage`/`FilterDropdown` and drop the alphabetical option, keeping whatever the remaining sort choices are (e.g. popularity, release date, added date). |
| 10 | **Header space consistency between "Live TV" and "Movies & Series"** | Requested 2026-08-31. The two sections apparently don't share identical header/app-bar spacing or layout today. Needs a side-by-side comparison of both pages' header widgets before deciding whether to extract a shared header component or just align paddings/sizes independently. |

## Signing and releases

- **Android release signing needs two repository secrets** — `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`. Until they exist, every build is signed with a throwaway debug key, which means each new APK refuses to install over the last one and the in-app updater cannot work. See [release signing](configuration.md#release-signing). The keystore must be generated locally: it is a long-lived credential and should not pass through a chat transcript or CI logs.
- **No other platform needs signing for updates**, because none of them self-install. See the table in `configuration.md`.

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now. Bringing back a drawer, pill row, or hub+submenu component for hub-switching solves a problem this app doesn't have. If a second hub is ever proposed, that is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** `PlaybackCoordinator` already covers video generically; there's no second controller type to unify against here (unlike PlayTorrioMod, which also had music/audiobook controllers).
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees — see `docs/configuration.md`.
