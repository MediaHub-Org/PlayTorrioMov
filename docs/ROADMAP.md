# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and the GitHub release notes; this file stays about what is left. Day-to-day
task tracking lives in [TASKS.md](../TASKS.md); this file is the longer arc.

Last reconciled against the tree: **2026-09-03** (v1.1.5+13).

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
weighed against why they were removed, not just re-added by habit.

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
| 5 | **Some files do ad-hoc `MediaQuery.sizeOf(context).width`** instead of `AppBreakpoints.of(context)` | Inherited from PlayTorrioMod's own count of call sites — no shared risk, no user-visible bug. Migrate opportunistically when a file is touched for another reason, not as a batch pass. |
| 6 | **Kotlin Gradle Plugin will break future Flutter builds** | Every Android build warns: the app and six plugins (`package_info_plus`, `shared_preferences_android`, `torrserver_flutter`, `url_launcher_android`, `video_player_android`, `wakelock_plus`) apply KGP, and *"future versions of Flutter will fail to build if your app uses plugins that apply KGP"*. The app's own `build.gradle.kts` can migrate to Built-in Kotlin; the plugins cannot be fixed here — each needs a version that supports it, or an upstream issue. Not urgent, but it is a dated fuse rather than a style nit. |
| 10 | **Header space consistency between all sections** | Live TV, Movies & Series, Anime and Library don't share identical header/app-bar margin and padding today. Tracked as a near-term item in [TASKS.md](../TASKS.md). |

## Known bugs

| # | Bug | Notes |
|---|-----|-------|
| 7 | **"Unknown hard error" on Windows after closing the app** | Root-caused: a native window close never runs the widget tree's own `dispose()`, so `PlayerScreen`/`IptvPlayerPage`'s media_kit `Player` stayed alive into process teardown. Candidate fix shipped (`PlaybackCoordinator.disposeForShutdown()` + `onShutdownDispose`, `WindowService` calls it on close) — see [CHANGELOG.md](../CHANGELOG.md). **Not yet empirically verified** — no way to drive the UI to start real playback and then close over it in this environment; confirmed only that a real `WM_CLOSE` with no active player exits clean. Needs a hands-on close-while-playing-video check. |
| 11 | **Android back button** | Reported broken; tracked in [TASKS.md](../TASKS.md). |
| 12 | **Tags on content pages only show their icon** | The label doesn't fit the available width; tracked in [TASKS.md](../TASKS.md). |

## Requested UI work

| # | Task | Notes |
|---|------|-------|
| 9 | **Remove A-Z title sort on Movies & Series** | Find the sort control on `TypeCatalogPage`/`FilterDropdown` and drop the alphabetical option, keeping whatever the remaining sort choices are (e.g. popularity, release date, added date). |

## Resolved

- ~~**Icon-button consistency, plus a Watchlist/Watched pair**~~ — shipped:
  Watchlist / Watched / Like three-state buttons for Movies & Series (see
  [CHANGELOG.md](../CHANGELOG.md)).

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
