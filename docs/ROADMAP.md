# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-10-26**, on `v1.9.11` (dispatched as a full release, not a
dev prerelease). The repo is private, so nothing is published publicly; builds are
made locally, and CI builds stay private in GitHub.

---

## Waiting on you

All five device checks below were run on 2026-10-26 and came back clean --
nothing needed fixing before cutting v1.9.11. Specific findings (exact shows
checked, diagnostics output, etc.) weren't recorded here since they weren't
reported; if anything surfaces after more use, reopen the relevant line.

- ~~Profile sync across devices.~~ Verified with two devices.
- ~~Simkl Connect on a store build.~~ Verified.
- ~~Anime while AniList is down (Kitsu fallback).~~ Verified on a device.
- ~~Anime seasons.~~ Verified on a device.
- ~~Anime episode arrows.~~ Verified on a device, no defect found.
- ~~Anime episode names.~~ Verified on a device, no defect found.

One item stays open, not covered by the above:

- **PLAYBACK_PLAN.md Step 0.2** (one TV session with the stats panel's "Copy
  diagnostics" open) still needs that specific pasted output to measure the
  hypotheses it gates -- a general "TV playback was clean" doesn't give the
  numbers Step 0.2 is asking for. See that plan.

---

## Planned

Written plans, not started. Each says what is known, what is a guess, and what
has to be measured first.

| Plan | Status |
|:-----|:-------|
| [MAINTENANCE_PLAN.md](MAINTENANCE_PLAN.md) | Step 1 is done, including the 37 deprecations and the ignore that hid them. The device checks Step 2 was waiting on are now clean (see above), so it's unblocked -- not started yet. Then the big pages, and the player last. |
| [PLAYBACK_PLAN.md](PLAYBACK_PLAN.md) | Done: stats-panel diagnosis with "Copy diagnostics", release ranking, a learned link ceiling, a source offer after repeated stalls, a rebuffer cushion, a bigger rewind cache, faster probing, burst seeks as one seek, and the debrid Cached badge with cached-first ranking (**not verified against a live account**). Open: Step 0.2 needs a session with diagnostics actually copied -- a clean TV session happened 2026-10-26 but without that paste. Stream adaptation is HLS-only; a server of our own is not planned. |

---

## Not doing, so it stays decided

| What | Why not |
|:-----|:--------|
| Xtream/portal movies and series as parent sources (#77) | **Not viable right now.** It needs a pipeline, not a tab: match entries to catalog titles (by id where the feed has one, guarded title-plus-year where not), play through the existing details and player so history sees one title, and decide where unmatchable entries live. A wrong match in Films is worse than an honest gap. Portals stay Live TV only. |
| Size/sort filter under Sources & Filters | Browsing choices for *this* title, not a standing preference; they stay on the sources screen. |
| Keyboard shortcut for the subtitle panel | `A`, `S`, `R`, `C` are taken. Revisit if a key frees up. |
| Merge `megasource` / `nova` | Shared skeleton, but Nova munges titles MegaSource does not. Unifying them needs a hook with nothing in common between its two sides. |
| Offline tests for page scraping | The input is one host's markup on one day, so a fixture pins that day. Ciphers and response formats are covered. |
| Cast from Windows | Google ships no Cast sender SDK for Windows. It would be DLNA/UPnP, a feature, not a fix. |
| Sponsor/monetization, aspect-cycle HUD (upstream) | Out of scope; the player settings already have an aspect control. |
| Single-select audio filter | "English or Spanish" needs multi-select. The checkmark delay was a stale-rows bug, since fixed. |
| Alphabetical online subtitle order | The list leads with the language being heard, on purpose. |
| Translating catalog descriptions, AniList genres/formats | Addon and AniList data, sent back to their APIs to filter. It would need a display-name map per language. See CONVENTIONS. |
| Trakt sync (card in Settings → Sync) | Decided off, not deleted (`_traktSyncEnabled = false` in `sync_settings_page.dart`). Registering a *new* Trakt API app now needs paid VIP, which makes it impractical next to Simkl's free one. `TraktService`, `TraktSettings` and the pasted-credentials path stay in place. See [SYNC_AND_BACKUP.md](SYNC_AND_BACKUP.md). |
| Mega backup | **Decided against.** Mega has no official Dart SDK, so its login and client-side crypto would be a reimplementation, and it needs the user's Mega email and password stored in the app. Cloud backup already works without a password: Dropbox (OAuth, nothing stored) and WebDAV (the user's own server). Revisit if Mega ships an official Dart SDK, or if storing the password is accepted explicitly. See [SYNC_AND_BACKUP.md](SYNC_AND_BACKUP.md). |
| Remove the centered play/pause button | **Decided: keep it.** It is where a TV remote's first arrow lands when the controls reappear (#80), and the single tap and double tap are already taken (show controls; fullscreen and the ±10s zones). If the look is the complaint, a lighter visual version is the option, not removal. |
| Public release and the in-app update check | **Paused, 2026-10-23.** The repo is private, so the release downloads, the update check (`releases/latest`) and the About link answer 404 to anyone outside the org. The app itself works; the updater finds no update and says nothing. Revisit if the repo goes public, or if the releases move to a public mirror. |
| LAN sync with a QR code between devices | **Not built, 2026-10-23.** It needs a scan at every sync and both devices on the same network. The gist profile sync covers the same data once per device. See SYNC_AND_BACKUP.md, "Choosing how to sync". |
| Simkl custom-list writes | **Blocked upstream.** Simkl's Custom Lists API is read-only beta (reads need AUTH V2 and PRO/VIP), and a POST returns 200 while changing nothing. Revisit when Simkl ships writes. The watchlist, history and ratings sync is unaffected. |

---

## Reference

### Upstream sync

The fork's upstream, `ayman708-UX/PlayTorrioV3`, returns 404 as of 2026-10-19,
so there is nothing to sync from. The last reviewed state is `61098a5`
(2026-10-08). The Oct 2/5 bitrate batch (upstream PR #50) was taken and ported,
with UTF-8 and in-flight fixes of its own. Not taken: `39b736f`'s CloudStream
extension system (a feature, not a fix) and its Kotlin coroutine fix; `9616808`,
a blurred hero backdrop for a problem we do not have; and `29a4127`, `1da1940`,
`d2f8074`, read as ideas and hand-fixed instead (#40). Re-check if the repo
comes back.
