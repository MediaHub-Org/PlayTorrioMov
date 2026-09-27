# Roadmap — PlayTorrioMov

**What is left to do.** Shipped work is in [CHANGELOG.md](../CHANGELOG.md),
the release process is in [RELEASES.md](RELEASES.md), and item numbers
(`#15`–`#74`) are indexed at the end of the changelog.

Item numbers are never renumbered or reused, so `#43` means the same thing in
a commit message, a pull request and here.

Last reconciled: **2026-09-27**, on `v1.8.11+44`.

---

## Pending

Two kinds of work are left, and they need different things from you.

**Actionable now, no hardware** — #68 and #69. Neither is a research problem;
each has a method below that has already been used. What is left of both is
now the part a test cannot hold, which is worth being precise about:

| Held by a test | What that leaves |
|:--|:--|
| `no_hardcoded_text_test` — no `Text()` holds an English sentence | Strings built from data, which stay English on purpose |
| `rtl_directional_padding_test` — no padding names a physical edge | ~87 `Alignment` constants and icon direction, which need judgment per site |
| `icon_button_tooltip_test` — every icon-only *button* carries a label | Icon-only controls that are not buttons: ~24 candidates, and the count is unreliable |
| `text_scale_overflow_test` — 19 widgets survive 3x on a 360px view | ~46 files with a fixed `height:` that nothing has probed |

An invariant with a test behind it does not need revisiting, so the four
right-hand cells are the work. Each of them needs a judgment a test cannot
make, which is why none of them is behind one.

**Needs a device** — #28 and the torrent-cast question. Nothing here can be
advanced by reading or writing code; each is one test away from an answer.

### Open questions

**Whether more belongs under Sources & Filters (#72).** #72 shipped the audio
language and quality filters as a global default. #75 then merged the audio
filter with the preferred-audio ranking and made both filters multi-select,
which settled the page's shape: two blocks, one per media kind. The size /
sort filter and the add-on filter on the sources screen are still
per-episode. A size range and a "largest first" sort are browsing choices for
*this* title, not a standing preference, so they stay on the sources screen —
the question #72 left open is answered by leaving them where they are.

**The preferred-audio ranking has no way to be scanned.** #73 applies the
ranking on the first non-empty track list only, once. If a source's tracks
arrive in stages, a late update will not re-apply it — deliberate, so a manual
switch in the audio menu is never undone, but it means a file whose tracks
arrive after the first frame keeps its own default. Not observed yet on a real
device.

**"Original" on an audio track is a guess, and it is labelled as one.** #76
badges the track the file *opens with* as ORIGINAL, because there is no
original-language flag to read: the media_kit fork this builds against
exposes no `isDefault` or `original` marker on an audio track, and mpv's own
track list carries none either. What a release ships as its opening track is
its own statement of which one it is, which is what other players treat as
primary -- but a release that defaults to the dub would badge the dub. The
subtitle auto-match on `C` does not rely on it: it matches the *selected*
audio language, which is always the language being heard. Worth checking on a
multi-audio file that defaults to a dub.

**The `C` key no longer opens the subtitle panel, and nothing else does.**
`A`, `S` and `R` are the audio, speed and aspect menus, so there was no free
key to give the panel once `C` became a toggle. Keyboard-only users reach it
only through the transport bar, which needs a pointer. Deliverable trade made
deliberately; revisit if a key frees up.

**Embedded subtitles select by verified id, and render per format.** The
2026-09-26 report behind this section -- tracks appear on the automatic path
only -- is resolved rather than still open. `_selectEmbeddedTrack` reads
`sid` back and retries once, because the player's property set never throws
and a rejected id used to fail silently with the menu showing selected;
ASS renders through libass, other text through the overlay, bitmaps through
mpv's OSD. A `[SubDiag]` line dumps the full subtitle roster on every manual
pick, so an id mismatch shows itself in one paste. Auto-select of full
translations stays off deliberately; forced tracks are the open remainder --
seen listed, rendering not yet confirmed on a device.

**#74's pill rail has not been seen on screen.** #73 was confirmed in a local
temp build; the rail was not. What to look at: a source list too short to
overflow (no buttons at all), one long enough to overflow (a button at each
end, the left one dimmed), and a scroll to the end (the right one dimmed, the
left one lit). The buttons are driven by `maxScrollExtent`, so the case worth
checking is a row that is *just* wider than its frame.

The rail is shared by the phone and desktop layouts, so the edge affordances
are split by *platform*, not width: the fade is drawn everywhere, the button
only on desktop. A tablet is wide enough to pass any breakpoint and is still
a touch device, where the row is dragged and a button over the first and last
pill would swallow taps meant for them. The check reuses
`isDesktopPlatform()` from `horizontal_slider_scroll.dart`, which the other
horizontal rails already use -- it was a method on the mixin and is now a
top-level function so a non-mixin widget can call it too. **The phone layout
has not been seen on a device either**; what to check is that the fade reads
as "more this way" without a button, and that the first and last pill are
tappable right to their edges.

### Translation (#68)

**The hardcoded-string tail is closed, and a test holds it closed.**
981 keys are translated into Spanish, Arabic and Portuguese-BR, covering the
settings pages, the player (controls, menus, panels, the subtitle style
editor, cast sheet, loading and error screens, snack bars), the Films, Series,
Discover, Search, Anime browse and Library pages, the shared header buttons,
the mini player, the P2P warning and update dialogs, and Live TV end to end.

The tail was found by reading the *argument* to `Text(` rather than the line
it sits on, which is what the previous note said a scan could no longer do.
79 literal first arguments, 42 of them prose; a third needed no new key
because one already existed -- the portal browser had its own English copies
of four Live TV settings rows, and three badges duplicated `iptvLive`,
`commonAll` and `playerSeasonN`. Eleven more reach the screen through a named
argument or a field instead of `Text(`, so the same scan cannot see them:
two tooltips on the Continue Watching card, a hint, the player's own title for
an anime episode, the Arabic pages' error text, and the browse pages' error
heading.

**The RTL audit is half done, and the half a test can hold is held.**
`Row`, `ListView` and the Material widgets flip themselves under
`Directionality`. Physical padding does not, and 37 sites across 21 files were
using it: `EdgeInsets.only(left:)` is still the left edge in Arabic. All are
`EdgeInsetsDirectional.only(start:/end:)` now, and
`test/rtl_directional_padding_test.dart` fails if one comes back. Two were
visible rather than cosmetic — `iptv_search_page` and `watch_history_page`
applied the *page inset* with `left:`, so in Arabic the whole page hugged the
wrong edge — and two were the hardcoded-Arabic anime pages.

What is left needs eyes on a device, because it is about meaning rather than
geometry:

- **~87 `Alignment.centerLeft`-style constants.** Unlike the padding these
  are not all wrong: some are genuinely physical (a gradient, a badge pinned
  to a corner of artwork). Converting them wholesale would be a sweep with no
  test behind it. They need reading one at a time, asking "leading, or left?"
- **Icon direction.** A back chevron, a "next episode" arrow and the source
  rail's scroll buttons all point somewhere. Flutter does not mirror
  `Icons.arrow_forward_ios` for you; `Icons.arrow_forward` has a
  `matchTextDirection` sibling and these do not use it.
- **The player transport.** Seek-forward and seek-back are physical controls
  over a timeline, and a timeline in Arabic is a genuine design question, not
  a bug to fix blind.

**Catalog descriptions are not a TMDB free win, if anyone reaches for that
next.** Synopsis and genre text comes from the Stremio addon (Cinemeta by
default), read generically as `json['overview'] ?? json['description']` in
`models/movie/video.dart` — not from TMDB, which this codebase only uses for
cast/crew and scrapers' own IMDb→TMDB id matching. Translating catalog
descriptions would mean checking whether Cinemeta's own API takes a locale, a
separate and unstarted question.

**Still missing: show original titles.** The language picker ships
(`AppThemeService.setLocale`, four locales in Appearance settings) but the
opt-in display-only toggle does not: with a translated UI there is no way to
keep original/English titles, which is what Stremio, Plex and Jellyfin
default to. The rule it must obey lives in `docs/CONVENTIONS.md` under
Naming/Titles -- a translated title is not a stable identifier, while the
original is the one string every provider agrees on.

### Text scale and accessibility (#69)

**~46 of the ~68 files in `lib/` with a fixed `height:` are still
unaudited.** Twenty-five high-traffic boxes are fixed so far, the settings
pages among them, and **no named target is left** -- Live TV's portal browser
was the last, and its four search pills are capped. What remains is the long
tail, deliberately unranked: the one attempt to rank it by grepping `height:`
returned 165 hits whose loudest were `height: 4` spacers, and a ranking that
wrong is worse than none.

The details-page rails are done, and one of the three never needed doing:

| Rail | Fixed box | Verdict |
|:--|:--|:--|
| Cast | `SizedBox(height: 148)` | Name capped at 1.3. The column is avatar + 6 + name + 2 + role, and the role was already capped at 1.0; the 12px name alone wanted ~43px at 3x, asking ~151 of a 148 box |
| Similar | `cardWidth * 1.5 + 64` | Both lines capped at 1.3. The poster takes the 1.5, so the title and year/genre share a flat 64px — they want ~39 at 1.0 and ~96 at 3x |
| Related | `cardWidth * 1.5 + 8` | **Nothing to do.** The item is a bare poster in an `AspectRatio(2/3)` with no `Text` anywhere, so no text scale can move it. Listed here as a target for three revisions on the assumption it looked like the other two |

Those three are reasoned from the arithmetic rather than probed, and that is
a real gap: `DetailsPage` fetches its own data over the network and its rails
are private builders, so there is nothing a test can construct. Making them
probeable means extracting the credit card and the similar card as public
widgets — worth doing, not done here.

**Semantics labels on icon-only buttons are done, for every `IconButton` and
`PlayerIconButton` in `lib/`.** 46 went in with the Close/Back pass and seven
more after it; the earlier count of "twelve left" was wrong in a useful way --
five of the twelve were `IconButton.styleFrom` or a wrapper class whose
tooltip is required at the type level, which a grep cannot tell from a call.
`test/icon_button_tooltip_test.dart` fails on the next one added without a
tooltip, which is what Material turns into the label a screen reader reads.
The details page's three status buttons also carry the *state* now
(`Semantics(toggled:)`), because a tooltip gives a name and not an answer to
"is Watched on?"

What is left is the controls that are not buttons: an `Icon` inside a
`GestureDetector`. A scan finds 24 candidates across 15 files, and **that
number should not be trusted** -- a `Tooltip` or `Semantics` on an *ancestor*
labels the control just as well, and the scan cannot see one. The library
action row and the Continue Watching card both appear in the list and are both
already labelled. These need reading one at a time, which is why they are not
behind a test.

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
| Single-select audio-language filter                                  | "English or Spanish" is not expressible with one choice, and the multi-select checkmark delay was a stale-rows bug, now fixed by rebuilding the menu from the setting on every change — the control was never the problem                                                   |
| Pure-alphabetical online subtitle order                              | The list leads with the language being heard because that is the track a viewer is most likely to want. A Spanish-first tie with ten files each is that rule working, not a sort bug; identical counts now tie-break alphabetically, covered by a test                          |

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

**Reviewed through `39b736f` (2026-09-16). Nothing outstanding.**

Re-fetched 2026-09-20: `v3/main` has not moved (still `39b736f`, and it is
the default branch's only one), and the archived PlayTorrioMod's last commit is
still 2026-09-05. Nothing new to review or port.

Taken: `db2a4b9` and `0343720` (Linux CI hardening), plus a scraper-lifecycle
fix of our own that reading upstream surfaced: leaving a watch screen
mid-search left every scraper issuing HTTP requests into a controller nobody
was reading, because the cancel never reached `ScraperManager`. Fixed, with a
test that fails without it.

**Not taken, so they are not re-reviewed:** the CloudStream extension system
(a plugin ecosystem, and a feature rather than a fix), the blurred hero
backdrop (every hero here already uses `BoxFit.cover`), and the IPTV/storage
commits in the area this fork has diverged furthest in.
