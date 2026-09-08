# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history, not here.

Last reconciled against the tree: **2026-09-08** (v1.2.1+16).

## Navigation

One hub, five sections, the last always Library:

| Section      | Content                       |
|:-------------|:--------------------------------|
| **Movies**   | TMDB-catalog movies             |
| **Series**   | TMDB-catalog series              |
| **Anime**    | Its own catalog and scraper      |
| **Live TV**  | IPTV channels                    |
| **Library**  | Everything you've saved          |

Phones show sections in the bottom tab bar; tablet and desktop show them as
a chip row under the top bar. Search stays an icon, not a section.

## Upstream sync

PlayTorrioMov originated as a fork of `MediaHub-Org/PlayTorrioMod`; that repo
is now **archived**, so Mov is the only active app in the family and the
direct downstream of upstream `ayman708-UX/PlayTorrioV3` — no more relaying
through PlayTorrioMod.

**Last synced: `f1f1310`, 2026-09-06.** Next step: check `v3/main` for
commits past that point and port anything applicable, file-by-file (git
history was squashed at the fork point, so nothing arrives via `git merge`).

## Code and consistency

| #  | Task | Why it is still open |
|----|------|------------------------|
| 4  | Anime and Movies/Series share one row (`BrowseRowView`), but the *pages* still differ | Migrating Anime's page onto `BrowseScaffold` was dropped — `AnimeSliderSection` is also used by `anime_search_page`, so converting only the Anime page would leave two row implementations on adjacent screens. Revisit only if a third page wants Anime's hero-carousel + `ContinueWatchingSlider` arrangement. |
| 5  | Some files use `MediaQuery.sizeOf(context).width` instead of `AppBreakpoints.of(context)` | No user-visible bug. Migrate opportunistically when a file is touched for another reason. |
| 10 | Header side-padding differs per section (24/28/16px) — Movies/Series has a responsive constant the others should converge on | Needs a mobile-first pass, but this environment has no phone/tablet device or emulator to verify the result against, so it needs a hands-on check before landing. |

## Requested UI work

| #  | Task | Details |
|----|------|---------|
| 15 | Design mobile-first, as a standing policy | Not a single fix — design new/reworked screens for mobile first, then scale up. Still open for #10. |
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. |
| 24 | Define a minimum width for the pill/header controls | `FilterDropdown`/`PageSearchButton`/`HeaderPillIconButton` have no minimum tap-target/width of their own — separate question from the 760×600 window floor. |

## Signing and releases

Android release signing needs two repository secrets and is what lets the
in-app updater replace an existing install — see
[release signing](RELEASES.md#release-signing). Without them, builds still
succeed, signed with a throwaway debug key. No other platform needs signing
for updates, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now; a second is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
