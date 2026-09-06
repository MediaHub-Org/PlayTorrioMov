# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and the GitHub release notes; this file stays about what is left. Day-to-day
task tracking lives in [TASKS.md](../TASKS.md); this file is the longer arc.

Last reconciled against the tree: **2026-09-06** (v1.1.6+14).

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
for its own log). **Last commit merged into Mov: `f1f1310`** — Mov is
fully caught up with `v3/main` as of 2026-09-06; `9d34d4c` carried no
portable content (V3's own README).

| Commit    | Summary                                              | Status                                                                                                                     |
|-----------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `cc07994` | Fix anime catalog AniList 403 issue, bump 1.1.1        | **Merged.** `anilist_service.dart` now sends a browser User-Agent/Origin/Referer and a 15s timeout. The paired `anime_page.dart` empty-results error message already existed independently in Mov. |
| `b0aecf5` | New scraper sources, fix mapple scraper, bump 1.1.2    | **Merged (side by side).** 30 new scraper sites and 7 new anime extractors added alongside Mov's existing, non-overlapping set; new `video_settings_page.dart`; anime/continue-watching/player diffs reviewed file-by-file rather than patch-applied, since those files had already diverged. Mov's own `StreamHealthChecker` dead-stream filtering was kept — V3 had dropped its equivalent, not carried over. |
| `9d34d4c` | Update README                                         | **Not merged, by design.** V3's own README, not relevant here.                                                             |
| `ad0e40d` | Bump 1.1.3: audio dub & language filtering, backend scraper extractions, responsive UI | **Merged.** Audio-language/dub detection on `StreamSource` plus a matching filter dropdown and source-card badge in `watch_screen.dart`, 10 scraper-site touch-ups, a smarter open-above dropdown positioning fix. Deliberately skips the type-filter chip bar, seeder filter, mobile bottom-sheet variant, and the desktop flex-ratio tweak — Mov never had the first two, and the last one risked an unreviewed layout regression. |
| `6c4d0cf` | fix(player): streamline stream error filtering and health verification | **Merged.** `PlayerSettings.isNonFatalError` refinement, Dulo referer/domain-priority fix, VidRock JSON-playlist parsing fix, new CDN referer resolver rules. The `stream_scraper.dart` health-check hunk was a non-issue — Mov already had the equivalent gate under different variable names. Skips the `audiobook_player_screen.dart`/`music_player_controller.dart` hunks — Mov has neither. |
| `f1f1310` | Add full Stremio catalog-extra handling and collection addons support | **Merged.** `AddonCatalogExtra` model, the bigger `discover_page.dart` with catalog-extra selectors, Stremio collection-addon support (Movie/MovieDetail `isCollection`, part-level IMDb-id normalization through watch/player/details). Dropped the "Liquid Dock Navbar" this commit added to `discover_page.dart` along with the `dock_settings.dart`/`app_liquid_dock.dart`/`home_page.dart` hunks outright — V3's three-hub dock nav, which this app doesn't have (see § Navigation principle); `DiscoverPage` here is a standalone pushed page, not dock-bearing. A follow-up cloud review caught a real regression in the port (a collection-part IMDb-id override that was firing for every series episode, not just collection parts) — fixed same day, see git log for the fix commit. |

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
| 10 | **Header space consistency between all sections, mobile first** | Confirmed and quantified: Movies & Series (`BrowseScaffold`) uses a shared, responsive `sizing.sidePadding`; Anime hardcodes `EdgeInsets.fromLTRB(24, 80, 24, 120)`; Live TV hardcodes `EdgeInsets.fromLTRB(28, topPadding + 14, 28, 14)`; Library hardcodes `EdgeInsets.fromLTRB(16, 16, 16, 100)`. Three different fixed side-padding values (24/28/16) where one page already has a responsive constant to converge on. **2026-09-06:** user asked specifically for the top-of-page margin/padding to be tightened on mobile, and for the fix to be designed mobile-first rather than adapted down from desktop. Still not fixed — this environment can now actually run and screenshot the desktop build (see this session's launch), but has no phone/tablet device or emulator to check the mobile result against, so a mobile-first pass still needs a hands-on check on a real device before landing. |

## Known bugs

Nothing open here right now — see Resolved below for #17.

## Requested UI work

Requested 2026-09-06, after seeing the merged upstream-port build running
live for the first time this session.

| #  | Task                                                        | Details                                                                                                                                                                                                                                                            |
|----|---------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 15 | **Design mobile first, as a standing policy**                  | General direction going forward, not a single fix: design new/reworked screens for mobile first, then scale up to tablet/desktop — not the other way around. Applied so far to #12 and the `FilterDropdown` mobile fix below; still open for #10. |

See Resolved below for #13 (nav split), #14 (Settings position), and #16
(subtitle list).

## Resolved

- ~~**#14 Settings entry point: fixed position, same on every screen**~~ —
  `TopBar`/`AdaptiveNavShell._MobileTopBar` were already the *only* two
  Settings entry points (top-right on both, one `onSettingsTap` callback
  from `HubPage`, nothing duplicated per page) — first pass called that
  "already true." A closer look found the two bars actually picked
  different heights (60 vs 52) and differently-sized/padded `IconButton`s
  independently, drifting the gear icon's exact position a few px between
  tiers while resizing. Fixed for real with a shared `SettingsIconButton`
  and `TopBar.sharedHeight` both bars now use. The one remaining gap
  (pages pushed *outside* the hub, like `DiscoverPage` or detail pages,
  show no Settings icon) still looks intentional — nested, not top-level
  destinations — left as-is.
- ~~**#18 Header pills, Settings drift, window min size, Library search/chips, Live TV favorites**~~ —
  a batch from live testing on the desktop build:
  - New `PillFilterHeaderBar` (`lib/widgets/common/pill_filter_header_bar.dart`):
    the genre/decade/sort/search pill row floated over a page's hero is one
    widget with one canonical inset now, instead of Movies/Series and Anime
    each hand-rolling their own (24/24/24/16 padding vs. a hand-tuned
    `Positioned(top:16,right:16)` box) — they render pixel-identically.
    Live TV has no equivalent filter row to unify (its header is a
    distinct branded bar with a channel count), left as-is.
  - `window_service.dart` now calls `windowManager.setMinimumSize(760, 600)`
    on desktop — there was no floor before, so the window could be shrunk
    into the mobile breakpoint tier, which is what made pills look cramped
    in the first place. 760 stays above `AppBreakpoints.tablet` (600).
  - Library's own local search box (a second, separate search implementation
    from the rest of the app's per-page `PageSearchButton` pattern) removed.
  - Library gets a Watched toggle chip (next to Watchlist, filtering on
    the already-existing `MyListItem.isWatched`) and a Live TV chip.
  - Live TV channels can now be favorited (heart on `IptvChannelCard`,
    reusing `LikeButton` — a first attempt hand-rolled the same
    `favorite_rounded`/`favorite_border_rounded` toggle
    `test/widgets/like_button_test.dart` exists specifically to catch, and
    it did) and show up under Library's new Live TV chip. Kept fully
    separate from `MyListItem`/`MyListService` (new `FavoriteChannelsService`,
    mirroring `IptvStore`'s own favorites pattern) since that model syncs to
    Trakt/Simkl, which have no concept of a live channel.
  - Audited whether any hub-section page can cover the shared
    `SectionTopBar`/bottom tab bar: none use `Overlay.insert`,
    `OverlayEntry`, or `extendBody` — each section's own `Stack`/`Positioned`
    overlays are bounded to its own `Expanded` slot in
    `SectionedHubScaffold`'s `Column`, not the full screen. Confirmed by
    source read, no fix needed.
- ~~**#17 A catalog fetch failure silently looked like "no content"**~~ —
  fixed: `AddonManager.fetchByType` now rethrows the last error when every
  catalog for that type failed outright (as opposed to succeeding with
  zero results), instead of always swallowing to `null`. A transient
  network failure now surfaces `TypeCatalogPage`'s existing `ErrorView` +
  retry instead of the misleading "no content" empty state. Found chasing
  a "Series doesn't load content" report — the report itself traced to a
  live DNS failure during that session, not a Movies/Series code
  asymmetry, but the swallowing was real and is what made it confusing.
- ~~**#7 "Unknown hard error" on Windows after closing the app**~~ —
  confirmed fixed 2026-09-06: no longer reproduces. Root cause was a
  native window close never running the widget tree's own `dispose()`,
  leaving `PlayerScreen`/`IptvPlayerPage`'s media_kit `Player` alive into
  process teardown; fixed by `PlaybackCoordinator.disposeForShutdown()` +
  `onShutdownDispose`, called from `WindowService` on close (see
  [CHANGELOG.md](../CHANGELOG.md)).
- ~~**#13 Split "Movies & Series" into two separate sections**~~ — done: 5
  top-level sections now (`HubController.currentSections`), the internal
  Movies/Series pill toggle removed from `TypeCatalogPage`. See §
  Navigation principle for the shape and the trade-off it overrides.
- ~~**#12 Tags on content pages only show their icon**~~ — done, but not
  the bug originally suspected: no "icon-only, overflowing label" widget
  ever existed (confirmed by source read) — genre chips were text-only
  `Wrap`s implemented **five separate times** (Movies/Series and Anime's
  hero carousels, plus the Movies/Series, Anime, and Anime-Arabic detail
  pages — the hero-carousel pair only turned up in a later visual pass,
  after the first fix already landed), and Live TV had no genre tag at
  all (only a category badge). Unified into one shared `GenreTagRow`
  (`lib/widgets/common/genre_tag_row.dart`): icon-only pills (with a
  genre→icon map and a hover/long-press `Tooltip` for the name), laid out
  in a horizontally-scrolling single row so it can never wrap to a second
  line regardless of genre count. Also made `FilterDropdown` (the
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
