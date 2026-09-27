# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#76`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-27**, on `v1.8.11+44`.

---

## Pending

**Nothing here needs a device.** Hardware checks are not tracked in this file
any more: #28's Cast path, the phone-casts-a-torrent question, forced-subtitle
rendering, #74's pill rail and the ORIGINAL audio badge were all
"seen listed, not seen working", and a list of things only one person can look
at is not a roadmap. Each is now a doc comment on the thing it is uncertain
about, where whoever next opens that file will meet it:
`PlayerCastSheet` (#28), `CastService.canCastUrl` (the torrent question, with
the one `curl` that answers it), `PlayerOriginalBadge` (#76),
`FilterPillRail` (#74), and `_buildSourceTabs` in the subtitle menu (forced
tracks).

### What holds without anyone re-auditing it

Six invariants fail in CI rather than needing a pass over `lib/`:

| Test | Invariant |
|:--|:--|
| `no_hardcoded_text_test` | No `Text()` holds an English sentence |
| `icon_button_tooltip_test` | Every icon-only control carries a label, button or not |
| `rtl_directional_padding_test` | No padding, and no content alignment, names a physical edge |
| `american_spelling_test` | One spelling of every word, `.arb` files included |
| `text_scale_overflow_test` | 26 widgets survive 3x text scale on a 360px view |
| `arrow_affordance_test` | Every rail arrow turns around for Arabic, and the player transport does not |

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
