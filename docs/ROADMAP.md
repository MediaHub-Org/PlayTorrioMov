# Roadmap — PlayTorrioMov

**What is left to do, and nothing else.** Shipped work is in
[CHANGELOG.md](../CHANGELOG.md), whose end indexes every item number
(`#15`–`#80`). How to do the work — the translation method, the overflow
probe, the RTL rules, the title-identity rule — is in
[CONVENTIONS.md](CONVENTIONS.md). The release process is in
[RELEASES.md](RELEASES.md).

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-10-04**, on `v1.9.3+50`.

---

## Not doing, so it stays decided

| What                                                     | Why not                                                                                                                                                                                                                                                                                                                                               |
|:---------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Xtream/portal movies and series as parent sources (#77)  | **Not viable right now.** Needs a pipeline, not a tab: match entries to catalog titles (ids where the feed has them, guarded title-plus-year where not), play through the existing details/player so history sees one title, and decide where unmatchable entries live. A wrong match in Films is worse than an honest gap. Portals stay Live TV only |
| Size/sort filter under Sources & Filters                 | Browsing choices for *this* title, not a standing preference; they stay on the sources screen                                                                                                                                                                                                                                                         |
| Keyboard shortcut for the subtitle panel                 | `A`, `S`, `R`, `C` are taken. Revisit if a key frees up                                                                                                                                                                                                                                                                                               |
| Merge `megasource` / `nova`                              | Shared skeleton, but Nova munges titles MegaSource does not; unifying them needs a hook with nothing in common between its two sides                                                                                                                                                                                                                  |
| Offline tests for page scraping                          | Input is one host's markup on one day, so a fixture pins that day. Ciphers and response formats are covered                                                                                                                                                                                                                                           |
| Cast from Windows                                        | Google ships no Cast sender SDK for Windows; it would be DLNA/UPnP, a feature not a fix                                                                                                                                                                                                                                                               |
| Sponsor/monetization, aspect-cycle HUD (upstream)        | Out of scope; the player settings already have an aspect control                                                                                                                                                                                                                                                                                      |
| Single-select audio filter                               | "English or Spanish" needs multi-select; the checkmark delay was a stale-rows bug, since fixed                                                                                                                                                                                                                                                        |
| Alphabetical online subtitle order                       | The list leads with the language being heard on purpose                                                                                                                                                                                                                                                                                               |
| Translating catalog descriptions, AniList genres/formats | Addon and AniList data, sent back to their APIs to filter; would need a display-name map per language. See CONVENTIONS                                                                                                                                                                                                                                |

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
