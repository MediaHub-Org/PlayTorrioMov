# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-29**, on `v1.9.0+47` plus the unreleased work in
CHANGELOG.

---

## Pending

Nothing below can be closed by reading code: each is waiting on a device, or
on a decision that only a device can inform. They are kept here, and not as doc
comments, because each one blocks or shapes real work.

### Top-bar reachability from content on a TV (#80)

Whether a D-pad can reach the top bar's section chips *from inside the content
area*. The chips answer OK correctly once focused; getting there is unproven.
The content renders inside `NestedNavigator`'s own `Navigator`, and every route
gets its own `FocusScopeNode`, which may bound directional traversal so the
persistent chrome outside it is never a candidate. Two fixes are possible — an
escape hatch that moves focus into the chip row when an arrow key goes
unhandled, or a `FocusTraversalPolicy` spanning both — and a wrong one breaks
the in-content navigation that just started working. Needs a device to isolate
which it is before either is attempted.

### Casting a scraper source gets stuck loading (#79)

Confirmed on a device 2026-09-28: the receiver connects, shows its splash, and
the media never starts. The likely cause is the Cast SDK's lack of any
sender-side way to attach a Referer/User-Agent, which most scraper sources
require (`CastService.loadMedia` says so). Not yet isolated: cast a direct/CDN
source with no header requirement and see whether *that* plays. If the header
is the cause, the only path is a local relay on the phone that re-serves the
stream with the headers added — the same shape of question as the torrent one
below.

### Whether a phone can cast a torrent

A torrent plays from TorrServer on the phone at `127.0.0.1`, and a receiver
asked to fetch that address asks *itself*, so the server would need to be
bound to the LAN and handed the device's LAN address. On Android the plugin
exposes `port`, so the LAN URL would be built from `NetworkInterface.list()`.
(iOS is out regardless — see `CastService.canCastUrl`.) What the shipped
`libtorrserver.so` binds is unproven. One command decides it, with a torrent
playing, from a laptop on the same Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.

### Unconfirmed on a device

Shipped, reasoned from code, not yet seen working on a TV:

- The Android TV banner (`res/mipmap-*/banner.png`): does the leanback launcher
  render it as intended.
- Poster card sizing (`AppSpacing.cardWidthForScreenWidth`, 108–168px): the
  numbers are a guess sized to be smaller than the old tables everywhere, not a
  measured target. `ContinueWatchingSlider` and the episode thumbnails were left
  on their own sizes on purpose (a different, landscape shape).
- Watch Sources on TV (icons hidden, 50/50 split) and the focus ring on cards.

### Fixed heights around text (#69)

The 3x text-scale probe covers 32 widgets (see below). The remaining tail was
re-scanned 2026-09-29 and is much smaller than the old "~42 files" estimate:
most fixed `height:` values wrap an icon, an image or a spinner, not text. The
six that did wrap text (the watch-screen filter pill, the cast sheet's device
row, the subtitle-sync buttons, the episodes panel's sources button, the
sources-and-filters rank badge and the search type-chip rail) now grow with the
text scale — as a `minHeight` floor where the parent allows it, and as a
text-scaled height for the search rail, whose horizontal `ListView` needs a
bounded one. What is left is the part a test cannot hold: pages that fetch on
init (Details, Discover, the Watch cards), whose skeletons need the network.
Lift the text-sizing piece into `widgets/` when you next touch such a page, give
it a named `static` height, and add a case to `text_scale_overflow_test.dart`.
The scan is a heuristic (it pairs a fixed height with `Text(` nearby); do not
rank work by grepping `height:`.

### What holds without anyone re-auditing it

Six invariants are held by tests, not by passes over `lib/`:

| Test | Invariant |
|:--|:--|
| `no_hardcoded_text_test` | No `Text()` holds an English sentence |
| `icon_button_tooltip_test` | Every icon-only control carries a label, button or not |
| `rtl_directional_padding_test` | No padding, and no content alignment, names a physical edge |
| `american_spelling_test` | One spelling of every word, `.arb` files included |
| `text_scale_overflow_test` | 32 widgets survive 3x text scale on a 360px view |
| `arrow_affordance_test` | Every rail arrow turns around for Arabic, and the player transport does not |

Data strings stay English on purpose.

---

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

PlayTorrioMov began as a fork of `MediaHub-Org/PlayTorrioMod`; that repo is
**archived**, so Mov is the only active app in the family and the direct
downstream of `ayman708-UX/PlayTorrioV3`.

**Reviewed through `39b736f`. Nothing outstanding.** Re-fetched 2026-09-20:
`v3/main` has not moved and the archived Mod's last commit is still
2026-09-05.

Taken: `db2a4b9` and `0343720`, both hardening the Linux CI job against a
`dl.google.com` apt source the runner image ships that periodically breaks
`apt-get update` — ported to **both** `build.yml` and `pr-checks.yml`. Plus
one real bug: upstream's "watch screen properly cancels all scrapers on
dispose" was true of `ScraperManager.scrapeAll` here but not of
`StreamService.fetchStreams`, which wrapped that stream in a second controller
with no `onCancel` of its own — so leaving a watch screen mid-search left all
forty-odd scrapers issuing requests into a controller nobody read. Fixed, with
a test that fails without it.

**Not taken, so they are not re-reviewed.** `39b736f`'s headline feature is a
CloudStream extension system with a native Android bridge — a plugin
ecosystem, and a feature rather than a fix; its player coroutine collision is
Kotlin-side and this fork's player is Dart-side. `9616808` (blurred hero
backdrop) fixes a problem we do not have. `29a4127`, `1da1940` and `d2f8074`
are in the area this fork has diverged furthest in — #45, #46 and the portal
browser are ours — so they were read as ideas, not ported; the overflows
`d2f8074` reported were hand-fixed in #40 instead, all four rather than the
two reported.
