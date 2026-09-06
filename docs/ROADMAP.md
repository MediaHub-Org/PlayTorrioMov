# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and the GitHub release notes; this file stays about what is left. Day-to-day
task tracking lives in [TASKS.md](../TASKS.md); this file is the longer arc.

Last reconciled against the tree: **2026-09-06** (v1.1.6+14).

**Redone from scratch, awaiting review:** the prior background agent's
worktree/branch for the `ad0e40d`/`6c4d0cf`/`f1f1310` port (see § Upstream
tracking below) turned out to exist only in that session's now-gone
environment — never pushed to `origin`, no other local checkout on the
machine. Redone as 3 stacked branches, each file-by-file (not
patch-applied) and each with `flutter analyze`/`flutter test` run clean:
`port/ad0e40d-dub-lang-filtering` → `port/6c4d0cf-stream-error-filtering` →
`port/f1f1310-stremio-catalog-extras`. Per-file breakdown of what was
clean, hand-merged, or skipped (and why) is in
[docs/UPSTREAM_MERGE.md](UPSTREAM_MERGE.md). PlayTorrioMod's side of the
same 3-commit gap is already done and pushed (`main` @ `08978f0`). Next
session: review the 3 branches, fast-forward `master` if clean.

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

One hub, five sections, the last always Library:

| Section      | Content                                    |
|:-------------|:--------------------------------------------|
| **Movies**   | TMDB-catalog movies                         |
| **Series**   | TMDB-catalog series                         |
| **Anime**    | Its own catalog and scraper                 |
| **Live TV**  | IPTV channels                               |
| **Library**  | Everything you've saved                     |

Phones show sections in the bottom tab bar; tablet and desktop show them as
a chip row under the top bar. Search stays an icon, not a section — it's an
action reachable from anywhere, not a place to browse, and doesn't compete
for the same scarce nav real estate the five sections above use.

**2026-09-06:** Movies and Series used to share one section with an
internal pill toggle, specifically to keep the mobile bottom bar at a
fixed four items (`SectionSubTabs`'s own doc comment explained why). User
asked to split them into two full top-level sections regardless — done
(`HubController.currentSections`, `MediaHub`, `TypeCatalogPage`'s internal
toggle removed). `SectionSubTabs` itself is kept for a future pair that
would rather stay merged than grow the section count again.

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
| `ad0e40d` | Bump 1.1.3: audio dub & language filtering, backend scraper extractions, responsive UI | **Ported**, on `port/ad0e40d-dub-lang-filtering`, awaiting review/merge. Audio-language/dub detection on `StreamSource` plus a matching filter dropdown and source-card badge in `watch_screen.dart`, 10 scraper-site touch-ups, a smarter open-above dropdown positioning fix. Deliberately skips the type-filter chip bar, seeder filter, mobile bottom-sheet variant, and the desktop flex-ratio tweak — see [docs/UPSTREAM_MERGE.md](UPSTREAM_MERGE.md) for why. |
| `6c4d0cf` | fix(player): streamline stream error filtering and health verification | **Ported**, on `port/6c4d0cf-stream-error-filtering`, awaiting review/merge. `PlayerSettings.isNonFatalError` refinement, Dulo referer/domain-priority fix, VidRock JSON-playlist parsing fix, new CDN referer resolver rules. The `stream_scraper.dart` health-check hunk was confirmed a non-issue — Mov already had the equivalent gate under different variable names. Skips the `audiobook_player_screen.dart`/`music_player_controller.dart` hunks — Mov has neither. |
| `f1f1310` | Add full Stremio catalog-extra handling and collection addons support | **Ported**, on `port/f1f1310-stremio-catalog-extras`, awaiting review/merge. `AddonCatalogExtra` model, the bigger `discover_page.dart` with catalog-extra selectors, Stremio collection-addon support (Movie/MovieDetail `isCollection`, part-level IMDb-id normalization through watch/player/details). Dropped the "Liquid Dock Navbar" this commit added to `discover_page.dart` along with the `dock_settings.dart`/`app_liquid_dock.dart`/`home_page.dart` hunks outright — V3's three-hub dock nav, which this app doesn't have (see § Navigation principle); `DiscoverPage` here is a standalone pushed page, not dock-bearing. |

This table gets re-checked whenever PlayTorrioMod's upstream gap is
revisited; it is a snapshot, not a live sync status. Re-fetch `v3/main`
before trusting "last merged" as current — upstream moves.

Per-file merge status for the in-progress `ad0e40d`/`6c4d0cf`/`f1f1310`
port (what applied cleanly, what was hand-merged and why, what was
deliberately skipped) is tracked in
[docs/UPSTREAM_MERGE.md](UPSTREAM_MERGE.md) while that work is in flight.

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
| 10 | **Header space consistency between all sections, mobile first** | Confirmed and quantified: Movies & Series (`BrowseScaffold`) uses a shared, responsive `sizing.sidePadding`; Anime hardcodes `EdgeInsets.fromLTRB(24, 80, 24, 120)`; Live TV hardcodes `EdgeInsets.fromLTRB(28, topPadding + 14, 28, 14)`; Library hardcodes `EdgeInsets.fromLTRB(16, 16, 16, 100)`. Three different fixed side-padding values (24/28/16) where one page already has a responsive constant to converge on. **2026-09-06:** user asked specifically for the top-of-page margin/padding to be tightened on mobile, and for the fix to be designed mobile-first rather than adapted down from desktop. Still not fixed — this environment can now actually run and screenshot the desktop build (see this session's launch), but has no phone/tablet device or emulator to check the mobile result against, so a mobile-first pass still needs a hands-on check on a real device before landing. |

## Known bugs

| #  | Bug                                                       | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|----|-----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7  | **"Unknown hard error" on Windows after closing the app** | Root-caused: a native window close never runs the widget tree's own `dispose()`, so `PlayerScreen`/`IptvPlayerPage`'s media_kit `Player` stayed alive into process teardown. Candidate fix shipped (`PlaybackCoordinator.disposeForShutdown()` + `onShutdownDispose`, `WindowService` calls it on close) — see [CHANGELOG.md](../CHANGELOG.md). **Not yet empirically verified** — no way to drive the UI to start real playback and then close over it in this environment; confirmed only that a real `WM_CLOSE` with no active player exits clean. Needs a hands-on close-while-playing-video check. |
| 17 | **A catalog fetch failure silently looks like "no content"** | `AddonManager.fetchByType`/`fetchAllHomeSections` swallow each catalog's fetch exception per-addon (`catch (_) { return null; }`) so a transient network failure (DNS hiccup, timeout) for one type/catalog just drops that row instead of surfacing an error with retry. Found 2026-09-06 chasing a "Series doesn't load content" report — reproduced no code-level asymmetry between Movies/Series, but the same session's log showed live DNS failures (`Failed host lookup: graphql.anilist.co`) at the same time, and Cinemeta's manifest was independently confirmed (live) to declare a real `type: series` catalog. Likely explanation: the swallowed exception, not a Movies/Series bug — but the swallowing itself is worth fixing so a network blip shows a retryable error instead of an indistinguishable empty state. |

## Requested UI work

Requested 2026-09-06, after seeing the merged upstream-port build running
live for the first time this session.

| #  | Task                                                        | Details                                                                                                                                                                                                                                                            |
|----|---------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 14 | **Settings entry point: fixed position, same on every screen** | **Confirmed already true 2026-09-06**, not a fix: `TopBar`/`AdaptiveNavShell._MobileTopBar` are the *only* Settings entry points in the app (top-right on both), shared by all 5 hub sections via one `onSettingsTap` callback threaded from `HubPage` — nothing duplicates it per page. The one real gap is pages pushed *outside* the hub (`DiscoverPage`, detail pages) showing no Settings icon at all — that looks intentional (they're nested, not top-level destinations), so left alone pending confirmation it should change. |
| 15 | **Design mobile first, as a standing policy**                  | General direction going forward, not a single fix: design new/reworked screens for mobile first, then scale up to tablet/desktop — not the other way around. Applied so far to #12 and the `FilterDropdown` mobile fix below; still open for #10. |

See Resolved below for #13 (nav split) and #16 (subtitle list).

## Resolved

- ~~**#13 Split "Movies & Series" into two separate sections**~~ — done: 5
  top-level sections now (`HubController.currentSections`), the internal
  Movies/Series pill toggle removed from `TypeCatalogPage`. See §
  Navigation principle for the shape and the trade-off it overrides.
- ~~**#12 Tags on content pages only show their icon**~~ — done, but not
  the bug originally suspected: no "icon-only, overflowing label" widget
  ever existed (confirmed by source read) — genre chips on
  Movies/Series/Anime/Anime-Arabic detail pages were text-only `Wrap`s,
  three separate near-identical implementations, and Live TV had no genre
  tag at all (only a category badge). Unified into one shared
  `GenreTagRow` (`lib/widgets/common/genre_tag_row.dart`): icon-only pills
  (with a genre→icon map and a hover/long-press `Tooltip` for the name),
  laid out in a horizontally-scrolling single row so it can never wrap to
  a second line regardless of genre count. Also made `FilterDropdown` (the
  genre/decade/sort pill buttons on catalog pages) icon-only on mobile
  after a follow-up report that they ran too wide there — label comes
  back on tablet/desktop where there's room.
- ~~**#16 Subtitle language list is unmanageably long**~~ — done:
  `SubtitleCatService`'s on-the-fly-translation branch (the ~110-language
  flood; direct/real subtitle files were never the problem and are
  untouched) now filters through a curated ~34-language
  `_commonTranslatableLangs` set instead of offering every language the
  site's translate widget could theoretically target.
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
