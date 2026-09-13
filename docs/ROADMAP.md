# Project Roadmap — PlayTorrioMov

**The app is in maintenance mode.** Every numbered feature item is closed;
what this file tracks now is what is *known broken*, what is *waiting on a
device*, and which decisions are settled so they do not get re-argued.
Shipped work lives in [CHANGELOG.md](../CHANGELOG.md) and git history, not
here — a roadmap that also carries a changelog stops being readable as
either.

Items are numbered and never renumbered, so `#43` means the same thing in a
commit message, a pull request and this file. Numbers are not reused when an
item closes.

Last reconciled against the tree: **2026-09-13**, on `v1.5.8+27`.

---

## Open

### Bugs

| # | What | State |
|:--|:-----|:------|
| — | TMDB shows no cast photos and no character names on a real device | **Investigating** — see below |

**TMDB enrichment is quiet on device and we do not yet know why.** Three
things were wrong on our side and are fixed:

1. The missing-character fallback printed the literal word *"Cast"*, which
   reads as a role every actor shares rather than as absent data. The second
   line is blank now, with its height reserved so one uncredited actor
   cannot shorten a column.
2. Enrichment short-circuited on `hasPhotos && hasCrew`. Character names are
   the third part of that row and were not in the test, so an addon that
   sent photos and a director stopped the lookup cold.
3. Nothing said *why* when TMDB itself was the problem. Every failure in
   `TmdbService` is swallowed on purpose — a dead key should cost cast
   photos, not the details page — which left a rejected key looking exactly
   like a working one on the Settings card.

**The next step is yours, and it is one tap:** open **Settings → Sync →
TMDB Cast Photos** and read the status line under the card. It now reports
the most recent request's outcome.

| What it says | What it means |
|:-------------|:--------------|
| *Loaded N cast and M crew from TMDB* | TMDB is fine; if the row still looks wrong the bug is in the page, not the service |
| *TMDB rejected the API key (401)* | The bundled key is dead or revoked — add your own free key on that same card |
| *Could not reach TMDB* | Network, DNS or a captive portal |
| *TMDB has no entry for this title (404)* | That one title only; try another |
| nothing at all | No request was made — the addon supplied everything, or the IMDb id never resolved |

`api.themoviedb.org` is blocked from the CI environment, so whether the
bundled key is live is exactly the thing that could not be checked from
here. That status line is how it gets checked.

### Light mode is wired up but not painted

The theme switch (System / Light / Dark) is in **Appearance & Interface**,
persisted, defaulting to the system setting, and `MaterialApp` now carries
a real `theme`/`darkTheme` pair. Each palette derives light surfaces from
its own hue, so the eight themes stay distinguishable rather than all
becoming the same off-white.

**What is not done is the app's own colours.** Roughly **1300
`Colors.white` references and 978 hardcoded hex values across 79 files**
ignore the theme entirely — 22 pages paint their own dark `Scaffold`, 12
their own dark `AppBar`. So selecting Light gives a correct Appearance &
Interface page (migrated in full, to prove the mechanism end to end) and a
still-dark everything-else.

Finishing it is mechanical but wide: replace hardcoded colours with
`Theme.of(context).colorScheme` / `cardTheme` tokens, page by page. It
wants doing as its own systematic pass rather than a page at a time,
because half-migrated is the one state that looks broken rather than
merely inconsistent.

### Code and consistency

**None open.** Every browse section renders through `BrowseScaffold` and
`BrowseRowView`; the three details pages share one spine and one section
heading (#41); and both players now draw from the same widgets — see
*The two players* below.

### Requested UI work

**None open.**

---

## Waiting on a device

CI can prove a parser handles a shape and a widget lays out at a width. It
cannot tell you whether a stream reaches a TV or whether a tap *feels*
immediate. These are the open questions, each already built and tested as
far as it can be.

### 1. Cast, against a real receiver (#28)

The sender path has been read for defects and had two, both fixed:
`streamType` was hardcoded to `buffered` (a live channel announced that way
gets a seek bar and a duration the receiver cannot honour), and `.ts` was
being called `video/mp4` (IPTV portals serve MPEG-TS constantly, and that
hands the receiver a demuxer that cannot read it).

The button is also no longer hidden on most sources: it used to be gated on
*"is this a torrent"*, when what actually matters is whether the receiver
can reach the host. A torrent resolved through a debrid or served from
another machine is as fetchable as any CDN; only this device's own loopback
is not.

**To answer:**

1. Does a **movie** reach the TV and play? (Known limit: the Cast SDK has no
   sender-side way to attach Referer/User-Agent, so scraper sources needing
   them fail on the TV while playing fine locally. Try direct/CDN sources.)
2. Does a **Live TV channel** reach the TV, and does the receiver show it as
   live — no seek bar, no phantom duration?
3. Does **disconnect** return playback cleanly?
4. On a stream a receiver *cannot* reach, does tapping Cast now explain
   itself rather than doing nothing?

### 2. Series creators (#39)

`created_by` on `/tv/{id}` is the showrunner, fetched only for a series
whose `/credits` had no directing crew. The parser is covered by tests for
an absent, empty and malformed field — being wrong costs nothing, it just
yields no crew, which is today's behaviour. What tests cannot confirm is
whether the field is **populated in practice**.

**To answer:** open a series whose director was missing and look for a
*Creator* card. `/tv/{id}/aggregate_credits` is the heavier fallback if
`created_by` proves thin — a large payload whose entries carry a `jobs`
array instead of a single `job`, needing a TV-shaped branch in the parser.

### 3. The player, on a phone in your hand

Everything here is laid out and guarded by tests, but "does it fit" and
"does it feel right" are different questions.

- **The menus fit the screen.** The speed menu used to run off the top of a
  landscape phone. Every popover now goes through `PlayerMenuAnchor`, which
  bounds it top *and* bottom and scrolls the difference. Worth checking in
  landscape on the shortest device you have.
- **No close buttons.** Tapping off a panel dismisses it; the back arrow
  returns to the settings root. Check that dismissing never feels stuck.
- **Audio track leads the settings list**, ahead of subtitles, speed and
  aspect.
- **Seek amounts:** double-tap the sides for ±10s, the centre buttons for
  ±30s. Two ways in, two different amounts.
- **The CC button is a plain on/off**, and what it turns on is the track
  matching the audio language — no picker, no dialog. Track and style
  selection live behind the gear.
- **Live TV's single tap** should reveal the controls immediately; it used
  to wait out the double-tap window.

---

## The two players

Live TV is meant to be the Movies/Series/Anime player **with fewer parts** —
not a second player that happens to look similar. Both now draw from the
same widgets: `PlayerIconButton`, `PlayerCenterControls`,
`PlayerVolumeControl`, `PlayerSettingsMenu`, `PlayerAspectMenu` and
`PlayerMenuAnchor`.

`test/player_convergence_test.dart` guards the shape, because the drift is
always the same one: a control gets hand-rolled on one page instead of
reaching for the shared widget. It asserts the shared widgets stay
referenced, that neither player hand-places a popover, and that no menu
grows a close button back.

**What Live TV legitimately lacks**, because a live feed has no use for it:
seeking (the centre buttons' callbacks go null and the play button stands
alone), a seek bar (a live-edge row sits where it would be, because absence
alone read as a control that failed to load), and playback speed (the
settings row is optional for exactly this).

**A note on a reversed decision.** This file used to record the Live TV
aspect-ratio pill as a divergence kept on purpose — one setting behind a
gear costs a click rather than saving one. That reasoning was sound in
isolation and wrong against the larger goal: it was the last control on the
page with no counterpart in the other player, and "same panel, fewer rows"
is worth more than the tap. It is the shared gear now.

---

## Navigation

One hub, five sections, the last always Library:

| Section      | Content                        |
|:-------------|:-------------------------------|
| **Movies**   | TMDB-catalog movies            |
| **Series**   | TMDB-catalog series            |
| **Anime**    | Its own catalog and scraper    |
| **Live TV**  | IPTV channels                  |
| **Library**  | Everything you've saved        |

Phones show sections in the bottom tab bar; tablet and desktop show them as
a chip row under the top bar. Search stays an icon, not a section.

---

## Upstream sync

PlayTorrioMov originated as a fork of `MediaHub-Org/PlayTorrioMod`; that repo
is now **archived**, so Mov is the only active app in the family and the
direct downstream of upstream `ayman708-UX/PlayTorrioV3`.

**Reviewed through `f69617b` (2026-09-13). The list is empty.**

Taken: `db2a4b9` and `0343720`, both hardening the Linux CI job against a
`dl.google.com` apt source the runner image ships that periodically breaks
`apt-get update` — ported to **both** `build.yml` and `pr-checks.yml`.

Not taken, with reasons, so they are not re-reviewed:

| Commit | Why not |
|:-------|:--------|
| `9616808` | Blurred dual-layer hero backdrop to kill black bars. Every hero in this fork already uses `BoxFit.cover`, which fills and crops. It fixes a problem we do not have. |
| `29a4127`, `1da1940` | IPTV channels, search and storage — the area this fork has diverged furthest in (#45, #46 and the portal browser are ours). Read as ideas, not ported as patches. |
| `d2f8074` | IPTV portal manager responsiveness. A near-total rewrite of `iptv_portals_modal.dart`; our copy carries Cloud Vault, the modal customizer and the M3U tab, so a straight port would drop them. The reported overflows were hand-fixed in #40 instead — all four of them, not the two reported. |
| Support Dev sponsor monetization | Out of scope for this fork. |
| Keyboard aspect-cycle HUD | Mov already has an aspect control in the player's settings; a second affordance for one setting is a regression. |

---

## Signing and releases

Android release signing **is configured** — `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` are both set. Released APKs therefore install
over each other and the in-app updater works. See
[release signing](RELEASES.md#release-signing). No other platform needs
signing for updates, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

`ENV_FILE`/`DOTENV` is **not** set, and that is the one outstanding release
secret. Every published build ships an empty `.env`, so Trakt sign-in and
Discord Rich Presence are inert in released binaries.

**Simkl is no longer stuck behind it** (#51): the user can register a free
app at simkl.com/settings/developer and paste its client ID into the Simkl
card. Simkl's PIN flow authenticates with the id alone, so there is no
secret to ship. Setting `ENV_FILE` would still make it work out of the box.

TMDB is *not* affected by that secret — `TmdbSettings` carries a bundled
fallback key. Whether that key still works is the open bug above.

**One thing to know about the release pipeline:** `build.yml` has **no
analyze or test step**. Only `pr-checks.yml` runs them, and only on a pull
request. A PR merged before its checks finish ships unverified — that is how
v1.5.8 went out, with the version pin confirmed by reading `pubspec.yaml`,
`app_info.dart` and the CHANGELOG off `main` directly instead. Either wait
for `pr-checks` before merging, or accept that the release build proves only
that it compiles.

---

## Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub now; a
  second is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract
  beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no
  direct-stream-URL field. IPTV multi-view shipped as an original grid
  feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is
  a namespace, not an identifier anything outside the module sees.
- **Merging Movies, Series and Anime into one section.** Measured against the
  tree, no. Movies and Series are *already* one implementation —
  `TypeCatalogPage(type: 'movie')` and `TypeCatalogPage(type: 'series')` are
  the same widget with a different string, both opening the same
  `DetailsPage`. Merging them removes a navigation entry, not a duplicate.
  Anime is a different stack on purpose: `AnimeMedia` from AniList rather
  than `MovieDetail` from addons, its own library service, its own scraper,
  its own Arabic variant, and a character-to-voice-actor relation with no
  equivalent for film. Flattening it would cost the anime-native data —
  AniList scores, seasonal grouping, sub/dub, episode numbering — that is the
  reason to have the section. The part of the request worth building was the
  single search, shipped as #48.
- **The two recommendation rows on a details page are not duplicates.**
  `relatedItems` is the set the title belongs to, passed in; `_similarItems`
  comes from the BestSimilar scraper. Recorded so it is not re-flagged.

---

## Closed items

For the reasoning behind any of these, read the commit — each was written to
be the record.

| # | Item |
|:--|:-----|
| #15 | Mobile-first, made checkable (`test/mobile_first_test.dart`) |
| #21 | The logo's film-strip rule |
| #28 | Google Cast — sender path fixed; receiver test is above |
| #38 | Cast and crew actually load |
| #39 | Series creators — device check is above |
| #40 | IPTV portal modal overflows (four, not two) |
| #41 | One details spine and one section heading |
| #42 | The Live TV player converged on the shared controls |
| #43 | Library tabs became the three states |
| #44 | One amount per seek control (±10s double-tap, ±30s buttons) |
| #45 | Live TV Liked row and portal pin |
| #46 | Channels you make yourself |
| #47 | Watch history |
| #48 | One search across Movies, Series and Anime |
| #49 | Settings scroll from anywhere in the window, not just the centre column |
| #50 | Backup export/import through the system file picker |
| #51 | User-supplied Simkl client ID, and a reason when Connect fails |
| #52 | System / Light / Dark switch (light mode's colour migration is open, above) |
