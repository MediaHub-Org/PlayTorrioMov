# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history, not here.

Items are numbered and never renumbered, so `#43` means the same thing in a
commit message, a pull request and this file. A row whose Details open with
**Decided** has had its design question settled — the reasoning is in the
`###` section under the same number, and it is there so the decision is not
re-argued from the one-line summary. Anything ruled out entirely goes to
[Declined](#declined-so-they-do-not-get-re-litigated) with its reasoning
rather than being deleted.

Last reconciled against the tree: **2026-09-11** (v1.5.7+26), after the
v1.5.7 Android build was tested on a real device. Everything below #38 came
out of that session.

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
mobile-first value but a large diff to review safely; **no longer blocking
anything**, since the reported overflows were fixed directly in #40 and our
copy of that file has diverged too far for a straight port — see *The IPTV
overflows*). Next step: review
those two, then check `v3/main` for anything past `3670ae1`, file-by-file
(git history was squashed at the fork point, so nothing arrives via
`git merge`).

## Bugs

**None open.** Everything reported from testing the v1.5.7 Android build on
a device has been fixed: the cast-and-crew bug that caused three symptoms at
once (missing photos, the role line reading "Cast", missing directors) in
#38, the empty Direction half on series in #39, and the text escaping its
container in the IPTV portals modal in #40. See *Series creators* and *The
IPTV overflows* below for what shipped, and the CHANGELOG for #38.

Next device test to run: a series whose director was missing, to confirm a
**Creator** card now appears — #39 is the one fix that could not be
verified against the live API from CI (see its note).

## Code and consistency

Every browse section — Movies/Series, Anime and Live TV — renders through
`BrowseScaffold` and `BrowseRowView`, so "the same kind of page" is one
implementation. What is still uneven is the *information* inside those
pages, and the players.

| #  | Task | Details |
|----|------|---------|
| 41 | Standardise what a details page shows across Movies, Series and Anime | **Decided: one spine, one section-specific block each.** The common spine, in order: hero, title/year/rating/genres, the library action row, synopsis, credits, then episodes or related. Each section may add **at most one** block of its own on top. Anime's Characters & Cast is the anime-native form of credits and *replaces* Cast & Crew rather than sitting alongside it — a character-to-voice-actor list answers the same question for anime that actor-to-character does for film. Do this **after** #38, because today's unevenness is partly just missing data rather than differing layout.
| 42 | Standardise the Live TV player against the Movies/Series/Anime one | **Decided: match everything except seek.** Same control layout and iconography, same settings menu (audio track, aspect ratio), same gesture zones, same overlay appear/auto-hide timing. Deliberately absent for live, because they have no meaning without a duration: the seek bar, resume, ±10s/±30s skip (#44) and playback speed. Put a **LIVE** indicator where the seek bar would otherwise sit, so the control bar reads as deliberately different rather than broken.

## Requested UI work

| #  | Task | Details |
|----|------|---------|
| 15 | Design mobile-first, as a standing policy | Not a single fix — design new/reworked screens for mobile first, then scale up. `AppSpacing.pageInset` is the mobile-first gutter to build against. The converged page gutter itself is now verified on real Android hardware. |
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. A design call (icon choice, placement, prominence), not a quick code fix. |
| 28 | Google Cast: verify the actual cast-a-stream flow | The app itself is now verified on real Android hardware, but that didn't cover Cast specifically — still need a Cast-capable receiver on the network to confirm `lib/services/cast/cast_service.dart` actually casts a stream end to end, on both Android and iOS. |
| 46 | Custom Live TV channels from a portal stream | **Decided: build it.** #45 has shipped, so this is unblocked. It is what makes the portal browser's star worth demoting rather than deleting. A `HardcodedChannel` is just `{name, category, keywords[], exclude[]}`, so a user-defined one is the same record with the stream's name as its keyword — no new concept, just a second source feeding the same list. Closes a real gap: today, if a portal carries something the built-in catalogue has no entry for, there is no way to give it a tile, like it, or find it again except by re-browsing the portal.

### Series creators (shipped, #39 — but verify it on device)

A series' `/credits` is **series-level** crew, which for most shows is
producers and no director at all: TV directors are credited per episode.
That is why the Direction half came back empty even once #38 had the ids
working. `created_by` on `/tv/{id}` is the showrunner — what a viewer means
by "whose show is this" — and it is one extra request, made **only** for a
series whose `/credits` had no directing crew, so a series that already has
one costs nothing.

`/tv/{id}/aggregate_credits` remains the heavier alternative: a large
payload whose entries carry a `jobs` array instead of a single `job`,
needing a TV-shaped branch in the parser. Reach for it only if `created_by`
proves thin in practice.

**The live check this item asked for could not be done here.** This
session's network policy blocks `api.themoviedb.org`, so the response shape
is still reasoned from TMDB's documentation rather than observed. The code
is written so that being wrong costs nothing — an absent, empty, or
malformed `created_by` yields no crew, which is exactly today's behaviour —
and the parser is covered by tests for each of those shapes. What tests
cannot confirm is whether the field is **populated in practice**, so the
Android release is the real check: open a series whose director is missing
and look for a "Creator" card.

### How search came together (shipped, #48)

One search page now answers for Movies, Series and Anime. The groundwork
was already there, which made it smaller than it sounded.

**There are not several search icons.** `PageSearchButton` is one shared
widget, already rendered in the same header pill-row slot by
`type_catalog_page`, `anime_page` and `iptv_page`. Anime and Live TV simply
pass an `onTap` override to divert it to their own page. So "unify the
entry points" is, mechanically, deleting two `onTap:` arguments.

**Decided: keep the icon in the header pill row, and do not add a second
one next to Settings.** It already sits in one consistent place, grouped
with the filters it relates to, and within thumb reach on a phone. A global
icon next to Settings would either duplicate it or force the pill out, and
Settings is a different kind of destination — configuration, not content.
The goal here is to unify what search *does* while leaving where it *lives*
alone.

**Make the scope a chip instead of a hidden mode.** Today `SearchScope`
silently changes what the icon does: the same button means different things
depending on where it was pressed, which is the actual complaint. Instead
open one search page every time, with the current section **pre-selected as
a type chip the user can clear**. Context is kept, reach becomes global, and
nothing is invisible.

**Filters.** Under the field sits a fixed row of type chips — All, Movies,
Series, Anime — as `SearchFilter`, which is also what decides where a query
is actually sent: addons, AniList, or both at once. With **All** selected
the two catalogues are queried in parallel and results stay grouped by type
under their own headings rather than interleaved.

The genre / year / sort `FilterDropdown` pills planned here were **not**
built, and the plan was wrong to assume them: `AddonManager.searchAll` takes
a query and a content type and nothing else, so those pills would have had
nothing to narrow on the addon side. They belong to catalog browsing, where
they already live. The anime-native filters, which do exist as a real API,
are reached instead through the handover described below.

**The other search pages.** `anime_search_page.dart` is 918 lines and most
of that is anime-native filtering (AniList genre, season, format) that has
no movie equivalent, so it was kept rather than deleted. It is now reached
*through* the unified page: an **Anime filters** pill appears beside the
chips when Anime is selected, and the anime results row's "See all" leads to
the same place. Both hand the typed query across via a new `initialQuery`,
so nothing has to be retyped — the filters became a step deeper into search
instead of a separate front door.

Anime's own search button follows the same rule: in AniList mode it opens
the unified page (arriving with the Anime chip pre-selected, so it reads the
same as Movies and Series), and only **Arabic mode** still opens the anime
page directly, because the unified search has no source for that catalogue.

**Live TV stays out, for now.** Its search filters a channel and stream
list by keyword; it does not search a title catalogue, so a result there is
a different kind of object. Leaving its `onTap` override in place is the
honest version: one rule, legible — *in Live TV you search channels,
everywhere else you search titles*. A later pass can add a Live TV chip
whose results render as channel cards, once the result list is ready to hold
two shapes.

### The IPTV overflows: hand-patched, not ported (shipped, #40)

The choice was between porting upstream's `d2f8074` — a responsiveness
rewrite of this same `iptv_portals_modal.dart` — and patching the overflows
directly. **Patched directly**, for a reason that only became clear on
reading our copy: the file has diverged. Cloud Vault as a second portal
source, the modal-style customizer, and the whole M3U Playlists tab are
Mov's, not upstream's, so a near-total rewrite of the file would have had to
be re-adapted around all three. `d2f8074` stays on the upstream list, no
longer as a fix for anything reported.

Four overflows, all the same bug in different clothes — **an unconstrained
child in a `Row`, which does not shrink; it paints outside the box**:

- **The modal's title.** "IPTV Portals & Playlists" at 20pt w900, plus the
  icon and two trailing buttons, is wider than a phone dialog. Now
  `Expanded` with an ellipsis — which is what the `Spacer` after it was
  standing in for anyway.
- **The customizer sheet's title**, the same shape, found while fixing the
  first.
- **The source dropdown's items** (the one the user reached via Reddit).
  Their descriptions run to ~50 characters; a popup menu sizes itself to
  what fits on screen and does not grow past the edge to suit its contents.
  The text columns are now `Expanded` and wrap, and Cloud Vault's count
  badge sits in a `Wrap` so it drops under the title instead of pushing the
  row out.
- **Both selection toolbars** (Manage mode, portals and M3U). Select-all
  plus the two delete buttons are together wider than a phone dialog. Now a
  `Wrap` of two groups with `spaceBetween`: unchanged on a wide dialog, and
  the delete pair drops to a second line on a narrow one.

### Where the ±30s buttons went (shipped, #44)

The centred overlay keeps play/pause and ±10s and gained nothing: five
controls in one row is one too many to aim at, especially on a phone. ±30s
went to the **centre of the transport bar's bottom row** instead — between
volume and the subtitle/settings group, which is empty space on a phone and
within thumb reach. The side groups became `Expanded`, so the pair is
centred on the bar rather than on whatever room the volume control happens
to leave; under `spaceBetween` it would have sat off-centre, and shifted as
the left group changed shape between compact and wide.

The two steps are for different things, which is why both exist: ±10s to
catch a line of dialogue, ±30s to clear an ad break or an opening.

**One feedback path, not four.** Every fixed step — the double-tap zones,
the centred ±10s buttons, the new ±30s buttons, the arrow keys — already
routed through `_seekRelative`, so the flash was added there once. There is
no second path that could animate differently, or not at all. It appears on
the side matching the direction, and is deliberately **not** gated on the
controls being visible: a double-tap seek happens with the overlay hidden,
which is exactly when confirmation that the tap registered matters most.

**It counts.** Repeat taps in the same direction accumulate, so three quick
+10s taps read "30 seconds" — what the viewer is actually asking for —
rather than flashing "10 seconds" three times. Turning around starts a new
count instead of cancelling out: the number describes the current gesture,
not a running total of the session.

### Why Downloads stays in the Library (shipped, #43)

Continue and Downloads look equally droppable and are not. Continue really
is redundant: its tab renders `ContinueWatchingService.activeItems`, the
identical deduped list the Continue Watching row already shows.

Downloads is not "just the user's disk". `DownloadService` tracks in-app
tasks with live state — progress, pause, resume, delete — and only two files
in the app touch it: `watch_screen.dart`, where a download is started, and
the Library tab, which is the **only** place it can be seen or managed
afterwards. Android app-private storage is not browsable, so removing that
tab would leave a download with no UI at all: no way to watch it, cancel it,
or reclaim the space. Keeping it as a fourth tab alongside the three states
is also what every comparable app does.

### Why the ❤️ sits on the Live TV channel tile (shipped, #45)

A Live TV tile is **not a channel**. `HardcodedChannel` is
`{name, category, keywords[], exclude[]}` — UFC is literally
`['ufc', 'fight pass', 'mma', 'ultimate fighting']` — and
`HardcodedChannels.matches()` filters the streams your portals carry against
those keywords. The tile is a *saved search over a brand*; what opens inside
it is whatever your provider happens to stock, named however they named it.
Those inner entries are not sub-channels, they are candidate sources.

That is the same shape Movies and Series already have: one title, several
sources, pick one. `DetailsPage` and `IptvChannelSheet` are the same screen
wearing different words.

So the ❤️ belongs on the tile, not on the streams inside it. The brand is
stable — "UFC" means the same thing next month. A stream is disposable: one
provider's line item, gone when they rotate their list or the user switches
portals, and a favourite pointing at it rots silently. Liking an inner
stream would be liking a specific torrent instead of the film.

And it should surface on the **Live TV page**, not only in Library: someone
about to watch television is on that page, not in their library. Today liked
channels appear nowhere on it at all, which is the real gap — Library
already lists them.

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
TMDB cast photos are unaffected by that secret — `TmdbSettings` carries a
bundled fallback key. They are broken for a different reason entirely; see
bug #38.

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now; a second is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no direct-stream-URL field. IPTV multi-view shipped as an original grid feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is a namespace, not an identifier anything outside the module sees.
- **Merging Movies, Series and Anime into one section.** Asked as "would one streaming category with one search be simpler, and better code?" Measured against the tree, no. **Movies and Series are already one implementation** — `TypeCatalogPage(type: 'movie')` and `TypeCatalogPage(type: 'series')` are the same widget with a different string, and both open the same `DetailsPage`. Merging them removes a navigation entry, not a duplicate: there is no consolidation left to win. **Anime is a different stack on purpose** — `AnimePage` and `anime_details_page.dart` against `AnimeMedia` from AniList, not `MovieDetail` from addons, with its own library service, its own scraper, its own Arabic variant, and a Characters & Cast relation (character to voice actor) that has no equivalent for film. Putting it behind a shared tab would hide two code paths under one label rather than unify them, and flattening its model would cost the anime-native data — AniList scores, seasonal grouping, sub/dub, episode numbering — that is the reason to have the section. The part of the request worth building is the single search, tracked as #48.
