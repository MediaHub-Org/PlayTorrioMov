# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history, not here.

Last reconciled against the tree: **2026-09-11** (v1.5.7+26), after Live TV
moved onto `BrowseScaffold` — which closed the last of the page-consistency
items — and after the standard library actions reached every section.

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

**Last synced: `3670ae1`, 2026-09-10.** Ported download auto-reconnect,
"Copy Stream URL", and the fullscreen-state-on-exit fix from that commit;
deliberately not ported: its Support Dev sponsor monetization feature (out
of scope for this fork) and its keyboard-driven aspect-cycle HUD (Mov
already has an aspect ratio control in the player's Settings menu — a
second, inconsistent affordance for the same setting would be a
regression). Still unreviewed from the same batch: `9616808` (hero
backdrop scaling for home/anime — anime_page.dart has diverged
significantly since this session's `BrowseScaffold` migration, needs
adapting rather than a direct port) and `d2f8074` (IPTV portal manager
responsiveness — a near-total rewrite of `iptv_portals_modal.dart`, real
mobile-first value but a large diff to review safely). Next step: review
those two, then check `v3/main` for anything past `3670ae1`, file-by-file
(git history was squashed at the fork point, so nothing arrives via
`git merge`).

## Code and consistency

Nothing outstanding. Every browse section — Movies/Series, Anime and Live TV
— now renders through `BrowseScaffold` and `BrowseRowView`, so "the same
kind of page" really is one implementation.

## Requested UI work

| #  | Task | Details |
|----|------|---------|
| 15 | Design mobile-first, as a standing policy | Not a single fix — design new/reworked screens for mobile first, then scale up. `AppSpacing.pageInset` is the mobile-first gutter to build against. The converged page gutter itself is now verified on real Android hardware. |
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. A design call (icon choice, placement, prominence), not a quick code fix. |
| 28 | Google Cast: verify the actual cast-a-stream flow | The app itself is now verified on real Android hardware, but that didn't cover Cast specifically — still need a Cast-capable receiver on the network to confirm `lib/services/cast/cast_service.dart` actually casts a stream end to end, on both Android and iOS. |

## Signing and releases

Android release signing **is configured** — `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` are both set, and the v1.5.6 build log confirms
it ("Release signing configured (alias: playtorriomov)"). Released APKs
therefore install over each other and the in-app updater works. See
[release signing](RELEASES.md#release-signing). No other platform needs
signing for updates, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

`ENV_FILE`/`DOTENV` is **not** set, and that is the one outstanding release
secret. Every published build ships an empty `.env`, so Trakt sign-in,
Simkl sign-in and Discord Rich Presence are inert in released binaries.
TMDB cast photos are unaffected — `TmdbSettings` carries a bundled fallback
key.

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now; a second is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
