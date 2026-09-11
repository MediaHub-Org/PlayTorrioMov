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
mobile-first value but a large diff to review safely). Next step: review
those two, then check `v3/main` for anything past `3670ae1`, file-by-file
(git history was squashed at the fork point, so nothing arrives via
`git merge`).

## Bugs

From testing the v1.5.7 Android build on a device. The cast-and-crew bug
that caused three of the reported symptoms at once — missing photos, the
role line reading "Cast", and missing directors — is fixed and therefore
gone from this list; see CHANGELOG. #39 is what remains of it, and only
became visible once that landed.

| #  | Bug | What is actually wrong |
|----|-----|------------------------|
| 39 | Series show no director even with a working TMDB id | **Decided: read `created_by` from `/tv/{id}`, label it "Creator".** `/tv/{id}/credits` returns series-level crew, which for most shows is producers and no director — TV directors are per-episode. `created_by` is the showrunner, which is what a viewer means by "whose show is this", and it arrives in the detail response the app can already ask for: one extra request, no new response shape. `/tv/{id}/aggregate_credits` is the heavier alternative — a large payload whose entries carry a `jobs` array instead of a single `job`, needing a TV-shaped branch in `_directingJobs` — so reach for it only if `created_by` proves thin in practice. **Verify against the live API before building**: this is reasoned from the API's documented shape, not yet observed.
| 40 | Text escapes its container in two IPTV places | **Decided: try the upstream port first, timeboxed.** In **IPTV Portals & Playlists** label text renders outside its box, and the **Reddit** button's drop-down renders items outside the menu box; both in `lib/pages/iptv/iptv_portals_modal.dart`. Upstream V3's `d2f8074` is a responsiveness rewrite of that same file (see Upstream sync) and would likely fix both plus more. Read it first: if it ports cleanly, take it; if the diff is too large to review safely, hand-patch the two overflows and leave the port on the upstream list. Do not do both.

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
| 43 | Library: make the three library states the tabs | **Decided** — replaces the earlier two-filter-rows idea; reasoning under *Why Downloads stays in the Library*. Tabs become **Liked / Watchlist / Watched**, with the media-type pills (All, Movies, Series, Anime, Live TV) inside each. Verified safe: `MyListService._applyOrRemove` deletes an item once all three flags are false, so every stored item carries at least one and nothing can fall between the tabs. It also retires a compromise the code already admits to — `LibrarySection.saved`'s own comment says a heart "overclaims" for that bucket and settles for `inventory_2`; with the states promoted to tabs, each gets its right icon. **Drop the Continue tab** — verified redundant, it renders `ContinueWatchingService.activeItems`, the same deduped list the Continue Watching row already shows. **Keep Downloads** (see below). Live TV appears only under Liked, per #45.
| 44 | Player: ±30s skip alongside the existing ±10s, with per-side animation | **Decided.** Requested for Movies, Series and Anime. The double-tap side zones keep ±10s — the convention people arrive with — and ±30s gets explicit buttons in the transport bar. No new gesture to learn, and five controls never share one row. Both paths animate on the side they affect, reusing the existing double-tap ripple rather than introducing a second visual language. |
| 45 | Live TV's ❤️ / ⭐ split, and liked channels having nowhere to live | **Decided — see the reasoning below the table.** Keep ❤️ on the channel tile (the brand), add a **Liked row at the top of the Live TV page**, and demote the portal browser's ⭐ to a plainly-named in-browser bookmark so it stops competing with ❤️. Three stores are in play today: `MyListService.isLiked` (Movies/Series/Anime), `FavoriteChannelsService` (built-in channels, ❤️ in `iptv_channel_sheet`), and `IptvPortalFavoritesStore` (portal streams, ⭐ in the portal browser, keyed by `streamId` and namespaced per portal). The first two reach Library; portal favourites reach nothing. Do **not** merge the stores: a built-in channel id is stable app data, a `streamId` is meaningless outside the portal and credentials it came from. Unify the vocabulary, not the storage. Blocks #43 — "Liked" must mean one thing before it can be a filter. |
| 46 | Custom Live TV channels from a portal stream | **Decided: build it, after #45.** It is what makes the portal browser's star worth demoting rather than deleting. A `HardcodedChannel` is just `{name, category, keywords[], exclude[]}`, so a user-defined one is the same record with the stream's name as its keyword — no new concept, just a second source feeding the same list. Closes a real gap: today, if a portal carries something the built-in catalogue has no entry for, there is no way to give it a tile, like it, or find it again except by re-browsing the portal.
| 47 | Watch history is recorded but never shown | **Decided: surface it as the Continue Watching row's "see all", not a Library tab.** `ContinueWatchingService.historyItems` already keeps every episode watched, up to 100, in its own persisted `continue_watching_history_v1` store; the only consumer is `getHistoryProgress`, reading one entry to resume a position. So the data and the persistence exist and only the view is missing. It does not belong in Library: #43 makes those tabs mean *what you chose to keep*, and history is a record of what happened, not an intent — a fifth tab would also be one too many. Hanging it off the row it belongs to keeps Library coherent and puts history where the user already looks for recent viewing.
| 48 | One search across Movies, Series and Anime | **Decided — see *How #48 fits together*.** The genuinely useful half of "be more like a big streaming platform". There are four search surfaces today — `search_page` (addon movies/shows), `anime_search_page`, `iptv_search_page` and `discover_page` — and `SearchScope` already narrows the icon's behaviour to whichever section you are standing in, so which one you get depends on where you were. One search that queries movies, series and anime together and groups results by type gives the platform feel without collapsing the sections or touching the anime stack. Live TV stays out: channels are matched by keyword against a portal's stream list, not searched by title, and folding them in would mean two different meanings of "result" in one list.

### How #48 fits together

The groundwork is already there, which makes this smaller than it sounds.

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

**Filters.** Under the field: type chips (All / Movies / Series / Anime),
then the existing `FilterDropdown` pills for genre / year / sort — the same
widget the catalog header already uses, so this is reuse, not new UI. With
**All** selected, group results by type under headings rather than
interleaving them.

**The other search pages.** `anime_search_page.dart` is 918 lines and most
of that is anime-native filtering (AniList genre, season, format) that has
no movie equivalent. Absorb those as options that appear when the Anime chip
is active, rather than deleting the page wholesale and losing them.

**Live TV stays out, at first.** Its search filters a channel and stream
list by keyword; it does not search a title catalogue, so a result there is
a different kind of object. Leaving its `onTap` override in place is the
honest version: one rule, legible — *in Live TV you search channels,
everywhere else you search titles*. A later pass can add a Live TV chip
whose results render as channel cards, once the result list is ready to hold
two shapes.

### Why Downloads stays in the Library (#43)

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

### Why #45 lands where it does

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
