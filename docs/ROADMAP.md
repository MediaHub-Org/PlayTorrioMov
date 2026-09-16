# Roadmap — PlayTorrioMov

**What is left to do.** Nothing else lives here: shipped work is in
[CHANGELOG.md](../CHANGELOG.md), the release process is in
[RELEASES.md](RELEASES.md), and item numbers (`#15`–`#69`) are indexed at the
end of the changelog.

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-15**, on `v1.8.0+33`.

---

## Pending

**#70 and #71 are coded, not verified. #68 and #69 are both scoped and
partly done**: #68 has working infrastructure and three real languages
(Spanish, Arabic, Portuguese-BR) but only ~30 of an estimated 500-800
strings migrated; #69 has four high-traffic overflow fixes shipped and an
in-app zoom, but ~64 files still unaudited. The rest need a person with
hardware.

### Translation (#68)

**Infrastructure shipped 2026-09-16, most strings not yet migrated.**
`flutter_localizations` + `intl` + `l10n.yaml` (`nullable-getter: false`) +
`lib/l10n/*.arb` generate `AppLocalizations` at build time
(`lib/l10n/app_localizations*.dart` is gitignored, not checked in). Three
languages have real translated content — Spanish, Arabic, Portuguese
(Brazil) — picked in Appearance & Interface → App Language
(`AppThemeService.locale`, persisted, null = follow the device's language
among the supported ones). The in-app text zoom (#69) composes correctly
with this: `main.dart`'s `MediaQuery` builder multiplies both onto the
system's scaler.

Migrated so far — hub navigation (`HubSection.localizedLabel`, used by both
`AdaptiveNavShell`'s bottom tab bar and `SectionTopBar`'s desktop chips),
the Settings hub page, and the Appearance & Interface page itself (~30
keys across `lib/l10n/app_en.arb`). Originally ~500-800 user-facing strings
were estimated across `lib/` (still hardcoded English almost everywhere
else, plus `anime_arabic_details_page.dart`'s seven hardcoded Arabic ones,
unrelated to this new system) — so roughly 470-770 remain. Mechanical,
large, and low-risk per string, the same as before this pass — just not
finished. Whoever continues: add a key to `app_en.arb` (+ the three
translated ones), run `flutter gen-l10n`, replace the literal with
`AppLocalizations.of(context).yourKey`. `HubSection.localizedLabel` shows
the pattern for a widget reached by tests that don't wire localization
delegates: use `Localizations.of<AppLocalizations>(context,
AppLocalizations)` directly and fall back to English, since the generated
`.of()` throws (not returns null) when no delegate is found, given
`nullable-getter: false`.

No RTL layout audit was done for Arabic — Flutter's `Directionality`
follows the locale automatically for standard Material widgets, but no
custom `Row`/icon-direction assumptions elsewhere in the app have been
checked against it.

**Correction to the note below, found while wiring this up:** catalog
synopsis and genre text does not come from TMDB in this codebase — it
comes from the Stremio addon (Cinemeta by default), read generically as
`json['overview'] ?? json['description']` in `models/movie/video.dart`.
`TmdbService`/`tmdb_helper.dart` only fetch cast/crew and resolve IMDb→TMDB
ids for scrapers' own matching — neither touches text a user reads. The
"free win" below assumed a TMDB-sourced catalog and does not apply as
written; translating catalog descriptions would mean checking whether
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

Flutter already applies the system text scale to every `Text`, so the app
scaled before this entry too — and *overflowed*, because its layouts are
fixed-height. Not hypothetical: the collections card shipped in 1.8.0 needed
`MediaQuery.textScalerOf(context).scale(38.0)` to reserve its label space, or
it burst its grid cell.

**Scoped and partly done, 2026-09-16** — 68 files in `lib/` declare a fixed
`height:`, too many to exhaustively audit in one pass, so this was scoped to
the highest-traffic chrome rather than all of them:

- Fixed and regression-tested (`test/text_scale_overflow_test.dart`, which
  pumps at 3x — the top of Android's accessibility slider — and asserts no
  overflow): `AdaptiveNavShell`'s mobile bottom tab bar labels, and
  `PillTabRow` (hosted inside `LibraryTabs`' `AppBar.bottom`, a
  `PreferredSize` fixed at 52).
- Fixed by inspection, not yet covered by an automated test:
  `SidebarLogo`'s wordmark (inside `TopBar`'s fixed `sharedHeight`, 56 —
  the regression test above caught this one by accident, pumping `TopBar`
  while chasing the tab-bar fix, which is exactly the kind of thing a
  grep-based audit misses) and the details page's per-credit role label
  (`SizedBox(height: 12)` in `_buildCreditCard`).
- Each fix is a clamp (`textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: ...)`),
  not a layout rewrite: the element still grows with text scale, just capped
  short of overflowing the fixed box it sits in.
- **The in-app zoom setting is shipped** (Appearance & Interface → App Text
  Size, `AppThemeService.textScale`), deliberately capped at 1.3x
  (`AppThemeService.maxTextScale`) — the same ceiling every fix above was
  clamped to, so the control can never ask them to render past what was
  actually verified. It multiplies on top of the system's own accessibility
  text size rather than replacing it.
- **Not done:** the other ~64 files with a fixed `height:` were not audited.
  System-level accessibility text scale (already true before this entry,
  independent of the new in-app control) can still overflow any of them.
  Whoever continues this: grep for `height:\s*[0-9]` the way
  `mobile_first_test` greps for `SizedBox(width: ...)`, then check whether
  each hit wraps scalable text.
- Semantics labels on icon-only controls, mentioned here previously, is
  still untouched — `Tooltip` supplies one for free, which the library
  action row already gets, but nothing has checked the rest.

### Audio silent under Flatpak (#70)

Reported across multiple devices, not one machine — which points at packaging,
not a driver. `flatpak/io.github.MediaHubOrg.PlayTorrioMov.json`'s
`finish-args` only grants `--socket=wayland`, `--socket=fallback-x11` and
`--device=dri`. There is no `--socket=pulseaudio`, so the sandbox has no path
to the host audio server at all.

Video still plays because it only needs Wayland/X11 and DRI, which are
granted — audio needs the PulseAudio socket, which is not, and every distro's
default audio stack (PipeWire included) speaks that protocol through its
`pulse` compatibility layer. That is consistent with "every device", since a
missing sandbox permission does not vary by hardware.

**Fixed in code:** `--socket=pulseaudio` added to `finish-args`. **Still
needs a device to confirm** — the reasoning explains the symptom, but no
Flatpak build with this manifest has been run against real speakers yet.

### Subtitle appearance settings open as a pop-up (#71)

Was: `video_player_settings_page.dart`'s `_openSubtitleCustomizer()` showed
`PlayerSubStyleModal` via `showDialog(...)` — a modal overlay dropped on top
of the Settings page, rather than the subtitle section on that page expanding
in place.

**Fixed.** `player_sub_style_modal.dart` now splits the controls (preview,
presets, the five tabs) into `SubtitleStyleEditor`, sized by `LayoutBuilder`
so it works both floating and embedded. `PlayerSubStyleModal` is a thin
wrapper that puts it in the floating glass card for the in-player overlay
(`player_screen.dart`, unchanged there); Settings now toggles the same
`SubtitleStyleEditor` open inline via a "Customize"/"Done" button and an
`AnimatedCrossFade`, inside a fixed dark card so it stays readable in light
theme. Verified with `flutter analyze` (clean) and `flutter test` (no new
failures) — not yet checked visually on a running build.

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
