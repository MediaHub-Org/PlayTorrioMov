# Project Roadmap — PlayTorrioMov

**The app is in maintenance mode.** This file tracks three things: what is
**open**, what is **waiting on a device**, and which **decisions are
settled** so they do not get re-argued. Shipped work lives in
[CHANGELOG.md](../CHANGELOG.md) and git history — a roadmap that also
carries a changelog stops being readable as either.

Items are numbered and never renumbered or reused, so `#43` means the same
thing in a commit message, a pull request and this file.

Last reconciled against the tree: **2026-09-14**, after `v1.6.3+31`. Every
count below was measured there.

**Open is empty.** Everything left needs a device — a Cast receiver, a phone
in the hand — not a commit. Where a device question could be narrowed by
reading code instead, it has been: see the TorrServer answer under *Cast*.

---

## Open

**Nothing.** Every item the 2026-09-13 audit left, and every candidate it
named, is done. What remains below needs a device, not a commit.

That is a claim worth being able to check rather than take on trust, so each
one names the guard that keeps it closed:

| What the audit left | How it closed | What stops it coming back |
|:--------------------|:--------------|:--------------------------|
| `iptv_portals_modal` ↔ `live_tv_settings_page`, **45** duplicated 12-line windows | The shared part was a widget, twice: a `ChoiceChip` styled by hand at ten call sites across three files, all ten agreeing on the same six properties, and the *Default Starting Tab* row — one control written out in two places. Now `SettingChoiceChip` and `DefaultPortalTabPicker`. **45 → 0**, and the three pages lose 172 lines | `setting_choice_chip_test` fails on an eleventh hand-styled chip, or on either screen writing the tab setting itself |
| **126 empty `catch` blocks** | Read one at a time. Five were losing something a user would notice and now say so through `debugPrint`; the other 121 carry the reason they swallow | `empty_catch_test` — `catch (_) {}` is still allowed, but not in silence |
| `megasource` / `nova` share **50** windows | **Declined, and still declined.** They share an HTTP-and-parse skeleton, but Nova munges stream titles in a way MegaSource does not. Unifying them means a formatting hook whose two implementations have nothing in common — an abstraction serving a duplication count rather than the code | — |
| The per-site **HTML parsers** | All three named candidates done — see below | `flutter test --exclude-tags network` runs every one of them |

### What the audit got wrong about itself

Two of its own descriptions did not survive contact with the tree, and are
corrected here rather than quietly fixed:

- It said of the empty catches that *"most carry a comment explaining why the
  error is deliberately swallowed."* Thirteen did. The 126 were precisely the
  ones that did not.
- It named *"`iptv_portal_browser_page`'s Xtream/Stalker response shapes"*.
  There is no Stalker support in this codebase — no portal type, no
  handshake, nothing. Only Xtream exists, so only Xtream was tested.

### The scrapers in CI

**14 of 103 test files were `@Tags(['network'])`** and excluded from CI,
covering exactly `lib/services/scraper` and `lib/services/anime`. The fix was
never to un-tag them — they hit live third-party sites — but to split the
pure logic out and test it offline. Six extractions have now done that.

The line that decides whether one is worth doing: is the input a **format** or
a **website**? A format is defined by somebody and honoured by many
implementations, so a fixture pins the contract. A website is one host's
markup on one day, so a fixture pins that day.

| What | Why it was worth it |
|:-----|:--------------------|
| `SubtitlePayload.decode` | Deciding what downloaded bytes *are* — zip, gzip or bare, and in which encoding. The old `subtitle_test` reimplemented the picking logic inside the test, so it proved the archive package works rather than that we use it correctly |
| `M3uParser` | Pure already, and had no test at all despite reading every playlist the app loads — all written by strangers |
| `MovyCipher` | Five private statics reachable only by running the whole fetch-and-decrypt pipeline against the live site. `rotl` rotating rather than shifting is the kind of thing a test catches and a reading does not |
| The **subtitle providers** | The Stremio addon protocol defines the `{"subtitles": [...]}` body and OpenSubtitles speaks it too; Wyzie's bare array is its published API. Pinned: the cross-endpoint dedupe (three mirrors, one file, listed twice without it), format inferred from a file name when an addon omits `SubFormat`, and both spellings of the fields Wyzie sends two ways |
| **Xtream `player_api.php`** | Hundreds of separate panel installations answer it and disagree constantly. Pinned: `user_info` wrapper or flat root, `auth: 1` or `status: Active`, `stream_id`/`id`, `name`/`title`, `stream_icon`/`cover`, episodes keyed by season-as-a-string, EPG times as epoch or datetime, EPG text base64 or in the clear |
| **VOE's payload cipher** and Luna's RSC reader | VOE is six reversible steps, so the test builds a payload with the inverse and checks the round trip — every step pinned against its own inverse, no fixture to go stale. Luna's transport is a Next.js RSC stream, which is a framework's format rather than Luna's markup |

**What is deliberately not covered:** the scraping itself — finding the script
tag, matching the slug, reading a search page. That input is a website, and a
fixture captured today proves the parser handles the shape it was given while
saying nothing about the shape it will meet next week. Worth having eventually,
a smaller claim than the six above, and not a reason to hold a release.

---

## Waiting on a device

CI can prove a parser handles a shape and a widget lays out at a width. It
cannot tell you whether a stream reaches a TV or whether a tap *feels*
immediate. Each of these is already built and tested as far as it can be.

### Cast, against a real receiver (#28)

**Two answers came back from a device on 2026-09-14, and neither is a bug.**

**Android, torrent source → "this source streams from your device".** Working
as designed. The stream is served by TorrServer on the phone itself, at a
`127.0.0.1` address; a receiver asked to fetch that asks *itself*. `canCastUrl`
rejects the whole 127/8 block rather than offering a button that always fails.
Direct and debrid sources do cast — the snackbar now says so, instead of
"pick a different source", which read as "try them all".

**Windows → no Cast option at all.** Also by design, and not fixable here:
`flutter_chrome_cast` implements Android and iOS only, because Google ships no
Cast *sender* SDK for Windows. `CastService.isSupported` is false there and the
button is absent. Casting from a Windows build would mean a different protocol
(DLNA/UPnP), which is a feature, not a fix.

**The open item this leaves** is the one that would actually let a phone cast
a torrent: bind the torrent server to the LAN and hand the receiver the
device's LAN address instead of loopback. Question (1) — *does the plugin
even allow it* — has since been answered by reading the code, and it splits
by platform.

**iOS: dead, and not worth revisiting.** The plugin's own Go shim
(`tool/go-shim/torrserverkit.go`) hardcodes
`net.Listen("tcp", "127.0.0.1:"+portStr)`. Loopback only, with no flag.

**Android and desktop: the plugin is not the obstacle.** It spawns the
external TorrServer binary with only `-p` and `-d`, plus a caller-supplied
`extraArgs` passthrough, so the bind address is the binary's own. `baseUrl`
is a getter with no setter and cannot be repointed — which does not matter,
because `port` is public and the LAN URL would be built here from
`NetworkInterface.list()` rather than taken from the plugin.

What the shipped binary does is the part still unproven. `libtorrserver.so`
out of the v1.6.3 APK is a Gin server that hands Gin its own listener,
carries a `0.0.0.0` literal and prints `Local IPs:` — all consistent with
listening on every interface, and none of it proof, because strings in a
64 MB binary are not a bind call.

**So the device question is now one line.** With a torrent playing on the
phone, from a laptop on the same Wi-Fi:

```
curl http://<phone-LAN-IP>:<port>/echo
```

An answer means it binds the LAN and the feature is possible; a refusal means
the idea stops there. Only then does (2) — Android's cleartext-HTTP policy and
the phone's firewall — matter, and swapping the host for the LAN address is
easy by comparison.

### Why it did not work: discovery was never started (fixed 2026-09-15)

A device reported Cast still not working, and the cause was in our code, not
the network. `CastService` exposed `devicesStream` and the picker subscribed
to it — but **nothing ever asked the plugin to scan**, so the stream had no
producer and the sheet sat on *"Looking for Cast devices on your network..."*
indefinitely.

That is not obvious from the plugin's README, which says discovery is
automatic once initialised. Its own source says otherwise, on both platforms:

- **Android** — `onAttachedToEngine` only wires up the method channel. The
  `MediaRouter.addCallback(selector, callback, CALLBACK_FLAG_REQUEST_DISCOVERY)`
  that actually scans lives *solely* inside the native `startDiscovery`, which
  is reachable only from Dart.
- **iOS** — the same through `GCKDiscoveryManager`, and worse: the SDK option
  `startDiscoveryAfterFirstTapOnCastButton` defaults to **true**, meaning it
  waits for a tap on its *own* native Cast button. This app draws its own
  button, so that tap never came.

The fix is `CastService.startDiscovery()` when the picker opens and
`stopDiscovery()` when it closes (scanning holds the radio awake), plus
setting that iOS option to false. `cast_content_type_test` pins that the
calls exist and are on the sheet's lifecycle rather than in `build`.

**This has not been confirmed against a receiver yet** — it is a fix for a
cause found by reading, and the next device test is what decides whether it
was the only one.

**Still unverified, and still needing a receiver:**

1. Does a **movie** from a direct/CDN source reach the TV and play? (Known
   limit: the Cast SDK has no sender-side way to attach Referer/User-Agent, so
   scraper sources needing them fail on the TV while playing fine locally.)
2. Does a **Live TV channel** reach the TV, and does the receiver show it as
   live — no seek bar, no phantom duration?
3. Does **disconnect** return playback cleanly?

### Series creators (#39) — confirmed on device, 2026-09-15

`created_by` is populated in practice. A device reports the Creator card
showing correctly, so the `/tv/{id}/aggregate_credits` fallback — a larger
payload whose entries carry a `jobs` array instead of a single `job`, needing
a TV-shaped branch in the parser — is **not needed** and is not being built.

### The player, in your hand — confirmed on device, 2026-09-15

Reported as feeling good. The list this section carried (menus in landscape,
panel dismissal, seek amounts, the CC button, Live TV's single tap, backup
export #50, Simkl #51) was a checklist for one pass on real hardware, and that
pass has happened. Nothing here is outstanding.

---

## Settled decisions

### The two players

Live TV is the Movies/Series/Anime player **with fewer parts**, not a second
player that looks similar. `test/player_convergence_test.dart` guards that:
the shared widgets stay referenced, neither player hand-places a popover,
and no menu grows a close button back.

**What Live TV legitimately lacks**, because a live feed has no use for it:
seeking, a seek bar (a live-edge row sits where it would be — absence alone
read as a control that failed to load), and playback speed.

**A reversed decision, recorded as reversed.** This file used to keep the
Live TV aspect-ratio pill as a deliberate divergence: one setting behind a
gear costs a click rather than saving one. Sound in isolation, wrong against
the larger goal — it was the last control on the page with no counterpart in
the other player, and "same panel, fewer rows" is worth more than the tap.

### What stays dark, in either theme

Light mode is finished (#52, #59, #61-#64), and "finished" needed a
definition, because a colour that does not follow the theme is not
automatically a bug. Three things legitimately stay dark, and every
remaining dark literal in `lib/` is one of them and says so in a comment:

- **Chrome over video.** The player, and the `PerformanceLiquidLens` behind
  its menus — moved out of `widgets/common/` into `widgets/player/`, since a
  file in `common/` whose only caller is the player looks like a shared
  widget somebody should migrate.
- **Artwork, and scrims over it.** Poster and thumbnail placeholders, the
  hero washes, the header scrim. What sits on these is `AppColors.onAccent`,
  fixed white, for the same reason: a poster is a poster in either theme.
  The three details pages are this case at page scale — a full-height
  backdrop behind every control.
- **Colours that are data.** Broadcasters' brand gradients in
  `hardcoded_channels.dart`, the saved gradient on a user's own channel, and
  the palette definitions themselves.

So the rule for the next person: before tokenising a dark literal, ask which
of the three it is. If it is none of them, it is a surface and wants a token.

### Where the TMDB key comes from

**Answered on device, 2026-09-14:** the status line read *TMDB rejected the
API key (401)*. The key was the fallback constant committed in
`tmdb_settings.dart`, and a TMDB key in a public repository gets found and
revoked. Three causes on our side were already fixed (#38, #53 and the TMDB
commits); the fourth was that the key itself was dead.

The constant is gone. What replaces it is a choice, not a default:

| Who | What to do |
|:----|:-----------|
| A user | **Settings → Sync → TMDB Cast Photos → Connect**, with a free key from themoviedb.org. The card asks for this when no key is set |
| This project | Put `TMDB_API_KEY` in the `DOTENV_CONTENTS` repository secret. Fresh installs then work with no setup, and the key rotates without a new release |

**Closed on device, 2026-09-14.** `TMDB_API_KEY` is in the `DOTENV_CONTENTS`
repository secret, and v1.6.3 is the first published build to carry it. A
device confirmed the whole chain end to end: cast photos and character names
appear on a details page, and a row that used to show three names now shows
the full billing. That was the one thing CI could never check —
`api.themoviedb.org` is blocked from the runners — so the table below is what
is left of this item: a way to tell, from the status line, whose bug it is.

| What the status line says | What it means |
|:-------------|:--------------|
| *Loaded N cast and M crew from TMDB* | TMDB is fine — a wrong-looking row is the page's bug |
| *TMDB rejected the API key (401)* | That key is invalid or revoked |
| *Could not reach TMDB* | Network, DNS or a captive portal |
| *TMDB has no entry for this title (404)* | That one title only; try another |
| nothing at all | No request was made — the addon supplied everything, or the IMDb id never resolved |

### macOS is Apple Silicon only

`flutter build macos` emits a universal binary; the workflow thins it to
arm64 with `lipo`. Measured on v1.6.2: the x86_64 slices were **50.2 MB of a
102 MB bundle**, across 37 fat binaries — half the download, for an
architecture this project's audience does not use.

**An Intel Mac cannot run these builds.** Not slowly; at all. That is the
decision, made deliberately, and the guard enforces it: the check that used
to require both slices now requires that only arm64 survives.

If it ever needs undoing, the shape is **two jobs, each thinned to its own
architecture** — two genuinely different artifacts. It is explicitly *not*
the pre-1.6.3 layout, where two jobs built the same universal app and shipped
it twice under names promising a choice that did not exist.

### The PR checks are three parallel jobs, not one

`pr-checks.yml` runs Analyze & Test, Android Build and Linux Desktop Build
side by side. Analyze & Test is the one job with no Java, no Gradle and no
platform toolchain, because it is both the check that fails most often and
the one whose answer is wanted first — it should not queue behind setup it
never uses. It was also the reason a red analyze used to hide whether the
APK builds: they were steps in one job, so the first failure ended the run
and the second only surfaced a push later.

**Why an Android build at all, rather than something lighter.** `flutter
analyze` and `flutter test` never invoke a platform toolchain, so neither
can catch a build-configuration break. That is not hypothetical here: the
Android build sat broken on a Windows-only JDK path in `gradle.properties`
long enough that its release job was deleted rather than fixed. Android and
Linux are the two cheapest compilations that exercise a real toolchain
(Gradle/NDK and CMake), and both run on the same ubuntu tier; Windows and
macOS runners cost several times as much per minute and stay release-only.
The APK is an artifact of the check, not its purpose — it is uploaded
because a built APK is free to keep once the job has produced it.

**Infos are fatal, and that is only defensible because the count is zero.**
`--no-fatal-infos` was the setting while the tree carried 133 `prefer_const_*`
suggestions — and one real `unused_local_variable` warning went unread in
that list and put `main` red. A check whose normal output is a screen of
ignored lines is not a check. The sweep (#66) took it to `No issues found!`
and the flag went to `--fatal-infos` in the same PR, so it stays there.

If a new info is genuinely not worth fixing, turn the rule off in
`analysis_options.yaml`, where the decision is visible and reviewable. Do
not put the flag back and go back to scrolling past the output.

### Declined, so they do not get re-litigated

- **Multiple hubs / a hub switcher of any shape.** There is one hub; a second
  is a bigger conversation than reintroducing the old chrome.
- **Forcing all playback sources onto one `PlaybackCoordinator` contract
  beyond what exists.** No second controller type to unify against.
- **`interneto/tv-multiview`'s channel data.** No stated license, no
  direct-stream-URL field. IPTV multi-view shipped as an original grid
  feature instead.
- **Renaming the Kotlin source package** from `com.example.playtorrio`. It is
  a namespace, not an identifier anything outside the module sees.
- **Merging Movies, Series and Anime into one section.** Movies and Series
  are *already* one implementation — `TypeCatalogPage(type: 'movie')` and
  `TypeCatalogPage(type: 'series')` are the same widget with a different
  string, both opening the same `DetailsPage`; merging them removes a
  navigation entry, not a duplicate. Anime is a different stack on purpose:
  `AnimeMedia` from AniList rather than `MovieDetail` from addons, its own
  library service, scraper and Arabic variant, and a character-to-voice-actor
  relation with no equivalent for film. Flattening it would cost the
  anime-native data that is the reason to have the section. The part worth
  building was the single search, shipped as #48.
- **The two recommendation rows on a details page are not duplicates.**
  `relatedItems` is the set the title belongs to, passed in; `_similarItems`
  comes from the BestSimilar scraper.

### Audit results that came back clean

Recorded so they are not re-audited from scratch: no TLS bypass anywhere; no
plaintext `http://` to non-local hosts; no leaked credentials (tokens live in
`flutter_secure_storage`, with a lazy migration off the old plaintext prefs);
no undisposed controllers, timers or subscriptions; no unused dependencies —
the two that look unused in Dart (`media_kit_libs_video`,
`media_kit_libs_windows_video`) ship native libraries and must stay. Every
file in `lib/` is reachable from `main.dart`.

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

**Reviewed through `f69617b` (2026-09-13). The list is empty.**

Taken: `db2a4b9` and `0343720`, both hardening the Linux CI job against a
`dl.google.com` apt source the runner image ships that periodically breaks
`apt-get update` — ported to **both** `build.yml` and `pr-checks.yml`.

Not taken, with reasons, so they are not re-reviewed:

| Commit | Why not |
|:-------|:--------|
| `9616808` | Blurred dual-layer hero backdrop to kill black bars. Every hero in this fork already uses `BoxFit.cover`, which fills and crops. It fixes a problem we do not have. |
| `29a4127`, `1da1940` | IPTV channels, search and storage — the area this fork has diverged furthest in (#45, #46 and the portal browser are ours). Read as ideas, not ported as patches. |
| `d2f8074` | IPTV portal manager responsiveness. A near-total rewrite of `iptv_portals_modal.dart`; our copy carries Cloud Vault, the modal customizer and the M3U tab, so a straight port would drop them. The reported overflows were hand-fixed in #40 instead — all four, not the two reported. |
| Support Dev sponsor monetization | Out of scope for this fork. |
| Keyboard aspect-cycle HUD | Mov already has an aspect control in the player's settings; a second affordance for one setting is a regression. |

### Signing and releases

Android release signing **is configured** — `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` are both set, so released APKs install over each
other and the in-app updater works (see
[release signing](RELEASES.md#release-signing)). No other platform needs
signing, because none of them self-install — see
[RELEASES.md](RELEASES.md#other-platforms).

The dotenv secret was **not set**, and that was the one outstanding release
secret. Every published build ships an empty `.env`, so Trakt sign-in and
Discord Rich Presence are inert in released binaries. **TMDB is affected too**,
now that the dead source-committed fallback key is gone: without
`TMDB_API_KEY` in `DOTENV_CONTENTS` a fresh install has no key, and the settings
card asks for one. **Simkl is no longer blocked by it** (#51): register a free app at
simkl.com/settings/developer and paste the client ID — Simkl's PIN flow
authenticates with the id alone, so there is no secret to ship.

**`build.yml` has no analyze or test step.** Only `pr-checks.yml` runs them,
and only on a pull request, so a PR merged before its checks finish ships
unverified — that is how v1.5.8 went out. Either wait for `pr-checks` before
merging, or accept that the release build proves only that it compiles.

### Closed items

An index of what each number means, for reading old commits and PRs. #1–#14
closed before this file was rewritten for maintenance mode and are not listed
— they live in git history.

| # | Item |
|:--|:-----|
| #15 | Mobile-first, made checkable (`test/mobile_first_test.dart`) |
| #21 | The logo's film-strip rule |
| #28 | Google Cast — sender path fixed; receiver test is above |
| #38 | Cast and crew actually load |
| #39 | Series creators — device check is above |
| #40 | IPTV portal modal overflows (four, not two) |
| #41 | One details spine and one section heading |
| #42 | The Live TV player converged on the shared controls |
| #43 | Library tabs became the three states |
| #44 | One amount per seek control (±10s double-tap, ±30s buttons) |
| #45 | Live TV Liked row and portal pin |
| #46 | Channels you make yourself |
| #47 | Watch history |
| #48 | One search across Movies, Series and Anime |
| #49 | Settings scroll from anywhere in the window, not just the centre column |
| #50 | Backup export/import through the system file picker |
| #51 | User-supplied Simkl client ID, and a reason when Connect fails |
| #52 | System / Light / Dark switch (the colour migration is #59) |
| #53 | One ISO-639 table for subtitle providers (two were 51 languages short) |
| #54 | Wyzie subtitle downloads go through `SubtitleExtractor` like the rest |
| #55 | One master-URL builder for cinesrc/cine.su/bcine (was triplicated) |
| #56 | One pipeline for vidfast/vidup (was two ~200-line near-clones) |
| #57 | `print()` out of `lib/`, `avoid_print` enforced as a warning |
| #58 | A silent scraper no longer holds the stream search open forever |
| #59 | The colour migration behind #52 — `AppColors`, and what it excludes |
| #60 | Every `package:http` call carries a timeout, enforced by a test |
| #61 | Nav chrome (top bar, section switcher, mobile tab bar) follows the theme |
| #62 | `HeaderPillSurface`: header pills know when they float over a hero |
| #63 | `AppColors.accent` — the palette picker reaches the whole app (was 156 hardcoded violets) |
| #64 | Light mode finished: every remaining dark literal is either a token or annotated as artwork |
| #65 | `OverArtwork`, the details backdrop bounded to its hero, and the last black backgrounds (Live TV, settings, genre chips) |
| #66 | Three parallel PR-check jobs, and the `prefer_const` sweep that emptied the analyzer's info list |
