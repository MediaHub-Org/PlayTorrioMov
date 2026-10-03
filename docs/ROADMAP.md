# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-10-03**, on `v1.9.2+49`.

---

## Pending

The first item is code work, in batches; the rest need a device.

- **Sizes in rem: check it on a device.** The migration is done in code:
  `units_no_raw_pixels_test` scans all of `lib/pages` and `lib/widgets`, and
  the convention is in CONVENTIONS ("Sizes") and `lib/services/app_units.dart`.
  It was made without a device, so a visual drift is the risk: look at the
  default text size (should be unchanged) and at 130% (should grow, not clip).
  The fixed-height budgets (`CreditCard`, `SimilarCard`,
  `ContinueWatchingSlider`) are rem too, each taking the text-size factor so
  `BrowseScaffold` can still derive the band without building it.

- **D-pad on a TV (#80).** Confirmed on a TV: rows, the side menu and reaching
  every element. Not yet: the menu's new icon-rail form (opens on focus), the
  player's controls coming back on an arrow/OK (and Left/Right seeking with
  them hidden), the trimmed Watch Sources rows, and cards without a ring.
  Report what the remote does. Also unconfirmed: the second focus pass (soft
  wash on the filter pills, the side menu's cue across icon and name, the
  play button's lit state, the seek bar's stronger violet, and the volume as
  one stop with Left/Right and OK), and the player's Back ladder (panel, then bars, then a second press to leave). From v1.9.1 on a TV it was reported that the player's menus (audio, speed, sleep timer, aspect), the volume and the seek bar's arrows did not work; these are reworked in v1.9.2 and not yet confirmed on a TV. The in-player sources panel and the anime
  episode sheet now carry the lean tag set too.
- **Player menus as sheets: check the shapes on devices.** The menus are a
  bottom sheet on a phone upright, a side sheet on a phone on its side, a
  tablet and a TV, the popover on a desktop (`playerPanelStyleFor`), with a
  close button, swipe and scrim chosen per shape (CHANGELOG, v1.9.2). It is
  tested in widget tests only. Look at: the breakpoints (a tablet upright, a
  large phone on its side), the swipe against a slider inside a menu, and
  whether the subtitle list now has the room it lacked.
- **Check on a device: loading logo, notification, Similar Content and Cast.**
  The progressive loading logo is now shared by VOD and Live TV: verify real
  buffering on a torrent, a debrid link and a plain URL, and that it clears on
  the first frame. Also check the Android notification's Play/Pause (and
  whether Android 13+ asks for notifications), and "Similar Content" on a
  movie and a series (TMDB first, BestSimilar as the fallback; the sandbox
  cannot reach the site). Cast now waits for the connected session before
  sending media: verify discovery, a direct/CDN stream, a Live TV channel and
  disconnect. Sources requiring Referer/User-Agent headers remain unsupported
  by the Cast SDK path.
- **Whether a phone can cast a torrent.** TorrServer binds `127.0.0.1` for
  the phone; a receiver needs the LAN. With a torrent playing, from a laptop
  on the same Wi-Fi: `curl http://<phone-LAN-IP>:<port>/echo`. An answer means
  it is possible; a refusal closes it for good.
- **Unconfirmed on a TV:** the Android TV banner, the poster card sizes
  (`AppSpacing.cardWidthForScreenWidth`, 108-168px, a guess), Watch Sources on
  TV, and the card focus ring.

## Not doing, so it stays decided

| What | Why not |
|:--|:--|
| Xtream/portal movies and series as parent sources (#77) | **Not viable right now.** Needs a pipeline, not a tab: match entries to catalog titles (ids where the feed has them, guarded title-plus-year where not), play through the existing details/player so history sees one title, and decide where unmatchable entries live. A wrong match in Films is worse than an honest gap. Portals stay Live TV only |
| Size/sort filter under Sources & Filters | Browsing choices for *this* title, not a standing preference; they stay on the sources screen |
| Keyboard shortcut for the subtitle panel | `A`, `S`, `R`, `C` are taken. Revisit if a key frees up |
| Merge `megasource` / `nova` | Shared skeleton, but Nova munges titles MegaSource does not; unifying them needs a hook with nothing in common between its two sides |
| Offline tests for page scraping | Input is one host's markup on one day, so a fixture pins that day. Ciphers and response formats are covered |
| Cast from Windows | Google ships no Cast sender SDK for Windows; it would be DLNA/UPnP, a feature not a fix |
| Sponsor/monetization, aspect-cycle HUD (upstream) | Out of scope; the player settings already have an aspect control |
| Single-select audio filter | "English or Spanish" needs multi-select; the checkmark delay was a stale-rows bug, since fixed |
| Alphabetical online subtitle order | The list leads with the language being heard on purpose |
| Translating catalog descriptions, AniList genres/formats | Addon and AniList data, sent back to their APIs to filter; would need a display-name map per language. See CONVENTIONS |

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
