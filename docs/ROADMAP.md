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

### Translation (#68) is closed

This section used to describe hardcoded Arabic across the Arabic anime
pages as the last outstanding piece of #68, needing a native review before
gaining es/pt/en translations. That description is now stale: the Arabic
anime catalog (`anime_arabic_details_page.dart`, `anime_arabic_stream_sheet.dart`
and its services) was deleted outright in the commit that removed the
separate Arabic feed (see CHANGELOG's "The Arabic anime catalog is gone"),
not translated -- there was nothing left to migrate once those files were
gone. Checked 2026-09-28: a full scan of `lib/` for Arabic-script
characters turns up exactly two, both intentional and out of scope --
`stream_model.dart`'s language-detection regex (matches the word "Arabic"
in scraped release titles, in either script) and
`appearance_settings_page.dart`'s language-switcher entry (shows each
language in its own name on purpose, same reason `'es'` reads `Español`
rather than `Spanish`). Nothing under #68 remains pending.

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

**The sweep is now complete: every bare `GestureDetector` in `lib/` has been
looked at.** `watch_screen.dart` was the first file done; from there it
covered the player transport (`player_center_controls.dart`,
`player_seek_bar.dart`, `player_volume_control.dart`,
`player_episodes_panel.dart`, `player_sources_panel.dart`,
`sub_sync_bar.dart`), the shared catalog card shell (`InteractiveCardShell`
-- which propagates focus to every `MovieCard` and `IptvChannelCard` on the
Films/Series/Anime/Live TV grids with no change needed at either call site),
`AnimeCard`, the hub's hero-carousel page dots (`browse_scaffold.dart`), the
Details and Anime Details pages (synopsis toggle, episode cards, SUB/DUB
chips, the shared `_HoverScale`), Catalog/Discover/Search/Collection page
filter chips, the Library shelf, Addons settings, the IPTV channel sheet,
portal browser (category rows, three channel-card variants, favorite pins),
the IPTV multiview/timeshift player, the Universal Play Bar, the
Continue Watching card and its overlay buttons, the IPTV hero slide's
Watch/Sources buttons, and a batch of smaller shared widgets (`LikeButton`,
`SliderArrow`, `GenreTagRow`, `LibraryActionsRow`, `UpcomingCalendarRow`,
`MagnetFilesView`). Same two primitives throughout: `FocusRing` where a
widget already painted one (the player controls), `HoverButton`'s own
focus-reuses-hover styling everywhere else.

**A handful of `GestureDetector`s were deliberately left alone**, because
making them focusable would be wrong, not just unfinished:
- **Fullscreen tap-to-reveal-controls surfaces** (`player_screen.dart`,
  `iptv_player_page.dart`) -- there is no D-pad equivalent of "tap the
  screen"; a remote already reaches every control directly once the
  transport is visible, so turning the whole screen into one giant focus
  target would only get in the way.
- **Tap-outside-to-dismiss barriers** behind the player's menus and side
  panels (`player_screen.dart`, `iptv_player_page.dart`) -- a keyboard or
  remote user dismisses these with Back, not by tabbing to an invisible
  full-screen catch-all.
- **No-op tap absorbers** that exist only to stop a panel-content tap from
  bubbling to the dismiss barrier behind it (`player_screen.dart`) -- there
  is nothing to activate.
- **`library_shelf_page.dart`'s `onLongPress` remove-title gesture** on a
  `MovieCard` -- long-press has no remote equivalent, and the card's own
  primary action (open/play) is already focusable via `InteractiveCardShell`.

There is no guard test enforcing full coverage going forward -- adding one
now would need to special-case the exclusions above. Untested against a real remote: the
key set (`select`, `enter`, `gameButtonA` for `HoverButton`) is a reasonable
guess at what different remotes and controllers send, matched to what
`PlayerToggleChip` already assumed, not a confirmed one. No focus order has
been set anywhere either -- Flutter's default reading-order traversal is
what a remote will get until someone checks whether that is the order a
viewer actually wants.

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

### TV-native UX redesign (#80)

**#78/#79 made the app D-pad-*reachable*, not TV-native.** Checked against
the actual codebase rather than guessed: 53 of 630 `fontSize` declarations
are under 11px (episode/source badges, sized for a phone 12-18in away, not a
couch 8-10ft back); 8 files present core flows (stream picking, channel
picking, casting) as `showModalBottomSheet`s, a phone gesture; zero uses of
`FocusTraversalGroup`/`FocusTraversalOrder` anywhere, so a D-pad gets
Flutter's default reading-order traversal on every grid, unchecked against
what a viewer would expect; only 16 `autofocus: true` uses total, almost all
in player menus, so most hub/catalog pages have no deliberate landing focus.
`ScreenTier` picks by width alone, so a TV is sized as a wide desktop window
rather than something viewed from 10 feet away.

Scoped into four phases, decided 2026-09-28:

1. **TV-mode detection.** A native platform-channel check against Android's
   `UiModeManager` (`UI_MODE_TYPE_TELEVISION`) -- not a pub dependency, not a
   width/aspect heuristic (would misfire on tablets/Chromebooks in
   landscape) -- exposed as a `ValueNotifier<bool>` service matching the
   `AppThemeService`/`IptvSettings` pattern already used throughout. Blocks
   phases 2 and 3.
2. **Type & spacing.** Targeted fixes to the 53 undersized `fontSize` spots
   found above via a `TvType.scale()`-style helper gated on phase 1 -- not a
   system-wide type-scale rewrite, since there is no central type scale to
   hook into (630 inline literals).
3. **Sheets to full-screen routes on TV.** All 8 `showModalBottomSheet`
   call sites swap to the app's existing `pushPage`/`pushFullscreenPage`
   helpers when phase 1 reports a TV, reusing existing sheet content/logic
   unchanged. (Only `iptv_portal_browser_page.dart` already branches UI
   shape by width today; `anime_details_page.dart`'s `isDesktop` branching
   is layout-only and does not extend to its stream sheet -- the other 6
   sheets have no wide-screen alternative at all.)
4. **Focus order, starting focus, and a real indicator for non-card
   targets.** `FocusTraversalGroup`/explicit order plus `autofocus` on each
   hub/catalog page's first tile; `FocusRing` (already built for the player
   controls) on text/icon-only `HoverButton` targets that currently rely on
   a ~2% hover-scale as their only cue.

**Starting with phase 4's focus-order half**, since it needs no
TV-detection groundwork, helps keyboard/D-pad users on every platform (not
just confirmed TVs), and is the most likely source of an actually-stuck
viewer today. Phases 2-3 follow once phase 1 (detection) lands.

**Starting-focus landed.** A shared `FirstFocusScope` (hands focus to the
first focusable descendant once content is ready, exactly once) now covers
every hub page via `BrowseScaffold`, plus the Catalog, Discover, Search,
Collection, Library shelf, IPTV search, IPTV portal browser, Anime, Anime
Search and multi-view channel-picker grids/lists -- deliberately skipping
auto-rotating heroes and filter-chip rows in favor of the first real content
card. Left alone on purpose: `anime_details_page.dart`'s small embedded
episode-number grid (focus there belongs on the page's Play button, not a
mid-page grid) and the multi-view *playback* grid (its tiles use tap-driven
state, not `FocusNode`s, so autofocus has nothing to land on).

**Traversal order checked -- mostly already correct.** The premise above
("a D-pad gets Flutter's default reading-order traversal... unchecked
against what a viewer would expect") assumed reading order followed widget
*declaration* order. It doesn't: `ReadingOrderTraversalPolicy`, Flutter's
default, sorts focusable nodes by on-screen geometry (top-then-left) for
both Tab/Shift+Tab and D-pad arrow keys (`inDirection`), so a floating
control's position in a `Stack`'s children list doesn't affect when it's
reached. Checked six places where a back button or floating transport bar
is declared *after* the scrollable content it floats over (`details_page`,
`anime_details_page`, `watch_screen`, `catalog_page`, `discover_page`,
`hub_page`'s `UniversalPlayBar`) -- that ordering is there so the control
*hit-tests* on top for touch/mouse (`Stack` hit-tests last-declared-first),
and is unrelated to keyboard/D-pad traversal, which is already geometric.
No fix needed.

One real bug did turn up: `AnimatedSwitcher`'s outgoing child stays in the
tree, still focusable, for the whole fade-out (both its default
`layoutBuilder` and any custom one following the same
`[...previousChildren, currentChild]` `Stack` shape). Of the app's two
`AnimatedSwitcher` uses, `details_page.dart`'s season switcher genuinely
mattered -- the outgoing child is a full episode row, reachable by D-pad
mid-transition -- so its outgoing children are now wrapped in
`ExcludeFocus`. `watch_screen.dart`'s only switches a single icon; nothing
to exclude there.

**`FocusRing` landed on text/icon-only targets, closing phase 4.** The
player transport's `FocusRing` (a ring drawn just outside a focused widget)
moved to `lib/widgets/common/focus_ring.dart` so it's no longer
player-only. `HoverButton` -- whose focus cue was, by design, its existing
hover-scale lean reused for focus, since a ring around an arbitrary child
would have to guess at a shape the widget doesn't know -- gained an opt-in
`showFocusRing` flag for call sites whose child *is* a known, plain shape:
a bare icon, a short line of text, a pill. Set on all 37 such call sites
(9 icon-only, 17 text-only, 11 icon+text), found via a full audit of every
`HoverButton` use in `lib/`; left off the 5 remaining uses, which wrap a
poster, a backdrop or another card with its own strong silhouette, where
the lean alone already reads clearly.

Phase 4 is done: starting focus, traversal order, and a real focus
indicator for every kind of target.

**Phase 1 (TV-mode detection) landed.** `TvModeService`
(`lib/services/tv_mode_service.dart`), an `abstract final class` with a
static `ValueNotifier<bool> isTv` matching `AppThemeService`/`IptvSettings`,
resolved once at startup alongside the app's other services. It calls the
new `com.example.playtorrio/tv_mode` platform channel, whose Kotlin side
(`MainActivity.kt`) asks `UiModeManager.currentModeType ==
UI_MODE_TYPE_TELEVISION` -- the same native check the scoping decision
above settled on, not a pub dependency and not a width/aspect guess. Off
Android (`Platform.isAndroid` false, including every desktop/iOS build)
`initialize()` is a no-op and `isTv` stays permanently false, since only
Android exposes `UiModeManager`. Unblocks phases 2 and 3.

**Phase 2 (type & spacing) landed.** `TvType.scale()`
(`lib/services/tv_type.dart`) multiplies a `fontSize` by 1.4 when
`TvModeService.isTv` is true, unchanged otherwise -- chosen so the audit's
worst offender (8.5px) clears the same 11px floor the audit itself used to
flag a spot as undersized. Applied at exactly the 53 spots the audit
found, not a system-wide rewrite: each was either a literal `fontSize:`
under 11 wrapped in `TvType.scale(...)`, or, for a `const TextStyle`, the
same plus dropping the now-invalid `const` (and adding it back on any
sibling `Color(...)` literal that only inherited constness from the
`TextStyle` around it, to keep `prefer_const_constructors` clean). Left
alone on purpose: the 600+ other `fontSize` literals the original audit
did not flag.

**Phase 3 (sheets to full-screen routes) landed -- #80 is complete.** A new
`showAdaptiveSheet()` (`lib/utils/navigation/adaptive_sheet.dart`) checks
`TvModeService.isTv`: true pushes the same builder's content via the
existing `pushPage` onto the root navigator, false calls
`showModalBottomSheet` exactly as before. All 8 call sites the audit found
now go through it. `AnimeStreamSheet` had three separate inline
`showModalBottomSheet` calls and no shared factory, unlike the other five
sheets; it gained its own `static Future<void> show(...)`, matching
`IptvChannelSheet`/`CollectionPickerSheet`/`PlayerCastSheet`'s existing
pattern, so all three of its call sites share one control point. Each
sheet's own content and chrome are unchanged, per the phase's scope --
several hardcode a rounded-top-corner decoration meant for bottom-sheet
presentation, so on TV they may show as a rounded panel rather than true
full-bleed content. Not fixed here: the actual problem this phase targets
is the dismiss gesture (drag/tap-outside, neither reachable by D-pad),
which the routing swap alone fully solves, since a normally pushed route
already answers to the remote's hardware Back button like any other page.
Untested against a real TV or Android TV emulator in this environment --
the swap was verified by reading each call site and `TvModeService`, not
by driving a device.

All four phases of #80 are now done.

### Library tab renamed to Profile; search moved to the top bar

Decided 2026-09-28, at the user's request. Three questions, three answers:

1. **What happens to the Library tab's existing content when it becomes
   Profile?** Kept as-is and settings added on top, not replaced by it --
   Watchlist/Watched/Liked, Continue Watching and Downloads get used far
   more often than Settings, so burying them behind a settings-only tab
   would demote the app's most-used feature for its least-used one. A
   `SettingsIconButton` was added to the tab's own header (`CollectionPage`,
   via `LibraryTabs`' existing `trailing` slot) instead, alongside the
   global gear rather than replacing it -- two paths to the same
   `SettingsPage`, one discoverable from wherever a Profile-style tab is
   expected to hold account-adjacent things, one already muscle-memorized
   from every other screen.
2. **What to call it.** "Profile" over "Account"/"You"/"Me": it reads as
   "your stuff + your account" the way Netflix/Disney+/Prime Video use the
   word, which matches a tab that is still mostly saved content with
   settings added, not the other way around. Only the display label and
   icon (`Icons.account_circle_rounded`) changed -- `HubSection`'s internal
   id stays `'collection'`, and the page's own class/file
   (`CollectionPage`/`collection_page.dart`) was deliberately left
   unrenamed, matching this app's existing practice of an internal id
   outliving a display label (the same section's id was already
   `'collection'` while showing "Library").
3. **Where search goes.** Four separate `PageSearchButton`s -- one inlined
   in each of Films/Series/Anime/Live TV's own header, repeating the same
   icon, and absent from the Profile tab entirely -- became one
   `SearchIconButton` in `TopBar`, next to the existing Settings gear, on
   every tier. `HubPage` decides where it opens based on
   `HubController.instance.mediaSection`: the unified `SearchPage`
   everywhere, except Live TV, which keeps its own `IptvSearchPage` --
   a keyword match against a portal's stream list, not a title-catalog
   search, so it was never the same kind of result the unified page
   returns. `PageSearchButton` is deleted; nothing else referenced it.

Untested against a real device in this environment -- verified by reading
each call site, `TopBar`, `AdaptiveNavShell` and `HubPage`'s wiring, plus
the existing widget test suite (updated for the rename and extended for
the new search icon), not by driving the app.

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
