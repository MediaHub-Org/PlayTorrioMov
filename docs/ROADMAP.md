# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#76`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-28**, on `v1.8.13+46`.

---

## Pending

**Nothing here needs a device.** Hardware checks are not tracked in this file
any more: #28's Cast path, the phone-casts-a-torrent question, forced-subtitle
rendering and #74's pill rail were all "seen listed, not seen working", and a
list of things only one person can look at is not a roadmap. Each is now a doc
comment on the thing it is uncertain about, where whoever next opens that file
will meet it: `PlayerCastSheet` (#28), `CastService.canCastUrl` (the torrent
question, with the one `curl` that answers it), `FilterPillRail` (#74), and
`_buildSourceTabs` in the subtitle menu (forced tracks). Cast issues go the
same way: use it, and report what breaks. The ORIGINAL audio badge (once
#76) was dropped outright rather than left pending -- it marked the track a
file opened with, not the track it was made in, so it was wrong more often
than it was right.

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

What is left is the part a test cannot hold:

- Data strings stay English on purpose.
- Unprobed fixed heights: lift on touch, probe, repeat. Pages that fetch
  on init (Details, Discover, the Watch cards) are out of scope -- their
  skeletons need the network, and this is about fixed heights around real
  text.

### The long tail of fixed heights (#69)

The one thing genuinely left, and it is a shape rather than a list: **~42 files
in `lib/` set a fixed `height:` around text that nothing probes.** Four more
came off it with the cards and the four widgets above; what remains is mostly
*pages*, and that is the obstacle rather than the volume. A page fetches over
the network, so a test cannot construct one, and every probe so far has needed
the widget pulled out first -- which is what `CreditCard`, `SimilarCard`,
`UpcomingCalendarRow` and `FilterPillRail` have in common.

So the work is not "audit 42 files". It is: when you next touch a page that
sizes text with a constant, lift that piece into `widgets/` with the constant
as a named `static` on it, and add a case to `text_scale_overflow_test.dart`.
The two cards are the worked example.

Do not rank the remainder by grepping `height:`. It was tried: a span-based
scan pairing each fixed height with the largest `fontSize` inside it returns
165 hits whose loudest are `height: 4` spacers sitting in the same subtree as a
`fontSize: 22` title. A static scan cannot tell "box that wraps this text" from
"box that happens to be near it".

### Xtream catalogs as parent sources (#77)

A portal's movies and series stay out of Films, Series and Anime today:
the portal browser is live-only on purpose, because folding VOD in means
more than listing it. Doing it properly needs a pipeline, not a tab:

- Match each entry to a catalog title (IMDb/TMDB id where the feed
  carries one, guarded title-plus-year matching where it does not, and a
  rule for what happens to the entries that match nothing).
- Play through the existing details and player pages, so watch history,
  Continue Watching and the library buttons treat portal and catalog
  titles as the same thing rather than two copies.
- Decide where unmatchable entries live: a portal shelf of their own, or
  nowhere at all. A wrong match pushed into Films is worse than an
  honest gap.

Until that exists, portals provide Live TV only, and that boundary is
load-bearing rather than temporary-looking.

### Translation (#68)

**What is left outside `Text(` is hardcoded Arabic.** The English sites are
keyed now -- Continue Watching badges, season-collection parts, the Arabic
sheet's status lines -- and `S01E01` shapes stay codes, as universal as episode
numbers. What remains is hardcoded Arabic across the Arabic anime pages:
correct for their audience today, and needing a native review before gaining
es/pt/en translations.

### Android TV and remote navigation (#78)

Reported live: on an Android TV, the D-pad reaches almost nothing, and
nothing shows a focus highlight when it does. Two separate causes, both
confirmed by reading the code rather than guessed:

- **The app declares no TV support.** `android/app/src/main/AndroidManifest.xml`
  has no `android.software.leanback` `<uses-feature>` and no
  `LEANBACK_LAUNCHER` intent category, so a TV treats a sideloaded build as
  an unlisted phone app rather than something built for it.
- **Most interactive widgets cannot take focus.** Flutter only routes D-pad
  and keyboard directional traversal to a widget holding a `Focus` node --
  Material's own buttons, chips and `InkWell` get one for free. A
  `GestureDetector` does not, and that pattern repeated across `lib/widgets`
  and `lib/pages`: 74 bare `GestureDetector` calls in 38 files when this was
  counted. A `Scrollable` (the pill rail, for one) takes arrow-key scrolling
  for free too -- which is likely what "the pills respond" was actually
  seeing: the row scrolling, not a pill taking focus and showing it.
  **Not a from-scratch problem, though: `player_glass.dart` already had a
  deliberate answer.** `PlayerToggleChip` and `PlayerStepSlider` both wrap in
  `Focus` with an `onKeyEvent` handler and paint `FocusRing` on focus --
  `PlayerStepSlider`'s own comment says it takes `autofocus` so a menu's
  primary control works immediately. That pattern was never carried to
  `PlayerIconButton`, the transport's actual buttons (play/pause, seek,
  volume), or to anything outside the player's menus.

**Underway, not finished.** The manifest now declares both features
required=false (`android.hardware.touchscreen` has to be there too, or
Android TV's own install filter excludes the app before leanback ever
matters) and the launch activity carries `LEANBACK_LAUNCHER`, so the app
should at least appear in a TV launcher now -- unconfirmed on a device, and
there is no banner image yet, so it falls back to the launcher icon.

Two primitives carry the fix, matching what each already looked like:

- **`PlayerIconButton`** (`lib/widgets/player/player_glass.dart`) now uses the
  same `Focus`/`onKeyEvent`/`FocusRing` shape as its neighbours in that file,
  activating on Select or Enter. This is the highest-leverage single change
  here: every play/pause, seek and volume control in the transport goes
  through this one class.
- **`HoverButton`** (`lib/widgets/common/hover_button.dart`) is the shared
  wrapper the details rails and cards already used, so it became the
  primitive for everything built from a bare `GestureDetector` instead: it
  now holds a `Focus` node, activates on Enter/NumpadEnter/Select/
  gameButtonA/Space, and reuses its existing hover lean as the focus visual
  rather than guessing at a ring for a `child` whose shape it does not know.
  `watch_screen.dart` -- the file actually tested -- is fully converted:
  every bare `GestureDetector` in it now either wraps in `HoverButton` or,
  where it shared hand-rolled hover state that did not fit that primitive,
  gained its own `Focus` and key handling directly, the same shape
  `player_glass.dart` already used.

That is the worked example, not the finished sweep: the other 37 files
counted above are not touched, and there is no guard test enforcing this
going forward -- adding one now would turn all of them red. Untested against
a real remote: the key set (`select`, `enter`, `gameButtonA` for `HoverButton`)
is a reasonable guess at what different remotes and controllers send, matched
to what `PlayerToggleChip` already assumed, not a confirmed one. No focus
order has been set anywhere either -- Flutter's default reading-order
traversal is what a remote will get until someone checks whether that is
the order a viewer actually wants.

**One thing removed rather than converted.** `CustomScrollTrack` -- the
floating draggable scrollbar with hover-only up/down arrows on Films,
Series, Anime and Live TV -- was gated to `ScreenTier.desktop`, and that
tier is picked by width alone, so a TV counts as desktop too. Its arrows
and thumb-drag both need a pointer a D-pad cannot produce, so it was dead
chrome there rather than something worth making focusable: a mouse wheel
or a trackpad already scrolls the same page without it. Deleted outright,
not gated behind a platform check.

### Casting a scraper source gets stuck loading (#79)

**Confirmed on a device 2026-09-28.** Casting a movie/series/anime source to
a TV: the receiver connects, shows its loading splash, and the media never
starts -- no error, just stuck. `CastService.loadMedia`'s own doc comment
already named the likely cause before this test: the Cast SDK has no
sender-side way to attach a Referer/User-Agent header to the receiver's
request, and most scraper sources require one, unlike this app's own player
which sends it directly. The symptom matches exactly, but it is not yet
isolated from some other cast-only failure -- that needs a direct/CDN source
(one with no header requirement) cast the same way, to see whether *that*
one plays.

If the header gap is confirmed, there is no sender-side fix: the Cast SDK
gives no hook for it. The only path is a local relay -- something on the
phone re-serves the stream with the right headers added, and the receiver is
pointed at that instead of the origin URL. That is the same shape of problem
as the torrent-cast question below (can a receiver reach a server running on
this phone), so an answer to one is evidence for the other.

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

### Whether a phone can cast a torrent

The one open feature question. A torrent plays from TorrServer on the phone at
`127.0.0.1`, and a receiver asked to fetch that address asks *itself* — so it
would need the server bound to the LAN and handed the device's LAN address.
On Android the plugin is not the obstacle — it exposes `port`, so the LAN URL
would be built here from `NetworkInterface.list()`. (iOS is out of the
question regardless -- see `CastService.canCastUrl`.)

What the shipped `libtorrserver.so` actually binds is unproven. One command
decides it, with a torrent playing on the phone, from a laptop on the same
Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.

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
