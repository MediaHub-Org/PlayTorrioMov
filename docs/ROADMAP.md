# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and the GitHub release notes; this file stays about what is left. Day-to-day
task tracking lives in [TASKS.md](../TASKS.md); this file is the longer arc.

Last reconciled against the tree: **2026-09-05** (v1.1.6+14).

## Relationship to PlayTorrioMod

PlayTorrioMov forked from
[`MediaHub-Org/PlayTorrioMod`](https://github.com/MediaHub-Org/PlayTorrioMod)
on 2026-08-31 (Movies & Series, Anime, Live TV, Library — Music and Books
removed, better served by dedicated apps). It has since become the **primary
app of the two**: the smaller, watch-only codebase is easier to keep
consistent and has been working well. PlayTorrioMod remains a sibling app
(and stays the primary consumer of upstream `ayman708-UX/PlayTorrioV3`) but
is no longer the source of truth for this repo's docs, roadmap, or
direction — those live here now. Anything worth carrying over from either
app gets ported deliberately, not by `git merge` — the two repos'
navigation shapes don't match (PlayTorrioMod: three hubs switched by
`AppHub`; this app: the single hub below, `AppHub` doesn't exist here).

## Navigation principle

One hub, four sections, the fourth always Library:

| Section             | Content                                       |
|:--------------------|:----------------------------------------------|
| **Movies & Series** | TMDB-catalog movies and series, one tap apart |
| **Anime**           | Its own catalog and scraper                   |
| **Live TV**         | IPTV channels                                 |
| **Library**         | Everything you've saved                       |

Phones show sections in the bottom tab bar; tablet and desktop show them as
a chip row under the top bar. Search stays an icon, not a section — it's an
action reachable from anywhere, not a place to browse, and doesn't compete
for the same scarce nav real estate the four sections above use.

There used to be three hubs here (Watch/Listen/Read, à la PlayTorrioMod) —
the hub-switching machinery (`AppHub` enum, hub-pill nav) was deleted
outright when Music and Books were forked out, not left around as a
one-branch abstraction. Any proposal to bring back multiple hubs should be
weighed against why they were removed, not just re-added by habit.

## Upstream tracking

Git history was squashed at the fork point (`cc3a1b3`) — Mov shares no
git ancestry with PlayTorrioMod, so nothing arrives here via `git merge`.
Everything below is a deliberate, file-by-file port, checked each time
against how far Mov's own scraper/player/continue-watching code has already
diverged from both PlayTorrioMod and its own upstream, `ayman708-UX/PlayTorrioV3`.

As of 2026-09-03, PlayTorrioMod's `main` sat 3 commits behind `v3/main`.
All 3 have since been reconciled (merged for real in PlayTorrioMod, ported
file-by-file here in Mov — see [PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod)
for its own log). **Last commit actually merged into Mov: `b0aecf5`** —
`9d34d4c` carried no portable content (V3's own README).

| Commit    | Summary                                              | Status                                                                                                                     |
|-----------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `cc07994` | Fix anime catalog AniList 403 issue, bump 1.1.1        | **Merged.** `anilist_service.dart` now sends a browser User-Agent/Origin/Referer and a 15s timeout. The paired `anime_page.dart` empty-results error message already existed independently in Mov. |
| `b0aecf5` | New scraper sources, fix mapple scraper, bump 1.1.2    | **Merged (side by side).** 30 new scraper sites and 7 new anime extractors added alongside Mov's existing, non-overlapping set; new `video_settings_page.dart`; anime/continue-watching/player diffs reviewed file-by-file rather than patch-applied, since those files had already diverged. Mov's own `StreamHealthChecker` dead-stream filtering was kept — V3 had dropped its equivalent, not carried over. |
| `9d34d4c` | Update README                                         | **Not merged, by design.** V3's own README, not relevant here.                                                             |
| `ad0e40d` | Bump 1.1.3: audio dub & language filtering, backend scraper extractions, responsive UI | **In progress.** 22 files, +1555/−148: a ~1080-line rewrite of `watch_screen.dart` (audio-track/dub language picker, responsive layout), a further `stream_model.dart` extension, and touch-ups to several scraper sites — including `movy.dart`/`vuflix.dart`/`xdownloader.dart`, which are *not* from the b0aecf5 port; Mov already carries its own independently-evolved copies of those three from before the fork. |
| `6c4d0cf` | fix(player): streamline stream error filtering and health verification | **Mostly a non-issue here.** Re-adds a dead-stream health check V3 itself had dropped in `b0aecf5` and then found it needed back — Mov never dropped it, so that hunk is already equivalent. Real content for Mov: `PlayerSettings.isNonFatalError` refinement, `PlayerScreen._onControllerError` fix, Dulo referer/domain-priority fix, VidRock JSON-playlist parsing fix, new CDN referer resolver rules. Skips the `audiobook_player_screen.dart`/`music_player_controller.dart` hunks — Mov has neither. |
| `f1f1310` | Add full Stremio catalog-extra handling and collection addons support | **In progress — large.** 14 files, ~2000 lines: a real `AddonCatalogExtra` model (required/optional extras, options, limits), a much bigger `discover_page.dart` (Mov's is 182 lines pre-merge vs. this diff's +1145), Stremio collection-addon support (e.g. TMDB Collections, "Movies in Collection" UI), `metadata_service.dart`/`addon.dart`/`catalog_page.dart` extensions. Skips the `dock_settings.dart`/`app_liquid_dock.dart`/`home_page.dart` hunks outright — those are V3's three-hub dock nav, which this app doesn't have (see § Navigation principle); the Discover-nav wiring needs to land in Mov's own nav shell instead. |

This table gets re-checked whenever PlayTorrioMod's upstream gap is
revisited; it is a snapshot, not a live sync status. Re-fetch `v3/main`
before trusting "last merged" as current — upstream moves.

## Blocked on a device

**Cleared 2026-09-03** — `AppInfo.channel` is now empty, the `(dev)` marker
is gone from the app and release titles, and `v1.1.6` shipped as a full
(non-prerelease) release on that basis. The three items below are kept as a
record of what that clearance covers; reopen (set `channel` back to `'dev'`)
if a regression in any of them turns up.

| # | Area                          | What was checked                                                                                                                                                                                                    |
|---|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | **media_kit/libmpv playback** | Torrent streaming, live IPTV, subtitle rendering, decoder presets and the volume-boost gesture, across movie / series / anime / IPTV. The `mediacodec-copy` fix for the Android black screen is part of this. |
| 2 | **Resume across sources**     | `ContinueWatchingService` absorbed `PlaybackHistoryService`. Resume across movie / series / anime / torrent paths. |
| 3 | **QA on all five platforms**  | Mobile, tablet, desktop, TV, including TV's D-pad/remote-input path. |

## Code and consistency

| #  | Task                                                                                                | Why it is still open                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|----|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 4  | **Anime and Movies/Series now share one row; the pages still differ**                               | The row is done: `BrowseRowView` is the single implementation, `BrowseScaffold` builds its rows from it and `AnimeSliderSection` wraps it, so card size, spacing, header and arrows cannot drift. Migrating the anime *page* itself onto `BrowseScaffold` was **dropped as not worth it**: `AnimeSliderSection` is also used by `anime_search_page`, so converting only the anime page would leave two row implementations on adjacent screens — worse than before. Converting both is two large pages of churn for a layout that now already matches. What the anime page still has of its own is a hero carousel and a `ContinueWatchingSlider` slot; revisit only if a third page wants that arrangement. |
| 5  | **Some files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | Inherited from PlayTorrioMod's own count of call sites — no shared risk, no user-visible bug. Migrate opportunistically when a file is touched for another reason, not as a batch pass.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 6  | **Kotlin Gradle Plugin will break future Flutter builds**                                           | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit.                                                                                                                                                                         |
| 10 | **Header space consistency between all sections**                                                   | Live TV, Movies & Series, Anime and Library don't share identical header/app-bar margin and padding today. Tracked as a near-term item in [TASKS.md](../TASKS.md).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|----|-----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7  | **"Unknown hard error" on Windows after closing the app** | Root-caused: a native window close never runs the widget tree's own `dispose()`, so `PlayerScreen`/`IptvPlayerPage`'s media_kit `Player` stayed alive into process teardown. Candidate fix shipped (`PlaybackCoordinator.disposeForShutdown()` + `onShutdownDispose`, `WindowService` calls it on close) — see [CHANGELOG.md](../CHANGELOG.md). **Not yet empirically verified** — no way to drive the UI to start real playback and then close over it in this environment; confirmed only that a real `WM_CLOSE` with no active player exits clean. Needs a hands-on close-while-playing-video check. |
| 12 | **Tags on content pages only show their icon**            | The label doesn't fit the available width; tracked in [TASKS.md](../TASKS.md). Still unlocated — no widget matching "icon-only, label overflows" turned up on a source read; needs a screenshot or on-device repro rather than a guess.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

## Requested UI work

Nothing open here right now — see Resolved below for #9.

## Resolved

- ~~**Icon-button consistency, plus a Watchlist/Watched pair**~~ — shipped:
  Watchlist / Watched / Like three-state buttons for Movies & Series (see
  [CHANGELOG.md](../CHANGELOG.md)).
- ~~**#9 Remove A-Z title sort on Movies & Series**~~ — already true on the
  tree: `TypeCatalogPage`'s `_CatalogSort` enum only has `yearNewest` /
  `yearOldest`, no alphabetical option exists to remove. Item was stale.
- ~~**#11 Android back button**~~ — root-caused: `NestedNavigator` (the
  Navigator that hosts pages pushed from within the hub content area) was a
  plain `Navigator`, which never sees the Android system back gesture —
  that goes to the root Navigator, which had nothing to pop while a page
  was pushed in the nested one, so back exited the app instead. Fixed by
  wrapping it in `NavigatorPopHandler`, Flutter's own solution for this
  exact nested-Navigator case; covered by a widget test
  (`test/widgets/nested_navigator_test.dart`) that fails without the fix.

## Signing and releases

Android release signing needs two repository secrets and is what lets the
in-app updater replace an existing install — see
[release signing](RELEASES.md#release-signing). Without them builds still
succeed, signed with a throwaway debug key. No other platform needs signing
for updates, because none of them self-install — see the table in
[RELEASES.md](RELEASES.md#other-platforms).

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now. Bringing back a drawer, pill row, or hub+submenu component for hub-switching solves a problem this app doesn't have. If a second hub is ever proposed, that is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** `PlaybackCoordinator` already covers video generically; there's no second controller type to unify against here (unlike PlayTorrioMod, which also had music/audiobook controllers).
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field, ~88 mostly-minor channels. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
