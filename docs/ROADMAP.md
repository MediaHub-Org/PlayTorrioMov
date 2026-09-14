# Project Roadmap — PlayTorrioMov

**The app is in maintenance mode.** This file tracks three things: what is
**open**, what is **waiting on a device**, and which **decisions are
settled** so they do not get re-argued. Shipped work lives in
[CHANGELOG.md](../CHANGELOG.md) and git history — a roadmap that also
carries a changelog stops being readable as either.

Items are numbered and never renumbered or reused, so `#43` means the same
thing in a commit message, a pull request and this file.

Last reconciled against the tree: **2026-09-14**, on `v1.6.0+28`, at commit
`cd2a289`. Every count below was measured at that commit.

---

## Open

### 1. TMDB is quiet on device, and we do not know why

Cast photos and character names do not appear. Three causes on our side are
fixed (see #38, #53 and the TMDB commits); what remains is whether the
bundled API key still works, and `api.themoviedb.org` is blocked from CI, so
that is the one thing that could not be checked from here.

**The next step is one tap.** Open **Settings → Sync → TMDB Cast Photos**
and read the status line under the card:

| What it says | What it means |
|:-------------|:--------------|
| *Loaded N cast and M crew from TMDB* | TMDB is fine — if the row still looks wrong the bug is in the page, not the service |
| *TMDB rejected the API key (401)* | The bundled key is dead. Add your own free key on that same card |
| *Could not reach TMDB* | Network, DNS or a captive portal |
| *TMDB has no entry for this title (404)* | That one title only; try another |
| nothing at all | No request was made — the addon supplied everything, or the IMDb id never resolved |

### 2. Light mode is painted, not finished (#59)

The switch works and the app's colours now follow it: `AppColors` resolves
ink and surfaces against the active theme, ~1500 sites across 60 files read
it, and the dark values are byte-identical to the literals they replaced, so
a dark build is unchanged.

**What is deliberately excluded**, because artwork is artwork in either
theme: the video player (chrome over video, 471 references across 23 files),
the three details pages (a full-height backdrop behind every control), and
anything on an accent fill or over a poster — those use `AppColors.onAccent`,
fixed white in both themes.

**What is left** are one-off dark surface hexes that no token maps —
`0xFF15171F`, `0xFF13151F`, `0xFF0C0F17` and their neighbours, mostly card
and sheet backgrounds in the IPTV and Discover pages. In light mode these
stay dark and the ink on them stays readable, so the result is islands of
dark rather than unreadable text. Each wants a judgement call about which
token it is, which is why the mechanical pass stopped short of them.

### 3. Engineering debt, from the 2026-09-13 audit

What the audit fixed is in git — including the HTTP timeout gap it had
deferred: all 54 `package:http` calls that lacked a deadline now carry one,
enforced by `test/services/http_timeouts_test.dart` (#60). What it found and
deliberately left:

| What | Why it was left |
|:-----|:----------------|
| `iptv_portals_modal` ↔ `live_tv_settings_page` share **45** duplicated 12-line windows | UI duplication, lower stakes than the logic duplication that was fixed. Needs a look at whether the shared part is a widget or a coincidence. |
| **126 empty `catch` blocks** | Most carry a comment explaining why the error is deliberately swallowed. Separating those from genuinely lost errors needs case-by-case reading, not a sweep. |
| `megasource` / `nova` share **49** windows | **Deliberately not merged.** They share an HTTP-and-parse skeleton, but Nova munges stream titles in a way MegaSource does not. Unifying them means a formatting hook whose two implementations have nothing in common — an abstraction added to satisfy a duplication count rather than to remove duplication. |

### 4. The scrapers are effectively untested in CI

**13 of 89 test files are `@Tags(['network'])`** and excluded by
`flutter test --exclude-tags network` — and they are exactly the files
covering `lib/services/scraper` and `lib/services/anime`, the two
least-covered areas. 143 of 370 public classes are named in any test.

That trade is reasonable: those tests hit live third-party sites and would
make CI flaky and slow. The gap it leaves is that a scraper's *parsing* is
only ever exercised against whatever the site returned that day.

The fix is not to un-tag them but to split the pure logic out and test it
offline, the way `glendale_master_url_test` and `subtitle_languages_test`
now do — both written during the audit, both of which found real bugs.
Candidates in order: the per-site HTML/JSON parsers, `SubtitleExtractor`'s
archive and encoding handling, the IPTV playlist parsers.

---

## Waiting on a device

CI can prove a parser handles a shape and a widget lays out at a width. It
cannot tell you whether a stream reaches a TV or whether a tap *feels*
immediate. Each of these is already built and tested as far as it can be.

### Cast, against a real receiver (#28)

1. Does a **movie** reach the TV and play? (Known limit: the Cast SDK has no
   sender-side way to attach Referer/User-Agent, so scraper sources needing
   them fail on the TV while playing fine locally. Try direct/CDN sources.)
2. Does a **Live TV channel** reach the TV, and does the receiver show it as
   live — no seek bar, no phantom duration?
3. Does **disconnect** return playback cleanly?
4. On a stream a receiver *cannot* reach, does tapping Cast explain itself
   rather than doing nothing?

### Series creators (#39)

`created_by` on `/tv/{id}` is fetched only for a series whose `/credits` had
no directing crew. The parser is covered for absent, empty and malformed
fields; what tests cannot confirm is whether the field is **populated in
practice**.

**To answer:** open a series whose director was missing and look for a
*Creator* card. If `created_by` proves thin, the fallback is
`/tv/{id}/aggregate_credits` — a larger payload whose entries carry a `jobs`
array instead of a single `job`, needing a TV-shaped branch in the parser.

### The player, in your hand

Laid out and guarded by tests, but "does it fit" and "does it feel right"
are different questions.

- **Menus in landscape** on the shortest device you have — the speed menu is
  the one that used to run off the top of the screen.
- **Dismissing a panel** never feels stuck, now that there are no close
  buttons (tap off, or the back arrow).
- **Seek amounts:** double-tap the sides for ±10s, centre buttons for ±30s.
- **The CC button** turns on the track matching the audio language — no
  picker, no dialog.
- **Live TV's single tap** reveals the controls immediately.
- **Backup export** (#50) actually lands where you pick it on Android.
- **Simkl** (#51) connects once you paste your own client ID.

---

## Settled decisions

### The two players

Live TV is the Movies/Series/Anime player **with fewer parts**, not a second
player that looks similar. `test/player_convergence_test.dart` guards that:
the shared widgets stay referenced, neither player hand-places a popover,
and no menu grows a close button back.

**What Live TV legitimately lacks**, because a live feed has no use for it:
seeking, a seek bar (a live-edge row sits where it would be — absence alone
read as a control that failed to load), and playback speed.

**A reversed decision, recorded as reversed.** This file used to keep the
Live TV aspect-ratio pill as a deliberate divergence: one setting behind a
gear costs a click rather than saving one. Sound in isolation, wrong against
the larger goal — it was the last control on the page with no counterpart in
the other player, and "same panel, fewer rows" is worth more than the tap.

### Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub; a second
  is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract
  beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no
  direct-stream-URL field. IPTV multi-view shipped as an original grid
  feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is
  a namespace, not an identifier anything outside the module sees.
- **Merging Movies, Series and Anime into one section.** Movies and Series
  are *already* one implementation — `TypeCatalogPage(type: 'movie')` and
  `TypeCatalogPage(type: 'series')` are the same widget with a different
  string, both opening the same `DetailsPage`; merging them removes a
  navigation entry, not a duplicate. Anime is a different stack on purpose:
  `AnimeMedia` from AniList rather than `MovieDetail` from addons, its own
  library service, scraper and Arabic variant, and a character-to-voice-actor
  relation with no equivalent for film. Flattening it would cost the
  anime-native data that is the reason to have the section. The part worth
  building was the single search, shipped as #48.
- **The two recommendation rows on a details page are not duplicates.**
  `relatedItems` is the set the title belongs to, passed in; `_similarItems`
  comes from the BestSimilar scraper.

### Audit results that came back clean

Recorded so they are not re-audited from scratch: no TLS bypass anywhere; no
plaintext `http://` to non-local hosts; no leaked credentials (tokens live in
`flutter_secure_storage`, with a lazy migration off the old plaintext prefs);
no undisposed controllers, timers or subscriptions; no unused dependencies —
the two that look unused in Dart (`media_kit_libs_video`,
`media_kit_libs_windows_video`) ship native libraries and must stay. Every
file in `lib/` is reachable from `main.dart`.

---

## Reference

### Navigation

One hub, five sections, the last always Library:

| Section     | Content                     |
|:------------|:----------------------------|
| **Movies**  | TMDB-catalog movies         |
| **Series**  | TMDB-catalog series         |
| **Anime**   | Its own catalog and scraper |
| **Live TV** | IPTV channels               |
| **Library** | Everything you've saved     |

Phones show sections in the bottom tab bar; tablet and desktop show them as a
chip row under the top bar. Search stays an icon, not a section.

### Upstream sync

PlayTorrioMov began as a fork of `MediaHub-Org/PlayTorrioMod`; that repo is
**archived**, so Mov is the only active app in the family and the direct
downstream of `ayman708-UX/PlayTorrioV3`.

**Reviewed through `f69617b` (2026-09-13). The list is empty.**

Taken: `db2a4b9` and `0343720`, both hardening the Linux CI job against a
`dl.google.com` apt source the runner image ships that periodically breaks
`apt-get update` — ported to **both** `build.yml` and `pr-checks.yml`.

Not taken, with reasons, so they are not re-reviewed:

| Commit | Why not |
|:-------|:--------|
| `9616808` | Blurred dual-layer hero backdrop to kill black bars. Every hero in this fork already uses `BoxFit.cover`, which fills and crops. It fixes a problem we do not have. |
| `29a4127`, `1da1940` | IPTV channels, search and storage — the area this fork has diverged furthest in (#45, #46 and the portal browser are ours). Read as ideas, not ported as patches. |
| `d2f8074` | IPTV portal manager responsiveness. A near-total rewrite of `iptv_portals_modal.dart`; our copy carries Cloud Vault, the modal customizer and the M3U tab, so a straight port would drop them. The reported overflows were hand-fixed in #40 instead — all four, not the two reported. |
| Support Dev sponsor monetization | Out of scope for this fork. |
| Keyboard aspect-cycle HUD | Mov already has an aspect control in the player's settings; a second affordance for one setting is a regression. |

### Signing and releases

Android release signing **is configured** — `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` are both set, so released APKs install over each
other and the in-app updater works (see
[release signing](RELEASES.md#release-signing)). No other platform needs
signing, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

`ENV_FILE`/`DOTENV` is **not set**, and that is the one outstanding release
secret. Every published build ships an empty `.env`, so Trakt sign-in and
Discord Rich Presence are inert in released binaries. TMDB is unaffected —
`TmdbSettings` carries a bundled fallback key (whether it still works is open
item 1). **Simkl is no longer blocked by it** (#51): register a free app at
simkl.com/settings/developer and paste the client ID — Simkl's PIN flow
authenticates with the id alone, so there is no secret to ship.

**`build.yml` has no analyze or test step.** Only `pr-checks.yml` runs them,
and only on a pull request, so a PR merged before its checks finish ships
unverified — that is how v1.5.8 went out. Either wait for `pr-checks` before
merging, or accept that the release build proves only that it compiles.

### Closed items

An index of what each number means, for reading old commits and PRs. #1–#14
closed before this file was rewritten for maintenance mode and are not listed
— they live in git history.

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
| #52 | System / Light / Dark switch (the colour migration is #59) |
| #53 | One ISO-639 table for subtitle providers (two were 51 languages short) |
| #54 | Wyzie subtitle downloads go through `SubtitleExtractor` like the rest |
| #55 | One master-URL builder for cinesrc/cine.su/bcine (was triplicated) |
| #56 | One pipeline for vidfast/vidup (was two ~200-line near-clones) |
| #57 | `print()` out of `lib/`, `avoid_print` enforced as a warning |
| #58 | A silent scraper no longer holds the stream search open forever |
| #59 | The colour migration behind #52 — `AppColors`, and what it excludes (open item 2 is the remainder) |
| #60 | Every `package:http` call carries a timeout, enforced by a test |
