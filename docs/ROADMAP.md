# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-29**, on `v1.9.0+47` plus the unreleased work in CHANGELOG.

---

## Pending

Every item here needs a device; none can be closed by reading code.

- **Top bar from content on a TV (#80).** Can the D-pad reach the section
  chips from inside the content area? The content sits in `NestedNavigator`'s
  own `Navigator`, and each route has its own `FocusScopeNode`, which may stop
  directional traversal at the scope edge. Candidate fixes: move focus into
  the chip row when an arrow key goes unhandled, or a `FocusTraversalPolicy`
  spanning both. A wrong one breaks in-content navigation, so isolate the
  cause on a device first.
- **Casting a scraper source hangs on the loading splash (#79).** Likely the
  Cast SDK's lack of a sender-side Referer/User-Agent (`CastService.loadMedia`
  says so). Cast a direct/CDN source with no header requirement: if it plays,
  the header is the cause and the only path is a local relay on the phone.
- **Whether a phone can cast a torrent.** TorrServer binds `127.0.0.1` for
  the phone; a receiver needs the LAN. With a torrent playing, from a laptop
  on the same Wi-Fi: `curl http://<phone-LAN-IP>:<port>/echo`. An answer means
  it is possible; a refusal closes it for good.
- **Unconfirmed on a TV:** the Android TV banner, the poster card sizes
  (`AppSpacing.cardWidthForScreenWidth`, 108-168px, a guess), Watch Sources on
  TV, and the card focus ring.

## What tests hold

Six invariants are held by tests, not by passes over `lib/`: no `Text()` holds
an English sentence (`no_hardcoded_text_test`); every icon-only control has a
label (`icon_button_tooltip_test`); no padding or alignment names a physical
edge (`rtl_directional_padding_test`); one spelling of every word
(`american_spelling_test`); 32 widgets survive 3x text scale on a 360px view
(`text_scale_overflow_test`); rail arrows turn around for Arabic
(`arrow_affordance_test`). Data strings stay English on purpose.

## Not doing, so it stays decided

| What | Why not |
|:--|:--|
| A size/sort filter under Sources & Filters (#72's open question) | A size range and "largest first" are browsing choices for *this* title, not a standing preference, so they stay on the sources screen. #75 settled the settings page's shape: two multi-select blocks, one per media kind |
| A keyboard shortcut for the subtitle panel | `A`, `S` and `R` are the audio, speed and aspect menus, and `C` became the on/off toggle, so no key is free. Keyboard-only users reach the panel through the transport bar, which needs a pointer. Revisit if a key frees up |
| Merge `megasource` / `nova` (50 shared windows) | They share an HTTP-and-parse skeleton, but Nova munges stream titles in a way MegaSource does not. Unifying them means a formatting hook whose two implementations have nothing in common — an abstraction serving a duplication count rather than the code |
| Offline tests for the page **scraping** (script tags, slug matching) | Its input is one host's markup on one day, so a fixture pins that day rather than a contract. The payload ciphers and response *formats* are covered |
| Cast from Windows | `flutter_chrome_cast` is Android/iOS only, because Google ships no Cast *sender* SDK for Windows. It would mean a different protocol (DLNA/UPnP) — a feature, not a fix |
| Sponsor/monetization, keyboard aspect-cycle HUD (upstream) | Out of scope, and Mov already has an aspect control in the player settings |
| Single-select audio-language filter | "English or Spanish" is not expressible with one choice, and the multi-select checkmark delay was a stale-rows bug, now fixed by rebuilding the menu from the setting on every change — the control was never the problem |
| Pure-alphabetical online subtitle order | The list leads with the language being heard because that is the track a viewer most likely wants. Identical counts tie-break alphabetically, covered by a test |
| Translating catalog descriptions | They come from the Stremio addon, not TMDB, and whether Cinemeta's API takes a locale is an unstarted question. See CONVENTIONS |
| Translating AniList's genres and formats | They are AniList's own values, sent back to its API to filter, and would need a display-name map per language on top |
| Xtream/portal movies and series as parent sources (#77) | **Not viable right now.** Folding a portal's VOD into Films, Series and Anime is a pipeline, not a tab: match each entry to a catalog title (IMDb/TMDB id where the feed carries one, guarded title-plus-year where it does not), play through the existing details and player so history and Continue Watching see one title rather than two copies, and decide where unmatchable entries live. A wrong match pushed into Films is worse than an honest gap, and none of that is small. Until it is revisited, portals provide Live TV only, and that boundary is load-bearing rather than temporary-looking |

---

## Reference

### Upstream sync

PlayTorrioMov began as a fork of `MediaHub-Org/PlayTorrioMod` (archived), the
direct downstream of `ayman708-UX/PlayTorrioV3`. **Reviewed through `39b736f`;
nothing outstanding** (re-fetched 2026-09-20). Not taken, so not re-reviewed:
`39b736f`'s CloudStream extension system (a plugin ecosystem, a feature not a
fix) and its Kotlin-side coroutine fix; `9616808`, a blurred hero backdrop for
a problem we do not have; and `29a4127`, `1da1940`, `d2f8074`, in the area this
fork has diverged furthest (#45, #46, the portal browser), read as ideas and
hand-fixed instead (#40).
