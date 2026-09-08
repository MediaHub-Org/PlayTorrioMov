# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history (commit messages carry the full root-cause/design detail);
this file stays about what is left, kept short on purpose.

Last reconciled against the tree: **2026-09-08** (v1.2.1+16).

## Relationship to PlayTorrioMod

PlayTorrioMov forked from
[`MediaHub-Org/PlayTorrioMod`](https://github.com/MediaHub-Org/PlayTorrioMod)
on 2026-08-31 (Movies & Series, Anime, Live TV, Library — Music and Books
removed, better served by dedicated apps). It's now the **primary app of the
two**: smaller, watch-only, easier to keep consistent. PlayTorrioMod remains
a sibling app (and stays the primary consumer of upstream
`ayman708-UX/PlayTorrioV3`) but this repo's docs/roadmap/direction no longer
follow it. Anything worth carrying over gets ported deliberately, not by
`git merge` — the two repos' git histories and nav shapes don't match
(PlayTorrioMod: three hubs switched by `AppHub`; this app: one hub, `AppHub`
doesn't exist here).

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
action reachable from anywhere, not a place to browse.

There used to be three hubs here (Watch/Listen/Read, à la PlayTorrioMod) and
Movies/Series used to share one section behind an internal pill toggle —
both deliberately removed/split (see Resolved #13, and Declined below for
why multi-hub isn't coming back). Any proposal to reintroduce either should
be weighed against why it was removed, not just re-added by habit.

## Upstream tracking

Git history was squashed at the fork point (`cc3a1b3`) — nothing arrives
here via `git merge`; everything is a deliberate, file-by-file port checked
against how far Mov's own code has already diverged from PlayTorrioMod and
its upstream, `ayman708-UX/PlayTorrioV3`.

**Mov is fully caught up with `v3/main` as of 2026-09-06** (last commit
merged: `f1f1310`). This is a point-in-time snapshot, not a live sync status
— re-fetch `v3/main` before trusting it as current.

| Commit    | Summary                                    | Status |
|-----------|---------------------------------------------|--------|
| `cc07994` | AniList 403 fix, bump 1.1.1                  | Merged |
| `b0aecf5` | 30 new scraper sites + 7 anime extractors     | Merged (added side by side with Mov's existing, non-overlapping set) |
| `9d34d4c` | Update README                                | Skipped — V3's own README, not relevant here |
| `ad0e40d` | Audio dub/language filtering, scraper touch-ups | Merged — skipped the type-filter chip bar, seeder filter, and mobile bottom-sheet variant Mov never had |
| `6c4d0cf` | Player error filtering & stream health         | Merged — skipped the audiobook/music-player hunks Mov has neither of |
| `f1f1310` | Stremio catalog-extra & collection addons     | Merged — dropped the "Liquid Dock Navbar" hunk outright (V3's three-hub dock nav doesn't exist here); a follow-up review caught and fixed a real regression the port introduced (a collection-part IMDb-id override firing on every episode) |

## Blocked on a device

Cleared 2026-09-03 — media_kit/libmpv playback, cross-source resume, and QA
across all five platforms were checked before `v1.1.6` shipped as a full
(non-prerelease) release. Reopen (set `AppInfo.channel` back to `'dev'`)
only if a regression surfaces in one of them.

## Code and consistency

| #  | Task | Why it is still open |
|----|------|------------------------|
| 4  | Anime and Movies/Series share one row (`BrowseRowView`), but the *pages* still differ | Migrating Anime's page onto `BrowseScaffold` was dropped — `AnimeSliderSection` is also used by `anime_search_page`, so converting only the Anime page would leave two row implementations on adjacent screens. Revisit only if a third page wants Anime's hero-carousel + `ContinueWatchingSlider` arrangement. |
| 5  | Some files use `MediaQuery.sizeOf(context).width` instead of `AppBreakpoints.of(context)` | Inherited from PlayTorrioMod, no user-visible bug. Migrate opportunistically when a file is touched for another reason. |
| 10 | Header side-padding differs per section (24/28/16px) — Movies/Series has a responsive constant the others should converge on | Needs a mobile-first pass, but this environment has no phone/tablet device or emulator to verify the result against, so it needs a hands-on check before landing. |

## Known bugs

Nothing open right now.

## Requested UI work

| #  | Task | Details |
|----|------|---------|
| 15 | Design mobile-first, as a standing policy | Not a single fix — design new/reworked screens for mobile first, then scale up. Still open for #10. |
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. |
| 24 | Define a minimum width for the pill/header controls | `FilterDropdown`/`PageSearchButton`/`HeaderPillIconButton` have no minimum tap-target/width of their own — separate question from the 760×600 window floor (#18). |
| 28 | Simplify the video player UI | Trim the on-screen controls to: close/back, a seek/progress line, play/pause, skip ±10s via double-tap on the left/right half of the video, a subtitle button, an audio-track button. Integrate Google Cast. Remove the download button. Distinct from #27's tap-to-play/pause removal — that was single-tap; this is the double-tap seek gesture YouTube-style players use. A real redesign, not a quick fix: `player_screen.dart` currently has far more controls than this (quality/server picker, PiP, aspect ratio, screenshot, sleep timer, subtitle sync, ...) — needs a decision on where those go (a secondary "more" menu?) or whether they're cut too. |

## Resolved

Full detail lives in commit messages (`git log`) and
[CHANGELOG.md](../CHANGELOG.md) — this is a checklist of what shipped, not
an archive of why.

- **#27** Tap-to-play/pause on the video removed (conflicted with
  double-tap-to-fullscreen and added input lag); gap added between the back
  button and the search field; gap added between a row's title and its
  card list.
- **#26** Header pills (Movies/Series/Anime/Live TV) no longer stay pinned
  to the screen while the page scrolls; search icon and Live TV's whole
  header unified onto one shared pill design; Library's extra top gap on
  mobile removed.
- **#20** Custom Background/Wallpaper and Liquid Glass Setup removed (dead
  PlayTorrioMod leftovers); Settings no longer hides the 5-section bar.
- **#19** IPTV favorite-channel discoverability improved; 5-section bar no
  longer hidden behind Details/Search on desktop; Settings icon position
  drift fixed (a `Flex` layout bug); back button design unified
  (`GlassBackButton`).
- **#18** Header pill row unified (`PillFilterHeaderBar`); 760×600 minimum
  desktop window size; Library's own search removed, Watched chip added;
  Live TV channels can be favorited.
- **#17** A catalog fetch failure no longer looks like an empty catalog.
- **#16** Subtitle translation language list trimmed to ~34 common
  languages (was ~110).
- **#14** Settings icon position unified across mobile/desktop.
- **#13** Movies & Series split into two top-level nav sections.
- **#12** Genre tag chips unified into one shared `GenreTagRow` (was
  hand-rolled 5 separate times).
- **#11** Android system back button now pops nested routes instead of
  exiting the app.
- **#9** Already true — no A-Z sort existed to remove.
- **#7** Windows "Unknown hard error" on app close, fixed (player now
  disposed on shutdown).
- Watchlist / Watched / Like three-state buttons shipped for Movies &
  Series.

## Signing and releases

Android release signing needs two repository secrets and is what lets the
in-app updater replace an existing install — see
[release signing](RELEASES.md#release-signing). Without them, builds still
succeed, signed with a throwaway debug key. No other platform needs signing
for updates, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now; a second is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** No second controller type to unify against (unlike PlayTorrioMod, which also had music/audiobook controllers).
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
