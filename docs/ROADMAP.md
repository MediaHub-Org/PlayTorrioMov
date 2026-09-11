# Project Roadmap — PlayTorrioMov

What is **outstanding**. Shipped work is tracked in [CHANGELOG.md](../CHANGELOG.md)
and git history, not here.

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

Ordered by blast radius. **#38 is the one to do first** — it is the single
cause of three separate symptoms reported from the device, and #39 is only
visible once it lands.

| #  | Bug | What is actually wrong |
|----|-----|------------------------|
| 38 | Cast and crew have no photos, no character names, and usually no director | **TMDB is never called.** `_fetchCastFromTmdb` returns on its first line unless `MovieDetail.tmdbId` is set, and that field is populated from exactly one place: `json['moviedb_id']` (`movie_detail.dart:85`). Cinemeta and most Stremio addons send `imdb_id`, not `moviedb_id`, so `tmdbId` is null for essentially every title and the request is never made. What renders is the addon's own `cast` — plain name strings, no photos, no characters — which is why the role line falls back to the literal "Cast". **The bundled TMDB key is not implicated**: no request reaches it. Fix: when `tmdbId` is null and the id looks like `tt…`, resolve it through TMDB's `/find/{id}?external_source=imdb_id` first, then carry on. Worth caching the resolved id per title. |
| 39 | Series show no director even with a working TMDB id | Separate from #38 and hidden behind it. `/tv/{id}/credits` returns *series-level* crew, which for most shows lists producers and no director at all — TV directors are per-episode. TMDB exposes the useful answers elsewhere: `created_by` on `/tv/{id}` (the showrunner, which is what a viewer means by "who made this") and `/tv/{id}/aggregate_credits` for crew aggregated across episodes, whose entries carry a `jobs` array rather than a single `job`, so `TmdbService._directingJobs` needs a TV-shaped branch. Verify against the real API before building — this is reasoned from the API's shape, not yet observed. |
| 40 | Text escapes its container in two IPTV places | In **IPTV Portals & Playlists**, label text renders outside its box; the **Reddit** button's drop-down renders its items outside the menu box. Both in `lib/pages/iptv/iptv_portals_modal.dart`. Upstream V3's `d2f8074` is a responsiveness rewrite of this same file (see Upstream sync) — check whether porting it fixes these before hand-patching, so the work is not done twice. |

## Code and consistency

Every browse section — Movies/Series, Anime and Live TV — renders through
`BrowseScaffold` and `BrowseRowView`, so "the same kind of page" is one
implementation. What is still uneven is the *information* inside those
pages, and the players.

| #  | Task | Details |
|----|------|---------|
| 41 | Standardise what a details page shows across Movies, Series and Anime | Right now the three answer different questions. Movies/Series show Cast & Crew (when #38 lets them); Anime shows Characters & Cast, which is a different relation — character to voice actor. Decide the common spine — title, year, rating, genres, synopsis, credits, episodes — and what each section is allowed to add on top, then make the three match. Do this **after** #38, because today's inconsistency is partly just missing data. |
| 42 | Standardise the Live TV player against the Movies/Series/Anime one | Cannot mean "identical": a live stream has no duration, so no seek bar, no resume, no ±N skip. What should match is everything that is not seek — control layout and iconography, the settings menu (audio track, aspect ratio), gesture zones, and the way the overlay appears and auto-hides. Worth writing down which controls are meaningless for live before starting. |

## Requested UI work

| #  | Task | Details |
|----|------|---------|
| 15 | Design mobile-first, as a standing policy | Not a single fix — design new/reworked screens for mobile first, then scale up. `AppSpacing.pageInset` is the mobile-first gutter to build against. The converged page gutter itself is now verified on real Android hardware. |
| 21 | Logo: add a film-strip/clapperboard line accent | On top of the current wordmark/`SidebarLogo`. A design call (icon choice, placement, prominence), not a quick code fix. |
| 28 | Google Cast: verify the actual cast-a-stream flow | The app itself is now verified on real Android hardware, but that didn't cover Cast specifically — still need a Cast-capable receiver on the network to confirm `lib/services/cast/cast_service.dart` actually casts a stream end to end, on both Android and iOS. |
| 43 | Library: make the three library states the tabs | Replaces the earlier two-filter-rows idea. Tabs become **Liked / Watchlist / Watched**, with the media-type pills (All, Movies, Series, Anime, Live TV) inside each. Verified safe: `MyListService._applyOrRemove` deletes an item once all three flags are false, so every stored item carries at least one and nothing can fall between the tabs. It also retires a compromise the code already admits to — `LibrarySection.saved`'s own comment says a heart "overclaims" for that bucket and settles for `inventory_2`; with the states promoted to tabs, each gets its right icon. **Drop the Continue tab** — verified redundant, it renders `ContinueWatchingService.activeItems`, the same deduped list the Continue Watching row already shows. **Keep Downloads** (see below). Live TV appears only under Liked, per #45.
| 44 | Player: ±30s skip alongside the existing ±10s, with per-side animation | Requested for Movies, Series and Anime. **Arrangement decided:** the double-tap side zones keep ±10s — the convention people arrive with — and ±30s gets explicit buttons in the transport bar. No new gesture to learn, and five controls never share one row. Both paths animate on the side they affect, reusing the existing double-tap ripple rather than introducing a second visual language. |
| 45 | Live TV's ❤️ / ⭐ split, and liked channels having nowhere to live | **Decided — see the reasoning below the table.** Keep ❤️ on the channel tile (the brand), add a **Liked row at the top of the Live TV page**, and demote the portal browser's ⭐ to a plainly-named in-browser bookmark so it stops competing with ❤️. Three stores are in play today: `MyListService.isLiked` (Movies/Series/Anime), `FavoriteChannelsService` (built-in channels, ❤️ in `iptv_channel_sheet`), and `IptvPortalFavoritesStore` (portal streams, ⭐ in the portal browser, keyed by `streamId` and namespaced per portal). The first two reach Library; portal favourites reach nothing. Do **not** merge the stores: a built-in channel id is stable app data, a `streamId` is meaningless outside the portal and credentials it came from. Unify the vocabulary, not the storage. Blocks #43 — "Liked" must mean one thing before it can be a filter. |
| 46 | Custom Live TV channels from a portal stream | Optional follow-on to #45, and the reason its ⭐ is worth keeping rather than deleting. A `HardcodedChannel` is just `{name, category, keywords[], exclude[]}`, so a user-defined one is the same record with the stream's name as its keyword — no new concept, just a second source for the same list. Closes a real gap: today, if a portal carries something the built-in catalogue has no entry for, there is no way to give it a tile, like it, or find it again except by re-browsing the portal. |
| 47 | Watch history is recorded but never shown | `ContinueWatchingService.historyItems` keeps every episode watched, up to 100, in its own `continue_watching_history_v1` store — and nothing renders it. The one consumer is `getHistoryProgress` in the player, which reads a single entry to resume that episode's position. So the data for a History view already exists and is already persisted; there is just no view. Worth deciding rather than leaving ambiguous: either surface it (a natural home once the Continue tab leaves under #43, and the only way to see anything older than the deduped Continue row) or stop maintaining the list and keep only the per-episode position lookup.
| 48 | One search across Movies, Series and Anime | The genuinely useful half of "be more like a big streaming platform". There are four search surfaces today — `search_page` (addon movies/shows), `anime_search_page`, `iptv_search_page` and `discover_page` — and `SearchScope` already narrows the icon's behaviour to whichever section you are standing in, so which one you get depends on where you were. One search that queries movies, series and anime together and groups results by type gives the platform feel without collapsing the sections or touching the anime stack. Live TV stays out: channels are matched by keyword against a portal's stream list, not searched by title, and folding them in would mean two different meanings of "result" in one list.

### How #48 fits together

The groundwork is already there, which makes this smaller than it sounds.

**There are not several search icons.** `PageSearchButton` is one shared
widget, already rendered in the same header pill-row slot by
`type_catalog_page`, `anime_page` and `iptv_page`. Anime and Live TV simply
pass an `onTap` override to divert it to their own page. So "unify the
entry points" is, mechanically, deleting two `onTap:` arguments.

**Keep the icon in the header pill row; do not add a second one next to
Settings.** It already sits in one consistent place, grouped with the
filters it relates to, and within thumb reach on a phone. A global icon next
to Settings would either duplicate it or force the pill out, and Settings is
a different kind of destination — configuration, not content.

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
