# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history, not here.

Last reconciled against the tree: **2026-09-08** (v1.3.0+17).

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

**Last synced: `e560d4a`, 2026-09-08.** Ported the HindMoviez scraper,
Castilian/Latino Spanish audio detection, and Arabic anime catalog fixes.
Deliberately not ported: the "Builtin Providers" settings feature (see #29
below). Next step: check `v3/main` for commits past `e560d4a` and port
anything applicable, file-by-file (git history was squashed at the fork
point, so nothing arrives via `git merge`).

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
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. A design call (icon choice, placement, prominence), not a quick code fix. |
| 28 | Google Cast: verify on real Android/iOS hardware | Wired up (`lib/services/cast/cast_service.dart`, `flutter_chrome_cast`), but this environment has no Android SDK, no Xcode, and no Cast-capable device — the native manifest/plist config and the actual cast-a-stream flow are both unverified. |
| 29 | Port upstream's "Builtin Providers" settings feature | A settings page + service (821 + 285 lines in `ayman708-UX/PlayTorrioV3`, commit `e560d4a`) letting users toggle and reorder individual built-in scrapers. Upstream hardcodes its own 46-provider list, which doesn't match Mov's actual registered scraper set (ported separately, at different times) — needs to generate the list from `ScraperManager`'s real scrapers instead of copying V3's, which is real design work, not a quick port. |
| 30 | Continue Watching must open straight into playback, with no hub chrome | Resuming an item pushes `PlayerScreen`/`WatchScreen` with a plain `Navigator.push`, which lands inside the hub's `NestedNavigator` — so the section top bar and sidebar stay drawn around a screen that is supposed to be fullscreen video. |
| 31 | Filter pills (Genres, Decade, Newest, Search) on one sticky line | `PillFilterHeaderBar` is a `Wrap`, so the pills break onto a second run on narrow widths, and the bar scrolls away with the hero. Wanted: one horizontally-scrollable line that stays put, with the hero carousel below it and a small gap between the two. Note this partly reverses the 1.2.1 un-pinning — pinning is only acceptable with the bar's own backdrop, so page content never scrolls visibly under a transparent strip, which is what made it look broken before. |
| 32 | Seed/torrent detail on the source pickers (Movie/Series/Anime) | `StreamSource.seeders` is parsed out of the source title but never rendered anywhere, and only the in-player sources panel distinguishes P2P from HTTP. The source cards you actually pick from show quality/codec/size and nothing about the torrent's health. |
| 33 | One page-change animation | Pages are pushed with three different transitions — `LiquidRevealRoute`, `CinematicSlideRoute`, and a bare `MaterialPageRoute` — chosen per call site rather than per kind of navigation. |
| 34 | Ship a working TMDB API key by default | Cast enrichment no-ops until the user pastes their own key into Settings. TMDB should follow the same `EnvService` dart-define/`.env` path Trakt, Simkl, and Discord already use, so a build can carry a key and the user's own key still wins. |
| 35 | One position for the floating back button and page header on mobile | `GlassBackButton` is one widget but every page positions it itself (8 / 16 / 20 / `_Space.md` / `_Space.xxl`), and Anime Details pins it at a fixed `top: 24` that ignores the status-bar inset entirely. |
| 36 | One page template, mobile-first | The follow-through on #15 and #10: pages that do the same job (a hero + rows browse page, a details page, a search page) should be built from the same scaffold and the same header metrics instead of each re-deriving them. |

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
