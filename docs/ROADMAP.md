# Roadmap — PlayTorrioMov

**What is left to do.** Shipped work is in [CHANGELOG.md](../CHANGELOG.md),
the release process is in [RELEASES.md](RELEASES.md), and item numbers
(`#15`–`#71`) are indexed at the end of the changelog.

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-16**, on `v1.8.2+35`.

---

## Pending

Two kinds of work are left, and they need different things from you.

**Actionable now, no hardware** — #68 and #69, both started and shipped in
part. Each has a method below that has already been used successfully, so
neither is a research problem; they are a long tail of small, verifiable
pieces.

**Needs a device** — #28 and the torrent-cast question. Nothing here can be
advanced by reading or writing code; each is one test away from an answer.

### Translation (#68)

**~410-710 of an estimated 500-800 user-facing strings are still hardcoded
English.** Infrastructure and three languages (Spanish, Arabic, Portuguese-BR)
shipped in 1.8.1, covering the hub navigation, the Settings hub page and the
Appearance page — 46 keys. The Library followed in 1.8.2 (34 more), then the
details pages and the player's gear menu (26 more). 120 keys in all.

The method, per string:

1. Add a key to `lib/l10n/app_en.arb`, plus the three translated ARB files.
2. Run `flutter gen-l10n`.
3. Replace the literal with `context.l10n.yourKey`.

A key that needs a value inside the sentence uses a placeholder —
`detailsPlayEp` is `"Play Ep {number}"`, because word order differs in the
other three languages and the number cannot be concatenated outside the
translation.

**A test compares every ARB file to English in both directions.** A missing
key does not crash: `gen-l10n` silently emits the English string, so the
app looks fine and one screen is quietly untranslated. Add the key to all
four files or the test fails.

**Use `context.l10n`, not `AppLocalizations.of(context)`.** The generated
getter is `nullable-getter: false`, so it force-unwraps and *throws* when no
delegate is registered — which is most existing widget tests, since they pump
a bare `MaterialApp`. `lib/l10n/l10n.dart` wraps it with an English fallback,
so a bare-pumped test sees exactly the string it saw before the widget was
translated. Translating a widget without this breaks every test that renders
it, and the failure looks like a null-check crash rather than a missing
delegate.

`HubSection.localizedLabel` (in `lib/utils/hub_controller.dart`) is the
earlier, hand-rolled version of the same idea, for a `const` enum that cannot
hold a context-dependent string. `LibrarySection.localizedLabel` and
`LibraryShelf.localizedLabel` follow it.

**The next slice is the settings pages.** They are long, text-heavy, and the
place a user who needs large text is most likely to be — which makes them
both the biggest remaining translation target and the one that most rewards
doing.

**No RTL layout audit has been done for Arabic.** Flutter's `Directionality`
follows the locale automatically for standard Material widgets, but no custom
`Row`/icon-direction assumptions elsewhere in the app have been checked
against it.

**Catalog descriptions are not a TMDB free win, if anyone reaches for that
next.** Synopsis and genre text comes from the Stremio addon (Cinemeta by
default), read generically as `json['overview'] ?? json['description']` in
`models/movie/video.dart` — not from TMDB, which this codebase only uses for
cast/crew and scrapers' own IMDb→TMDB id matching. Translating catalog
descriptions would mean checking whether Cinemeta's own API takes a locale, a
separate and unstarted question.

**The risk is not the UI. It is the titles**, and the rule below is settled
before anyone starts, because getting it wrong breaks things that look
unrelated.

> **A title is two fields, and they must never merge.**
>
> |                  | Used for                                                             | Localizable |
> |:-----------------|:---------------------------------------------------------------------|:------------|
> | `displayTitle`   | What the user reads                                                  | Yes         |
> | `canonicalTitle` | Scraper queries, `uniqueKey`, Trakt/Simkl matching, filename parsing | **Never**   |

Three things in this codebase depend on a stable title, and each breaks
differently:

1. **Identity falls back to the title.** `MyListItem.uniqueKey` returns
   `title:$type:$clean:$year` when there is no IMDb, TMDB, Trakt or Simkl id
   — and anime saved from AniList hits that branch *by design*, because
   AniList ids are their own namespace. Localize `title` and the same show
   saved under a Spanish UI is a different object from the one saved under
   English. That takes collections membership, Continue Watching dedupe and
   Trakt/Simkl matching with it.
2. **All 48 scrapers search by title string** (`scrape({required String
   title, ...})`). They index release names, which are English or original
   language. "El Caballero Oscuro" returns nothing, and it fails silently —
   the user sees no sources, not an error.
3. **AniList already returns four titles** — `titleUserPreferred`,
   `titleRomaji`, `titleEnglish`, `titleNative`. The app picks the first and
   discards the rest. The "which title do we show" decision already exists
   here; it is simply not a setting yet.

**Default: show original/English titles even when the UI is translated**,
with an opt-in toggle that affects display only. A translated title is not a
stable identifier — Spain and Latin America give the same film different
Spanish titles — while the original is the one string every provider agrees
on. It is also what Stremio, Plex and Jellyfin default to, and titles are how
people search and recognise things.

### Text scale and accessibility (#69)

**~56 of the ~68 files in `lib/` with a fixed `height:` are still unaudited.**
Twelve high-traffic boxes are fixed so far — four in 1.8.1, then the Continue
Watching card and its section header, then the three catalogue cards and the
details page action rows, then the player's two menus, the browse row header
and the settings hub. What is left is the long tail, in rough order of how
many people meet it:

1. **The transport bar and source sheet** — the player chrome the two menus
   above do not cover.
2. **The remaining settings pages** — the hub is done; the ten pages behind
   it are not, and they are the most text-heavy screens in the app.
3. **The remaining details-page rails** — cast, related, similar.
4. **Live TV's portal browser** — a modal with its own toolbars.

The method is settled and does not need rediscovering:

- **Probe, don't grep.** `test/text_scale_overflow_test.dart` renders at 3.0
  scale on a 360px-wide view and asserts nothing reached the binding. Flutter
  reports an overflow as an exception with an exact pixel count, so a failure
  names the widget and the amount. Add a case per widget.
- **Do not audit by grepping `height:`.** It was tried and it does not
  survive contact: a span-based scan pairing each fixed height with the
  largest `fontSize` inside it returns 165 hits, and the loudest are
  `height: 4` spacers that merely sit in the same widget subtree as a
  `fontSize: 22` title. A static scan cannot tell "box that wraps this text"
  from "box that happens to be near it", so the ranking is noise.
- **A clamp is not always enough.** The Episodes control strip still wanted
  179px at 1.3, because the jump input and the batch dropdown are
  fixed-width boxes with text inside them. It sits in a `Wrap`, so the box
  could genuinely grow — and wrapping is the better answer where it can.
  Clamp only what has nowhere to go. 1.3 is the established ceiling.
- **A page with a looping animation never settles.** `pumpAndSettle` times
  out on the details pages' ambient background rather than reporting anything
  about layout. Overflow is raised during layout on the first frame, so
  `pumpAtScale(settle: false)` is what those cases need.
- **Pump it where it actually lives.** A bare pump of the player menu reported
  a 1891px vertical overflow, and of `SectionHeader` a 790px one. Neither can
  happen in production: `PlayerMenuAnchor` bounds and scrolls the card, and a
  browse page is a scrollable. Both probes now wrap the widget in the
  arrangement it really sits in. A probe that reports an overflow production
  cannot have is not finding a bug — it is finding the test's own scaffolding,
  and it wastes exactly the time it takes to work that out.

Semantics labels on icon-only controls, mentioned here previously, is still
untouched — `Tooltip` supplies one for free, which the library action row
already gets, but nothing has checked the rest.

### Cast, against a real receiver (#28)

A bug was found and fixed by reading the plugin's source on 2026-09-15 — the
picker subscribed to a device stream that nothing ever started producing, so
it searched forever. **That fix has not been confirmed against a receiver.**
It explains the reported symptom exactly, but whether it was the only cause is
what the next device test decides.

Still unverified, and each needing a receiver:

1. Does the Cast sheet **list a device** within a few seconds of opening?
2. Does a **movie** from a direct/CDN source reach the TV and play? (Known
   limit: the Cast SDK has no sender-side way to attach Referer/User-Agent, so
   scraper sources needing them fail on the TV while playing fine locally.)
3. Does a **Live TV channel** show as live on the receiver — no seek bar, no
   phantom duration?
4. Does **disconnect** return playback cleanly?

### Whether a phone can cast a torrent

The one open feature question. A torrent plays from TorrServer on the phone at
`127.0.0.1`, and a receiver asked to fetch that address asks *itself* — so it
would need the server bound to the LAN and handed the device's LAN address.

Reading the code settled half of it: **iOS is dead** (the plugin's Go shim
hardcodes `net.Listen("tcp", "127.0.0.1:"+portStr)`), and **on Android the
plugin is not the obstacle** — it exposes `port`, so the LAN URL would be built
here from `NetworkInterface.list()`.

What the shipped `libtorrserver.so` actually binds is unproven. One command
decides it, with a torrent playing on the phone, from a laptop on the same
Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means the feature is possible. A refusal closes it for good.

### Not doing, so it stays decided

| What                                                                 | Why not                                                                                                                                                                                                                                                     |
|:---------------------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Merge `megasource` / `nova` (50 shared windows)                      | They share an HTTP-and-parse skeleton, but Nova munges stream titles in a way MegaSource does not. Unifying them means a formatting hook whose two implementations have nothing in common — an abstraction serving a duplication count rather than the code |
| Offline tests for the page **scraping** (script tags, slug matching) | Its input is one host's markup on one day, so a fixture pins that day rather than a contract. The payload ciphers and response *formats* are covered; this is a smaller claim and not a reason to hold a release                                            |
| Cast from Windows                                                    | `flutter_chrome_cast` is Android/iOS only, because Google ships no Cast *sender* SDK for Windows. Would mean a different protocol (DLNA/UPnP) — a feature, not a fix                                                                                        |
| Sponsor/monetization, keyboard aspect-cycle HUD (upstream)           | Out of scope; and Mov already has an aspect control in the player settings                                                                                                                                                                                  |

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

**Reviewed through `f69617b` (2026-09-13). Nothing outstanding.**

Taken: `db2a4b9` and `0343720`, both hardening the Linux CI job against a
`dl.google.com` apt source the runner image ships that periodically breaks
`apt-get update` — ported to **both** `build.yml` and `pr-checks.yml`.

Not taken, so they are not re-reviewed:

| Commit               | Why not                                                                                                                                                                                                                                                                               |
|:---------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `9616808`            | Blurred dual-layer hero backdrop to kill black bars. Every hero in this fork already uses `BoxFit.cover`, which fills and crops. It fixes a problem we do not have                                                                                                                    |
| `29a4127`, `1da1940` | IPTV channels, search and storage — the area this fork has diverged furthest in (#45, #46 and the portal browser are ours). Read as ideas, not ported as patches                                                                                                                      |
| `d2f8074`            | IPTV portal manager responsiveness. A near-total rewrite of `iptv_portals_modal.dart`; our copy carries Cloud Vault, the modal customizer and the M3U tab, so a straight port would drop them. The reported overflows were hand-fixed in #40 instead — all four, not the two reported |
