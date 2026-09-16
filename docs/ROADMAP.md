# Roadmap — PlayTorrioMov

**What is left to do.** Shipped work is in [CHANGELOG.md](../CHANGELOG.md)
(1.8.1+34 covers #67's device confirmation and the partial progress on #68
and #69 below), the release process is in [RELEASES.md](RELEASES.md), and
item numbers (`#15`–`#71`) are indexed at the end of the changelog.

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-16**, on `v1.8.1+34`.

---

## Pending

#68 and #69 are started and shipped in part (see CHANGELOG 1.8.1+34 for
what) but far from finished; what's left of each is below. The rest need a
person with hardware.

### Translation (#68)

**~470-770 of an estimated 500-800 user-facing strings are still
hardcoded English.** Infrastructure and three languages (Spanish, Arabic,
Portuguese-BR) shipped in 1.8.1 — see the changelog for what that covers.
To continue: add a key to `lib/l10n/app_en.arb` (+ the three translated
ARB files), run `flutter gen-l10n`, replace the literal with
`AppLocalizations.of(context).yourKey`. `HubSection.localizedLabel` (in
`lib/utils/hub_controller.dart`) shows the pattern for a widget reached by
tests that don't wire localization delegates: use
`Localizations.of<AppLocalizations>(context, AppLocalizations)` directly
and fall back to English, since the generated `.of()` throws (not returns
null) when no delegate is found, given `nullable-getter: false` in
`l10n.yaml`.

**No RTL layout audit has been done for Arabic.** Flutter's
`Directionality` follows the locale automatically for standard Material
widgets, but no custom `Row`/icon-direction assumptions elsewhere in the
app have been checked against it.

**Catalog descriptions are not a TMDB free win, if anyone reaches for
that next.** Synopsis and genre text comes from the Stremio addon
(Cinemeta by default), read generically as `json['overview'] ??
json['description']` in `models/movie/video.dart` — not from TMDB, which
this codebase only uses for cast/crew and scrapers' own IMDb→TMDB id
matching. Translating catalog descriptions would mean checking whether
Cinemeta's own API takes a locale, a separate and unstarted question.

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

**~64 of the ~68 files in `lib/` with a fixed `height:` are still
unaudited.** Four high-traffic ones shipped fixed in 1.8.1 (see changelog),
each a clamp rather than a layout rewrite — the element still grows with
text scale, just capped short of overflowing the fixed box it sits in.
System-level accessibility text scale (true regardless of the new in-app
zoom setting) can still overflow any of the remaining ~64. To continue:
grep for `height:\s*[0-9]` the way `mobile_first_test` greps for
`SizedBox(width: ...)`, then check whether each hit wraps scalable text.

Semantics labels on icon-only controls, mentioned here previously, is
still untouched — `Tooltip` supplies one for free, which the library
action row already gets, but nothing has checked the rest.

### Audio silent under Flatpak, needs a device to confirm (#70)

`--socket=pulseaudio` was added to `finish-args` in 1.8.1 (see changelog
for the reasoning) — a Flatpak build with the fixed manifest has not yet
been run against real speakers.

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
