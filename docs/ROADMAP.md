# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#76`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-26**, on `v1.8.11+44`.

---

## Pending

Two kinds of work, and they need different things.

**What a test already holds is not on this list.** Four invariants fail in CI
rather than needing a re-audit: no `Text()` holds an English sentence, every
icon-only button carries a label, no padding names a physical edge, one
spelling of every word. What is below is what no test can decide.

### Code — needs a judgment per site (#68, #69)

None of these is a research problem and none of them is a sweep. Each is a
list of sites that have to be read one at a time, which is exactly why no test
covers them.

| What | Where it is | The judgment |
|:--|:--|:--|
| **~87 `Alignment.centerLeft`-style constants** | across `lib/` | "Leading, or left?" Not all are wrong — a gradient, or a badge pinned to a corner of artwork, is genuinely physical. Converting them wholesale would be a sweep with nothing behind it |
| **Icon direction under RTL** | back chevrons, "next episode" arrows, the source rail's scroll buttons | Flutter does not mirror `Icons.arrow_forward_ios`. Some of these should mirror in Arabic and some should not, and the player's seek controls over a timeline are a design question rather than a bug |
| **~46 of ~68 files with a fixed `height:`** | the long tail; no named target is left | Whether the box wraps its own text or is sized by the layout around it. Deliberately unranked: the one attempt to rank it by grepping `height:` returned 165 hits whose loudest were `height: 4` spacers |
| **~24 icon-only `GestureDetector`s** | 15 files, most in the portal browser and the player overlays | Whether it already has a label. **This count is not reliable** — a `Tooltip` or `Semantics` on an *ancestor* labels the control just as well, and the scan cannot see one; the library action row and the Continue Watching card are both in the list and both already labelled |
| **The details-page rails cannot be probed** | `DetailsPage`'s credit card and similar card are private builders | Their text-scale fixes are reasoned from arithmetic, not measured. `DetailsPage` fetches over the network, so nothing constructs them. Extracting the two cards as public widgets makes them probeable |
| **The "show original titles" toggle** | does not exist yet | The decision is made and written down in CONVENTIONS (`displayTitle` is localizable, `canonicalTitle` never is). The setting itself was never built, so today every title is the original whether or not anyone chose that |

### Needs a device — yours to answer

Nothing here can be advanced by reading or writing code. Each is one session
with real hardware.

**Cast against a receiver (#28).** A bug was found and fixed by reading the
plugin's source on 2026-09-15 — the picker subscribed to a device stream that
nothing ever started producing, so it searched forever. That fix explains the
reported symptom exactly, but it has never been confirmed against a receiver,
and whether it was the only cause is what the next test decides.

1. Does the Cast sheet **list a device** within a few seconds of opening?
2. Does a **movie** from a direct/CDN source reach the TV and play? (Known
   limit: the Cast SDK has no sender-side way to attach Referer/User-Agent, so
   scraper sources needing them fail on the TV while playing fine locally.)
3. Does a **Live TV channel** show as live — no seek bar, no phantom duration?
4. Does **disconnect** return playback cleanly?

**Whether a phone can cast a torrent.** The one open feature question. A
torrent plays from TorrServer on the phone at `127.0.0.1`, and a receiver asked
to fetch that address asks *itself*. Reading the code settled half of it: iOS
is dead, because the plugin's Go shim hardcodes
`net.Listen("tcp", "127.0.0.1:"+portStr)`; on Android the plugin is not the
obstacle, because it exposes `port` and the LAN URL could be built here from
`NetworkInterface.list()`. What the shipped `libtorrserver.so` actually binds
is unproven, and one command decides it — with a torrent playing on the phone,
from a laptop on the same Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.

**Four things that have been seen listed but not seen working.**

- **Forced subtitles.** Embedded selection is resolved — `_selectEmbeddedTrack`
  reads `sid` back and retries once, because the player's property set never
  throws and a rejected id used to fail silently with the menu showing
  selected. ASS renders through libass, other text through the overlay,
  bitmaps through mpv's OSD. Forced tracks appear in the list; whether they
  *render* is unconfirmed. A `[SubDiag]` line dumps the full roster on every
  manual pick, so a mismatch shows itself in one paste.
- **#74's pill rail, on desktop.** The buttons are driven by
  `maxScrollExtent`, so the case worth checking is a row *just* wider than its
  frame: a short list (no buttons), a long one (a button at each end, the
  spent one dimmed), and a scroll to the end (the other one dimmed). The part
  genuinely unverified is the wheel — that a wheel over the rail does not also
  scroll the page behind it, which the pointer signal resolver exists to
  prevent.
- **#74's pill rail, on a phone.** The fade is drawn on every platform and the
  button only on desktop, because a tablet passes any width breakpoint and is
  still a touch device where a button over the first and last pill would
  swallow taps meant for them. What to check: that the fade reads as "more
  this way" without a button, and that the first and last pill stay tappable
  to their edges.
- **The ORIGINAL audio badge, on a file that defaults to a dub.** #76 badges
  the track the file *opens with*, because there is no original-language flag
  to read — the media_kit fork exposes no `isDefault` or `original` marker and
  mpv's track list carries none. What a release ships as its opening track is
  its own statement of which one it is, but a release defaulting to the dub
  would badge the dub. Related: #73 applies the preferred-audio ranking on the
  first non-empty track list only, once, so a file whose tracks arrive in
  stages keeps its own default — deliberate, so a manual switch is never
  undone, but never observed on a device.

### Not doing, so it stays decided

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
