# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-10-08**, on `v1.9.7+55`.

---

## Pending

Device checks; none of these can be settled from the code.

- **Cast.** Casting from the middle of a movie should start there and pause
  the phone; "Stop casting" should end the session. A scraper source that
  needs Referer/User-Agent still has no sender-side way to send them (#79),
  and whether a phone can cast its own torrent is one `curl` away (see
  `CastService.canCastUrl`).
- **Android notification.** Play/Pause should follow the player, and Android
  13+ should now ask for notification permission on launch.
- **Similar Content** on a movie and a series (TMDB first, BestSimilar as the
  fallback).
- **The loading logo** with a torrent, a debrid link and a plain URL, and
  that it clears on the first frame.
- **TV focus audit.** With a remote, go through: the Sources page (the four
  filter pills, then OK on each: the menu should open on the selected row and
  Back should return to the same pill; let the search run and watch that focus
  stays put when the add-on pill appears), the in-player Sources and Episodes
  panels, the Cast sheet, Library and Collections, Live TV sources, Discover
  and Catalog sort pills, and the video settings cards. Every row should show a
  wash under the remote, and a mouse should light it lighter. After touching the
  screen with a mouse or a remote app, the focus cue should stay.
- **Debrid with a real account.** Set up TorBox (or Premiumize, AllDebrid or
  Debrid-Link), switch "use debrid for streams" on and open a popular title:
  releases the service has should wear a green "Cached" badge and lead their
  language group, and one of them should start in a second or two. If no badge
  ever appears with a service that should have one, run it once with a
  debug build and read the `[DebridCache]` lines: they say whether the lookup
  was refused or came back in a shape this does not recognize. Real-Debrid has
  no lookup and shows none, by design. The card on the sources page should
  show for someone without debrid, go away on "Not now" for good, and not
  show once debrid is on.
- **Skipping around.** Hold the right arrow on a network stream: the bar
  should move at once and the picture should jump every so often, not freeze
  until the key is released. Try it on a torrent and on a debrid link.
- **Language and playback on a real connection.** On a device set to Spanish
  (or any of the thirteen languages the detector knows): the source list should
  open on releases in that language; a file with several audio tracks should
  open on that track; with foreign audio and an embedded subtitle in your
  language, that subtitle should come on by itself. Then on the slow
  connection: does it stop and wait once instead of stuttering, does the stats
  panel's sentence name the cause, does "Playback keeps pausing" appear after
  repeated stalls, and does a jump back come out of the cache.
- **TV: details, loading screen and speed menu.** Opening a title's details
  with a remote should land on Play, and Down/Right should reach the library
  buttons and then the rails with no genre tags in between. The loading screen
  should show the title's logo (or its name) above the filling logo, and the
  episode under it. The speed menu should stay open while Left/Right step the
  speed, close on OK or Back, and have no frame around the slider.
- **The subtitle panel on a TV and a phone.** Opening it should put the
  violet wash on "Turn subtitles on" with a remote and show nothing lit with a
  finger; Refresh appears only on the Online tab; a file with a full and a
  "Signs & Songs" track of one language should list them as two different
  rows.

---

## Planned

Written plans, not started. Each says what is known, what is a guess, and what
has to be measured first.

| Plan                                                | Status                                                                                                                       |
|:----------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------|
| [MAINTENANCE_PLAN.md](MAINTENANCE_PLAN.md)         | Step 1 (mechanical dedupe) is done; next is the 37 deprecations it uncovered, then one press/hover/focus primitive, the big pages, and the player last. |
| [PLAYBACK_PLAN.md](PLAYBACK_PLAN.md)                | Done: diagnosis in the stats panel (with "Copy diagnostics"), release ranking by language / already-on-debrid / weight / tier / seeders, the link ceiling learned from stalls, an offer to change source after repeated stalls, a rebuffer cushion, a bigger rewind cache, faster probing, and burst seeks as one seek. Debrid has a Cached badge, cached-first ranking and a one-time explanation, **unverified against a live account**. **Open: Step 0.2 (one TV session).** True stream adaptation is possible for HLS only; a server of our own is not planned. |

---

## Not doing, so it stays decided

| What                                                     | Why not                                                                                                                                                                                                                                                                                                                                                       |
|:---------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Xtream/portal movies and series as parent sources (#77)  | **Not viable right now.** Needs a pipeline, not a tab: match entries to catalog titles (ids where the feed has them, guarded title-plus-year where not), play through the existing details/player so history sees one title, and decide where unmatchable entries live. A wrong match in Films is worse than an honest gap. Portals stay Live TV only         |
| Size/sort filter under Sources & Filters                 | Browsing choices for *this* title, not a standing preference; they stay on the sources screen                                                                                                                                                                                                                                                                 |
| Keyboard shortcut for the subtitle panel                 | `A`, `S`, `R`, `C` are taken. Revisit if a key frees up                                                                                                                                                                                                                                                                                                       |
| Merge `megasource` / `nova`                              | Shared skeleton, but Nova munges titles MegaSource does not; unifying them needs a hook with nothing in common between its two sides                                                                                                                                                                                                                          |
| Offline tests for page scraping                          | Input is one host's markup on one day, so a fixture pins that day. Ciphers and response formats are covered                                                                                                                                                                                                                                                   |
| Cast from Windows                                        | Google ships no Cast sender SDK for Windows; it would be DLNA/UPnP, a feature not a fix                                                                                                                                                                                                                                                                       |
| Sponsor/monetization, aspect-cycle HUD (upstream)        | Out of scope; the player settings already have an aspect control                                                                                                                                                                                                                                                                                              |
| Single-select audio filter                               | "English or Spanish" needs multi-select; the checkmark delay was a stale-rows bug, since fixed                                                                                                                                                                                                                                                                |
| Alphabetical online subtitle order                       | The list leads with the language being heard on purpose                                                                                                                                                                                                                                                                                                       |
| Translating catalog descriptions, AniList genres/formats | Addon and AniList data, sent back to their APIs to filter; would need a display-name map per language. See CONVENTIONS                                                                                                                                                                                                                                        |
| Trakt sync (card in Settings → Sync)                     | Decided off, not deleted (`_traktSyncEnabled = false` in `sync_settings_page.dart`): registering a *new* Trakt API app now needs paid VIP, which makes it impractical next to Simkl's free one. Simkl is the one the app offers. `TraktService`/`TraktSettings` and the pasted-credentials path stay in place -- see [SYNC_AND_BACKUP.md](SYNC_AND_BACKUP.md) |

---

## Waiting on a decision

| What                                 | Status                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|:-------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mega backup | Dropbox is built and configured (`DROPBOX_APP_KEY` set; settings card, auto-backup prefers it over WebDAV). Google Drive was built then removed in favor of Dropbox alone -- see [SYNC_AND_BACKUP.md](SYNC_AND_BACKUP.md)'s "Google Drive: built, then removed". Mega is still open (proprietary login, no mature Dart SDK). "Auto" is settled as "at app open". **Local dev only**: `DROPBOX_APP_KEY` lives in the gitignored root `.env`; public release builds still need it added to the `ENV_FILE`/`DOTENV` repo secret (append, don't overwrite -- it also carries TMDB/Trakt/Simkl) before a tagged build has working Dropbox |
| Simkl custom-list writes | The Custom Lists API is read-only beta (reads need AUTH V2 + PRO/VIP; adding/removing items is web-only, and a POST returns 200 while changing nothing). Nothing to build against until Simkl ships writes -- the watchlist/history/ratings/collection sync the app actually uses is unaffected. See [SYNC_AND_BACKUP.md](SYNC_AND_BACKUP.md)'s "Moving a Trakt library to Simkl" |

---

## Reference

### Upstream sync

PlayTorrioMov began as a fork of `MediaHub-Org/PlayTorrioMod` (archived), the
direct downstream of `ayman708-UX/PlayTorrioV3`. **Reviewed through `61098a5`
(2026-10-08)** -- took the Oct 2/5 bitrate batch (upstream PR #50: title
parsing on `StreamSource`, the HLS `StreamBitrateResolver`, bitrate badges
on both source cards, ported onto this fork's rewritten player with UTF-8
and in-flight fixes of its own). Not taken, so not re-reviewed:
`39b736f`'s CloudStream extension system (a plugin ecosystem, a feature not a
fix) and its Kotlin-side coroutine fix; `9616808`, a blurred hero backdrop for
a problem we do not have; and `29a4127`, `1da1940`, `d2f8074`, in the area this
fork has diverged furthest (#45, #46, the portal browser), read as ideas and
hand-fixed instead (#40).
