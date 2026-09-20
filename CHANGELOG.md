# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Download from the video player**: a download button in the player's top
  bar, next to *Copy Stream URL*, for movies, series and anime. It downloads
  the source currently playing, through the same path as the download button
  on the sources list (duplicate check, folder prompt on phones, snack bar).
  Hidden for a file that is already local, and for a video opened with no
  title behind it, such as a bare magnet from search.

### Changed
- **Player top bar (phones)**: with the extra button the bar ran over on a
  360px screen, so on a narrow one the Episodes badge shows just its icon and
  the buttons and margins are a little smaller.
- **Playback speed**: the preset chips are gone; the slider and its -/+ buttons
  are the whole control. The slider now runs 0.25, 0.5, 0.75, 1, 1.25, 1.5, 2
  by step, so normal speed sits in the middle of the track. 1.75× is dropped
  to make that so.

## [1.8.5+38] - 2026-09-20

The player's bottom bar and menus: a seek bar that spans the window, a speed
menu with -/+ and presets, a simpler sleep timer, and flags that show on
Windows.

### Changed
- **Playback speed**: a large readout, a -/+ button either side of the slider
  for one step at a time, and one-tap presets underneath (0.5, 0.75, 1 —
  captioned *Normal* —, 1.25, 1.5, 2). The presets are the numbers the old
  row printed under the slider, now tappable and no longer only roughly
  under its ticks. 0.25× and 1.75× stay on the slider and the buttons.
- **Sleep timer**: the slider is gone. The presets are 15, 30, 45 and 60
  minutes, and the custom stepper now opens on 90 minutes, moves in 15-minute
  steps and reaches 8 hours, for the longer sleeps the presets do not cover.
- **Phones**: the sources and episodes panels fill the screen instead of
  covering 94% of it and leaving a sliver of video down one edge.

### Fixed
- **Player seek bar (desktop)**: the scrubber stopped a third of the way across
  the bar, with the remaining time floating in the middle. The two time labels
  were sharing the row's free space with the track; the track now takes
  everything the labels leave.
- **Subtitle flags on Windows**: languages drew as two bare letters ("ES",
  "GB") because Windows' emoji font has no flag glyphs. Flags are now bundled
  images (`assets/flags/`, 34 of them, about 1 KB each) and look the same on
  every platform.
- **Subtitles**: embedded tracks tagged `mon` no longer show a "Same as audio"
  language. They keep their own title, or their language name when untitled.

## [1.8.4+37] - 2026-09-20

A maintenance release: the settings pages translated and made 3× text-scale
safe, the player's remaining rough edges, and a few more strings out of
hardcoded English.

### Added
- **`docs/CONVENTIONS.md` and `AGENTS.md`**: how code is written here —
  naming, functions, control flow, structure, comments, failure, tests, and
  the correctness/clarity/efficiency priority order. The short agent-facing
  version is `AGENTS.md`.

### Changed
- **Details pages (#68)**: the *Cast & Crew*, *Characters & Cast* and
  *Franchise & Relations* section headers now follow the app language.
  Three new keys, 372 in all. The details-page *Similar Content* loading header
  was a hardcoded copy of a string that already had a key; it now uses it.
- **Settings pages translated (#68)**: the seven remaining pages — Built-in
  Providers, Addons, About, Backup & Data, Connect, Debrid & Cloud Streaming
  and Video Player & Engine — now follow the app language, in all four
  languages. 237 new keys, 369 in all. Two things stay untranslated on
  purpose: the debrid provider ids (`Real-Debrid`, `TorBox`, …) are persisted
  storage keys compared with `==`, and the platform names (`Android`,
  `Windows`, …) are product names.
- **Keyboard Shortcuts page translated (#68)**: the action column and the
  page title now follow the app language. The key column (`Space`, `J`,
  `Esc`) stays as-is — those are the physical keys.
- **Spelling unified to American English** across code, comments, docs and
  commit history (`color`, `behavior`, `catalog`, `center`, `gray`,
  `labeled`, `canceled`, `initialize`, `normalize`, `optimize`, `analyze`,
  `program`). The repo mixed both variants, which made searches miss half
  the hits. External API spellings are untouched — AniList's `favourites`
  field and its `CANCELLED` status stay as the API spells them.

### Fixed
- **Text scale (#69)**: all eight settings pages no longer overflow at 3×
  text scale. Four of them did: the Keyboard Shortcuts key chip now scales
  down, the Built-in Providers header scrolls with its list instead of being
  pinned above it, the Connect card's name and status badge wrap, and the
  Video Player page's engine title, preset badges, decoder-chain line and two
  dropdowns all flex.
- **Cast**: the "cannot cast this source" message named the wrong reason. It
  said torrents never cast, but the rule that decides this tests the *host*:
  a torrent that resolves through a debrid or a torrent server on another
  machine casts fine. What a receiver cannot reach is this device's own
  loopback, which is where TorrServer serves from. The message now says that.
- **Text scale (#69)**: the player's transport bar and sources panel no
  longer overflow at 3× text scale. The seek bar's time labels scale down
  instead of pushing past the row, the sources panel's episode badge does the
  same, and its per-source badge row wraps to a second line rather than
  running off the edge.
- **Flatpak**: the PC could suspend mid-playback — the sleep inhibitor D-Bus
  call (`org.freedesktop.ScreenSaver`) was silently blocked by the sandbox.
  Added `--talk-name=org.freedesktop.ScreenSaver` and
  `--talk-name=org.freedesktop.portal.Desktop` to the manifest.
- **Player (desktop)**: keyboard shortcuts (J/L/C/A/S/R/F/space) died after a
  suspend/lock-screen cycle; the player's focus node is now re-armed when the
  app resumes.

### Changed
- **Catalog loading**: a catalog whose first fetch fails (cold DNS, slow host)
  is retried once before the page renders, instead of silently dropping its
  row until a manual refresh — "the list is sometimes short" was that.
- **Sleep timer menu**: presets as full-width rows that show when playback
  will pause, plus a custom -/+ stepper (5–240 min); editing does not arm the
  timer until the check button is pressed. A discrete preset slider
  (15–240 min) sits above the rows for one-drag selection.
- **Playback speed**: the seven-row list became a discrete slider over the
  same points plus 0.25×, which the list omitted.
- **TV / D-pad**: the speed and sleep-timer sliders are now drivable with a
  remote's arrow keys (one step per press, with the same focus ring the
  buttons use), instead of being pointer-only.
- **Subtitle appearance**: removed the redundant Custom preset chip from the
  presets bar (the customizer's tabs already cover it) and bounded the font
  dropdown's menu height to the panel.
- **Subtitles**: regional labels group under their parent language
  ("Spanish (latam)" joins "Spanish"), names are capitalized, mpv's
  signs-only `SPL` track is no longer offered as a language, titles drop the
  media name and the provider's own noise, and the same subtitle arriving
  from several scrapers is collapsed to one choice. The default pick still
  follows the audio language.

## [1.8.3+36] - 2026-09-17

The player's controls reorganised around one button each, the subtitle
picker made legible, and a Documentaries shelf. Most of this came from
using the player rather than from a report: the sleep timer that did
nothing, the flags that pointed at the wrong countries, and the aspect
menu holding a subtitle control were all found by opening the menus and
reading what they actually said.

### Added
- **A Documentaries row on the Films page.** Documentaries are films -- the
  addon catalogs carry them under the same type -- but a viewer looking for
  one is rarely browsing; they want the shelf. Sourced by genre rather than
  by a catalog of its own, so it works with whatever addons are installed
  and costs no new catalog. It only appears when the installed addons
  actually carry Documentary titles, and loads silently: an addon without
  the genre costs the page nothing.

### Changed
- **"Movies" is now "Films".** The section carries documentaries, and
  "Movies" was the name that made that feel like a misfile. "Films" is
  broader without being vaguer. The other translations already said the
  right thing in their own languages (Películas, أفلام, Filmes) and are
  untouched. Live TV's portal browser still says "Movies" for its VOD tab:
  that is the portal's own category name, not ours to rename.
- **Keyboard shortcuts for the player's menus: C subtitles, A audio,
  S speed, R aspect ratio** -- VLC's letters, for the four things a keyboard
  user reaches for mid-scene. They open the same panels the transport-bar
  buttons do, and Esc closes whichever is open.

### Fixed
- **The shortcuts page said J/L seek ±5 seconds; they seek ±10.** The code
  has matched the double-tap zones since the one-amount-per-control work --
  that was the whole point of it -- and the reference page was never
  updated, so it documented the old amount next to a player that no longer
  had it. The page also now lists the arrow keys' volume control, which
  worked and was never written down.

### Changed
- **Subtitle Appearance is inside the subtitle panel now, not a pop-up.**
  This reverses the deliberate decision recorded under 1.8.2, and the reason
  it reverses is that the pop-up hid the thing it exists to style: a
  full-screen modal over the video covers the subtitles, so every change was
  judged from the preview box alone. In the panel the video stays visible
  behind the glass, and the tune button toggles the view in place.
- **Embedded subtitle tracks no longer offer "SPL", "MON", "ZHC" or "ZHT"
  as languages.** Those are mpv's own track tags, not languages: SPL is a
  signs-and-songs track, MON is the same language as the audio, and ZHC/ZHT
  are Chinese simplified and traditional. They rendered raw, so a file's
  subtitle list read as noise. They are named now, and the Chinese family
  groups under one heading instead of four.
- **The subtitle picker groups by canonical language.** The same language
  arriving from different providers under different labels -- "Chinese",
  "Chinese (Simplified)", mpv's `zhc` -- used to be separate groups, which
  made the language bar a row of near-duplicates.
- **The player's menus sit closer to the transport bar.** The clearance was
  sized to clear the whole bar, which left the card floating a hand's width
  above the buttons it belongs to. It clears the bar's top padding now, so
  the menu reads as attached to the row rather than hovering over it.
- **The settings button is gone; the sleep timer is a button of its own.**
  After the controls grew their own buttons, the gear held only the subtitle
  entry and the sleep timer -- and a menu for one control is worse than a
  button for it. The transport bar now reads speed, audio, subtitles, sleep
  timer, aspect ratio. The subtitle button opens the full panel, whose first
  pill is Off, so the toggle it used to be is still there one tap further;
  an Auto pill joins it, keeping the one-tap best-track behavior the old
  toggle had. The moon button's badge counts down while the timer runs.
- **The sleep timer actually works now.** The chips existed for several
  releases -- in the speed menu, then in the settings menu -- and choosing
  one changed a highlight and nothing else: there was no timer behind them.
  `SleepTimerService` is the timer, pausing playback when the countdown ends;
  the last choice replaces a running one, and Off cancels.
- **The transport bar has a button per control: speed, audio, subtitles,
  settings, aspect ratio -- in that order.** They used to be two buttons
  (subtitles and a gear that held everything else), which made the gear a
  menu of menus: three taps to reach a speed that was one tap away on
  YouTube. Each of these is a choice a viewer makes mid-scene, so each gets
  its own button.
- **The gear menu holds only what has no button: the subtitle entry and the
  sleep timer.** The sleep timer moved here from the bottom of the speed
  menu, which was the one place a viewer winding down for the night would
  not look for it.
- **The player's subtitle and picture controls are reorganised.** Six things
  were wrong with them, and all six came from the same cause: controls
  grouped by where there was space rather than by what they belong to.
  - **Subtitle size was in the Aspect Ratio menu.** A "Subtitle Size Scale"
    slider sat under the aspect list, where nobody looking for subtitle
    settings would find it. It is gone from there; the same control already
    existed in Subtitle Appearance as "Scale Multiplier", so the aspect menu
    was a second copy of it, not a missing one.
  - **The language flags were wrong.** Both the subtitle and audio menus
    matched ISO code substrings against what is actually a display name, so
    "Spanish" drew the globe (no `es`/`spa` substring in it) and "Chinese"
    drew the Indian flag (`hi` is inside `Chinese`). The two menus also
    disagreed with each other on the same language. One shared
    `languageFlag` keyed on the exact name replaces both.
  - **"Speech Text Sync" is gone.** It adjusted subtitle timing by following
    the spoken dialogue, which the name did not say and almost nobody
    understood. The plain delay control beside it already answers "the
    subtitles are out of sync", which is the only thing a viewer is trying
    to fix. The overlay it opened is still in the code, unwired, in case it
    comes back under a name that explains itself.
  - **Aspect Ratio now has an Original option, and says so.** The first
    entry was "Fit to screen (Contain)", which read as a mode rather than an
    answer to "show it the way it was shot". It is now "Original (keeps the
    source shape)" -- which is what `BoxFit.contain` does. Two forced ratios
    join it, 16:9 and 4:3, for the shapes old content is most often trapped
    in; a 4:3 film mis-tagged as 16:9 shows squeezed in Original and
    forcing the ratio re-squares it.
  - **Menus no longer cover the transport bar's buttons on a phone.** The
    popover's bottom clearance was 76px against a bar that measures about
    126px, so the subtitle and settings icons were hidden behind the open
    menu and the first tap "missed" what the user could see. It is sized
    from the bar now.
  - **Subtitle Appearance stays a pop-up, deliberately.** Inlining it into
    the subtitle panel was considered and rejected: the editor is a
    five-tab, live-preview surface that needs most of the screen, and
    shrinking it into a corner of the track list would have made it worse
    to use in order to make it one tap closer. It is one tap from the
    subtitle panel's own header, which is where it was.

### Fixed
- **Subtitle rows said the provider instead of the language, and the HI/CC
  and Forced filters never matched anything.** Two bugs with one root.
  OpenSubtitles titled every track "OpenSubtitles #3" -- the provider name
  was already on the row as its own badge, so the title repeated it and
  gave the user nothing to choose between five rows by. It uses the addon's
  own id now, or a plain number when the addon sends none. And the HI/CC
  and Forced badges were derived by sniffing the title for words like "SDH"
  and "forced" at render time, while the one provider that marks
  hearing-impaired tracks directly (Wyzie) put its flag in a separate field
  the model never carried -- so the badges were blank for exactly the
  tracks that were marked. `SubtitleVariant` now carries `isHearingImpaired`
  and `isForced`, set from the provider's flag where it sends one and from
  a word-boundary match on the title where it does not. The word boundary
  matters: the old substring match read "White.House" and "Childhood" as
  hearing-impaired, because both contain "hi". The language also shows as
  words on each row now, not only as a small flag -- "which of these is
  the English one" is the question the list exists to answer.
- **Two `return` statements that skipped their own `catch`.** Both were
  `return <Future>` inside a `try` without `await`, which completes the try
  block before the future settles — so the `catch` below could never see
  anything the call raised. In `StreamHealthChecker._probeUrl` that is the
  redirect chain: a throw from a redirect escaped past the handler that
  exists to turn a failed probe into `false`. In `TraktService.
  refreshAccessToken` it is the `on StateError`, which was unreachable for
  exactly the case it was written for.

  Neither was live — `_probeUrl`'s recursion and `_refreshAccessTokenScoped`
  both handle their own errors, so nothing escaped today. They were one edit
  away from mattering, and the analyzer had been reporting both since the
  local SDK moved ahead of CI's pinned 3.44.0. `flutter analyze
  --fatal-infos` is now genuinely zero rather than zero-except-these-two.
- **Leaving a watch screen mid-search left every scraper running.** The
  source search kept issuing HTTP requests into a controller nobody was
  reading — forty-odd of them, for a screen the user had already left.
  `ScraperManager.scrapeAll` has had the teardown all along: its
  `controller.onCancel` cancels every subscription and deadline. What was
  missing was the link above it — `StreamService.fetchStreams` wrapped that
  stream in a *second* controller with no `onCancel` of its own, so
  canceling the outer consumer never reached the manager. Both
  `fetchStreams` and `fetchStreamsForTargetAddon` now forward the cancel.
  Found by reading upstream `39b736f`, whose commit message claims to fix
  exactly this; the fix is ours, because the cause was in code upstream
  does not share.
- **Five more text-scale overflows (#69)**, on the player's chrome and the
  browse row header. All five are the same shape: a fixed-height `Container`
  with a bare `Row` inside it, where one half grows with text scale and the
  other does not. The settings menu (436px — the label was `Expanded` and the
  value beside it was not), the aspect menu (685px), its subtitle-scale row
  (590px), and `SectionHeader`'s "See All" (8.7px — small, and the heading
  above every row on every browse page).
- **Three more on the settings hub (#69)** — 286px, 64px and 32px, on the
  category tiles. The screen a user who needs large text is most likely to
  be on.

  The fixed heights became minimums rather than being clamped. `PlayerMenuAnchor`
  already bounds and scrolls its card, and the settings page scrolls, so the
  box can genuinely grow; clamping would only make the text smaller for no
  reason.

### Added
- **The details pages and the player's gear menu are translated (#68).** 26
  keys — the Play button in all four of its forms, the section headings, Read
  more / Show less, the anime SUB/DUB toggle, and the player's four menu rows
  — in Spanish, Arabic and Portuguese-BR. Two carry placeholders, the first in
  this app: `"Play Ep {number}"` is a sentence whose word order differs per
  language, so the number cannot be concatenated outside the translation.

### Internal
- **The release workflow is off the retired Node 20 runtime.**
  `softprops/action-gh-release` was on `v2`, which targets Node 20; GitHub
  is retiring that runtime and forces such actions onto Node 24 with a
  warning. Nothing failed and nothing went red — the warning was the only
  signal, and it scrolled past in a green build, which is how it survived
  the v1.8.2 release. Now on `v3`, a runtime bump with no input or output
  changes. A test fails if any action in either workflow drops below the
  first major that moved to Node 24, and fails again if a *new* action is
  added that the list does not cover — so the guard cannot pass by not
  looking.
- **The l10n guard now compares whole files.** The Library's own check named
  six keys by hand, which was right when there were six and does not scale to
  120. The new one asserts every key in `app_en.arb` exists in each
  translation and vice versa. A missing key does not crash — `gen-l10n`
  silently emits the English string — so the failure mode it prevents is a
  screen that is quietly untranslated while everything looks fine.
- **Upstream reviewed through `39b736f`** (2026-09-16), the largest commit
  since the fork. Its CloudStream extension system is not taken — a whole
  plugin ecosystem, and a feature rather than a fix. The scraper-lifecycle
  bug above is what came out of reading it.

## [1.8.2+35] - 2026-09-16

The release that finished what 1.8.1 started on text scale, took the
translation work one screen further, and confirmed the Flatpak audio fix on
real hardware. No new features; three of the four items here are things that
were already shipped and are now either finished or verified.

### Fixed
- **Three catalog cards overflowed their grid cell at a large text scale
  (#69).** `MovieCard`, `AnimeCard` and `IptvChannelCard` are hosted in a
  `SliverGridDelegateWithFixedCrossAxisCount` cell — a hard box whose size
  comes from `childAspectRatio`, not from its own text — so at 3x the
  metadata row painted out the side of the cell: 273px for `MovieCard`,
  76px for `AnimeCard`, 91px for `IptvChannelCard`. The first two were a
  bare `Row` with no flex on any child; the third was the same, plus a
  short-code badge whose text wrapped past its fixed box. Each card now
  clamps its text scale and flexes the row, so the clamp keeps it legible
  at ordinary settings and the flex holds at any scale.
- **Three more on the details pages (#69)**, found by probing them the same
  way: the Play button (174px — a bare `Row` of icon and label, the same
  shape as the cards above), the section heading (195px — `Flexible` was on
  the heading but not on the count beside it), and the Episodes control
  strip (516px — SUB/DUB, the jump input and the batch dropdown, all
  fixed-height boxes whose labels grow). The strip wraps now rather than
  clamping: it already sat in a `Wrap`, so the box could genuinely grow, and
  clamping it to 1.3 still left 179px.

### Added
- **`ClampedTextScale`**, naming the `MediaQuery` incantation that had been
  hand-rolled in six places. It documents that capping is a compromise — a
  viewer who asked for 3x does not get 3x — and points at `CollectionCard`,
  which reserves label space from `MediaQuery.textScalerOf` instead, as the
  better answer where the box can genuinely grow. Defaults to 1.3, the
  ceiling the app had already settled on.
- **The Library is translated (#68).** Its three tabs, the three built-in
  shelf cards, their empty states, the type filter chips, the sort menu and
  the collection dialogs — 34 keys, in Spanish, Arabic and Portuguese-BR.
  That takes #68 from ~30 to ~64 of an estimated 500-800 strings.
- **`context.l10n`**, a one-line extension that falls back to English when no
  localization delegate is in scope. The generated `AppLocalizations.of`
  force-unwraps and *throws* instead of returning null (`nullable-getter:
  false` in `l10n.yaml`), which is right for a real screen and wrong for the
  many existing widget tests that pump a bare `MaterialApp`. Without this,
  translating a widget broke every test that rendered it.

### Confirmed
- **Flatpak audio (#70) works on real speakers.** 1.8.1 added
  `--socket=pulseaudio` to the sandbox's `finish-args` and shipped it
  unverified, because a missing sandbox permission cannot be reproduced by
  a test — it is a property of the manifest, not the code. A Flatpak build
  with the fixed manifest has now been run and plays sound, which is the
  only thing that could have settled it.

### Not yet verified

- **#69** covers 10 of the ~68 files in `lib/` with a fixed `height:`. A
  large system accessibility text size can still overflow any of the
  other ~58 — unrelated to, and unchanged by, the new in-app control.
- **#68** covers roughly 64 of an estimated 500-800 strings. No RTL layout
  audit was done for Arabic beyond Flutter's automatic `Directionality`.
  The display/canonical title split the roadmap says must come before
  translating catalog content is still only decided, not built.
- **#71** is verified by `flutter analyze` and `flutter test` only — not
  yet checked visually in a running window.

Also still outstanding from 1.7.0: the **Cast fix has never been confirmed
against a receiver** (#28).

## [1.8.1+34] - 2026-09-16

A packaging fix, a settings-page cleanup, and the first real steps on two
roadmap items — text-scale accessibility and translation — that turned out
much larger once started. Both ship here in a real, working, *partial*
form, scoped down on purpose rather than held back for a future release
that would have kept them at zero. See **Not yet verified** for exactly
where each stops.

Collections (#67), shipped device-untested in 1.8.0, has since been
confirmed working on a phone.

### Fixed
- **Audio was silent under Flatpak (#70).** The sandbox's `finish-args`
  granted `--socket=wayland`, `--socket=fallback-x11` and `--device=dri`,
  but never `--socket=pulseaudio` — so media_kit's libmpv backend had no
  path to the host audio server, while video played fine through the
  sockets that were granted. Consistent across every reported device,
  since a missing sandbox permission doesn't vary by hardware.
- **Subtitle appearance settings opened as a pop-up (#71).** Settings →
  Video Player's "Customize" button showed the subtitle style editor via
  `showDialog`, a modal dropped on top of the page rather than part of it.
  It now expands inline in place; the same editor still floats as an
  overlay when opened mid-playback, where that's the right call.
- **Four high-traffic text-scale overflows (#69).** `AdaptiveNavShell`'s
  mobile bottom tab bar, `PillTabRow` (hosted in `LibraryTabs`'
  `AppBar.bottom`, fixed at 52), `SidebarLogo`'s wordmark (inside `TopBar`'s
  fixed 56), and the details page's per-credit role label all clamp their
  text scale now instead of overflowing the fixed box they sit in.

### Added
- **An in-app text zoom** (Appearance & Interface → App Text Size, #69),
  capped at 1.3x — the same ceiling every fix above was individually
  verified against — and multiplying on top of the system's own
  accessibility text size rather than replacing it.
- **Translation infrastructure, with Spanish, Arabic and Portuguese
  (Brazil)** (#68): `flutter_localizations` + `intl` + `lib/l10n/*.arb`,
  picked in Appearance & Interface → App Language. English is offered
  there too, explicitly, not just as the implicit default. Hub navigation,
  the Settings hub page, and the Appearance & Interface page itself are
  translated — roughly 30 of an estimated 500-800 user-facing strings.

### Not yet verified

- **#70** explains the symptom exactly, but no Flatpak build with the
  fixed manifest has been run against real speakers yet. *(Confirmed in
  1.8.2.)*
- **#71** is verified by `flutter analyze` and `flutter test` only — not
  yet checked visually in a running window.
- **#69** covers 4 of the ~68 files in `lib/` with a fixed `height:`. A
  large system accessibility text size can still overflow any of the
  other ~64 — unrelated to, and unchanged by, the new in-app control.
- **#68** covers roughly 30 of an estimated 500-800 strings. No RTL layout
  audit was done for Arabic beyond Flutter's automatic `Directionality`.
  The display/canonical title split the roadmap says must come before
  translating catalog content is still only decided, not built.

Also still outstanding from 1.7.0: the **Cast fix has never been confirmed
against a receiver** (#28).

## [1.8.0+33] - 2026-09-15

The collections release. Everything here is covered by the test suite and
nothing in it has been used on a phone yet — see **Not yet verified** at the
end of this entry before treating it as done.

### Added
- **Collections.** A user-named list of titles, with create, read, rename,
  delete and reorder, and a stored shape that survives a corrupt blob. Movies,
  series and anime share one collection — the split by section would have made
  "a list of things I want to watch this weekend" impossible to express, which
  is the main thing anyone wants a list for.

  Deliberately *not* another library state. Liked / Watchlist / Watched live on
  `MyListService`: one flat list, one state per title, Watchlist and Watched
  mutually exclusive, all three synced to Trakt and Simkl — where "watched" is
  scrobble history rather than a list, so removing from it means "mark
  un-watched". A collection has none of those constraints: any number of them,
  a title can be in many at once, the order is the user's, and nothing syncs
  upstream. Called *collection* rather than *playlist* because Live TV already
  has playlists — `M3uPlaylist` is a source of channels, and the portals screen
  has an "M3U Playlists" tab.

  Entries reuse `MyListItem` rather than a parallel type. It already resolves
  identity across four providers — `uniqueKey` prefers IMDb, then TMDB, then
  Trakt, then Simkl, then a cleaned title+year — so the same film added from a
  Trakt payload and from a TMDB catalog lands once, not twice. Storage is one
  SharedPreferences key, which `BackupService` already exports and restores
  without needing to know collections exist.

- **A fourth library action on every details page.** It opens a picker rather
  than toggling, because a title can be in any number of collections at once;
  it still lights up when the title is filed somewhere, so the row answers "is
  this saved anywhere?" without being tapped. Creating is offered in the picker
  as well as the Library: the moment you most want a new collection is while
  holding a title that fits none of the existing ones, and "+ New collection"
  there creates and files in one step. Renaming and deleting are not, and
  belong where the collection is the subject of the screen.

### Changed
- **The Library is Collections / Continue / Downloads.** It was four tabs, one
  per library state, which stopped scaling the moment collections arrived — six
  collections would have meant ten tabs. Liked, Watchlist and Watched are now
  square cards beside the user's own collections, the arrangement Spotify and
  YouTube Music use, and the tab bar holds the three genuinely different things
  you can want from a Library. Square rather than poster-shaped on purpose: a
  2:3 tile is a *title* everywhere else in the app, so the square is what says
  "this opens a list".

  Opening any card lands on one shared shelf screen, because from the user's
  side both kinds are the same thing: a grid of titles with a name on it. Two
  things differ underneath. A built-in state has no inherent order, so it keeps
  the type filter and sort the tabs always had; a collection's order *is* the
  user's, so it gets a reorder mode instead of a sort that would throw that
  away. And removing from a state is a library edit that syncs upstream, while
  removing from a collection only leaves that one list.

- **Continue is a Library tab again**, after being dropped on 2026-09-13 for
  duplicating the home row. With the states gone from the tab bar there is
  room, and the home row only holds what fits on screen — the Library is where
  you look for the thing that has scrolled off it.

- **Play and the library actions are stacked on phones.** The details pages put
  them on one row, which squeezed the primary action to make room for the
  secondary ones and left nothing for a fourth. Play now takes its own
  full-width line and the four actions share the one below it: roughly 72px
  each on a 360px phone, past the 48px tap target and *larger* than the
  clustered icons they replace. It also converges the two layouts — desktop
  already stacked them in its poster column.

### Not yet verified

743 tests pass, and they are the reason to believe the logic is right. They
are not a device. Nothing below has been exercised on real hardware, and each
is a thing a widget test cannot answer:

- **Does a collection survive a restart?** The round trip is unit-tested
  against a mocked `SharedPreferences`; the real plugin writing to real
  storage is not.
- **Does backup and restore carry collections?** Believed yes, and for free:
  `BackupService` dumps every preferences key, so it needs no knowledge of
  this feature. Believed is not the same as seen.
- **Drag-to-reorder**, under a real finger rather than a synthesised index.
  The off-by-one in `ReorderableListView`'s destination index is tested
  directly, which is the part most likely to be wrong — but not the gesture.
- **The four action buttons on a real phone.** Tested at 320px and at the
  default text scale. A device with large system text is a different sum.
- **The picker sheet with the keyboard open.** It offsets by
  `MediaQuery.viewInsetsOf`, which no test raises a keyboard against.

Also still outstanding from 1.7.0: the **Cast fix has never been confirmed
against a receiver** (#28). It explains the reported symptom exactly, and
that is all anyone can say about it so far.

## [1.7.0+32] - 2026-09-15

The release where the roadmap's **Open** section became empty. Four bugs
turned up while clearing it that were nobody's assignment — three of them
found by tests written for something else.

### Fixed
- **Cast never searched for devices.** The picker subscribed to the plugin's
  device stream, but nothing ever asked the plugin to *scan*, so the stream
  had no producer and the sheet sat on "Looking for Cast devices on your
  network..." forever. The plugin's README says discovery starts automatically
  once initialized; its source says otherwise on both platforms. On Android
  the native `onAttachedToEngine` only wires up the method channel — the
  `MediaRouter.addCallback` that actually scans lives solely inside the native
  `startDiscovery`, reachable only from Dart. iOS is the same through
  `GCKDiscoveryManager`, and adds a second trap: the SDK option
  `startDiscoveryAfterFirstTapOnCastButton` defaults to true, so it waits for
  a tap on its *own* native Cast button, and this app draws its own. Discovery
  now starts when the picker opens and stops when it closes, since scanning
  holds the radio awake
- **A failed keychain delete left the credential behind.**
  `SecureValueStore.delete` removed the plaintext copy whether or not the
  secure delete succeeded, so a failure left the credential in the keychain
  while the app behaved as though it were gone — and `read` would hand it back
- **"See all" was pushed off the edge of the Continue Watching header.** The
  header laid its accent bar, title, count and button out flat with a
  `Spacer`, and the title was inflexible, so it took its natural width and the
  button went past the right edge: 88px of overflow at 420px wide with any
  watch history, and more for a longer title than the English one, which the
  Arabic heading already is. The title and count now share what the button
  leaves, and the title ellipsizes rather than shoving
- **Live TV's portal chips overflowed on a narrow phone.** Two chips do not
  fit a 320px screen side by side. The settings page had wrapped its chip rows
  all along; the portals modal used a bare `Row` — so the duplication below
  meant one copy was correct and the wrong one was the one people open from
  the Live TV screen itself
- **Four more errors that were being lost in silence** now say so: a failed
  anime-watchlist save (the app kept showing a list that would be gone at
  restart), a source search that died wholesale (indistinguishable from a
  title with no sources), and two updater preferences that sprang back at next
  launch

### Changed
- **The hero carousel now fills the screen down to Continue Watching.** It was
  sized as a fraction of the *screen* — 0.52 of it on desktop, capped at 560px
  — which left the row below it sharing the fold with the start of two more,
  and on a phone was measured against a height the page never had: the top
  bar, the section chips and the bottom tab bar all come off it first. The
  hero is sized from the viewport it was actually given, minus the exact
  height of the band beneath it, so the hero and the Continue Watching row
  come to one screen. No breakpoint table: the size is arithmetic on the
  window, clamped only at the ends so a half-height window still shows real
  artwork and a very tall one does not get a poster the height of a door
- **Live TV's chip styling lives in one place.** A `ChoiceChip` had been
  styled by hand at ten call sites across three files, every copy agreeing on
  the same six properties, plus the *Default Starting Tab* row written out
  twice. Now `SettingChoiceChip` and `DefaultPortalTabPicker` — the 45
  duplicated windows the audit measured are 0, and the three pages lose 172
  lines
- **Every empty `catch` block now says why it is empty.** All 126 read one at
  a time: five were losing something a user would notice and now report it,
  and the other 121 carry the reason they swallow — a scraper whose site
  changed while 47 others still run, a metadata fallback that was always a
  second guess, tidy-up of a file being deleted anyway

### Internal
- **The scrapers are no longer untested in CI.** Six parse extractions, all
  following one rule: cover it offline when the input is a *format* somebody
  defined and many implementations honour, not when it is one website's markup
  on one day. Subtitle providers (the Stremio addon body, Wyzie's array),
  Xtream's `player_api.php`, VOE's payload cipher and Luna's RSC reader. VOE's
  is reversible, so its test builds a payload with the inverse and checks the
  round trip rather than pinning a capture that goes stale
- **Test count 602 → 680.** New guards stop the fixed things coming back: a
  bare `catch (_) {}` with no reason, an eleventh hand-styled chip, a Cast
  picker that forgets to start discovery
- Roadmap rewritten. **Open is empty**; what remains needs a Cast receiver

## [1.6.3+31] - 2026-09-14

Two bugs you could see, one you could not, and the first build that ships a
working TMDB key.

### Fixed
- **The bars kept the old theme until you navigated away.** Switching theme
  recoloured the app but left the top bar, the section bar and the phone's
  bottom tab bar on the previous one, until something unrelated made them
  redraw. `main.dart` hands the app down as `const HubPage()`, and a const
  widget with no arguments is a single shared instance — so on the next build
  Flutter finds the identical widget in the same slot, reuses it, and never
  calls `build`. These bars paint from `AppColors`, which reads globals rather
  than an inherited widget, so nothing else marked them dirty either. They
  subscribe to the theme now, along with every other widget that paints from
  those tokens — 93 in all
- **Movies and Anime showed an error card on a first run, and a reload fixed
  it.** Installing the default addon on first launch was a single network
  attempt whose failure was caught and discarded; the app then carried on with
  no addons at all, so every catalog had nothing to query for the rest of
  the session. A cold start is exactly when that call is most likely to
  fail — DNS cold, connection pool empty, the radio still waking. It is
  retried now when a page next asks for a catalog, so recovering costs a
  pull to refresh rather than a restart
- **Export and Import had each other's icons.** Export carried the upload
  arrow and Import the download arrow
- **Cast on a torrent source now says what does work.** It could never reach a
  receiver — the stream is served from your own device, and a receiver told to
  fetch `127.0.0.1` fetches itself — but "pick a different source" read as
  "try them all". It names direct and debrid sources, and offers the picker

### Added
- **Cast photos and character names work out of the box.** This is the first
  release whose binaries carry a TMDB key. Every published build until now
  shipped without one, which is why cast rows have always been bare names. The
  key that used to sit in the source had been found and revoked, as a key in a
  public repository will be; it now comes from a repository secret, where
  rotating it does not mean shipping a new binary

### Internal
- Five committed TMDB keys removed — the two named constants and three more
  written into the middle of a URL, where a scan for a 32-character literal
  never saw them. All read one setting, so a key you paste in Settings now
  serves the scrapers too
- Offline tests for three things previously reachable only over the network:
  subtitle archive and encoding handling, the IPTV playlist parser, and Movy's
  stream cipher
- macOS ships one universal build instead of two identical ones labeled Intel
  and Apple Silicon, with a check that fails the build if it stops being
  universal. Releases are about six minutes shorter

## [1.6.2+30] - 2026-09-14

The light-mode corners 1.6.1 could not reach, and the details page that was
blocking most of them.

### Fixed
- **"Could not load movies" on the Anime page.** The error card defaulted to
  that heading and no page ever replaced it, so Anime and Live TV both told
  you your *films* had failed while the line underneath correctly named the
  anime catalog. Each page now says what it was actually loading
- **Live TV and Settings stayed black in light mode.** Both read the
  palette's dark surface directly instead of resolving it against the active
  brightness — along with Live TV's hero gradients, the ambient background
  behind Settings and the video-player settings, and Anime search
- **Genre chips came out black on a photograph.** The same chip appears on a
  hero's artwork and on a details page's background, so neither fixed white
  nor theme ink is right for both. They now know which one they are in
- **"Cast & Crew", "Similar Content" and the like / watchlist / watched
  buttons read black on a dark photo.** The details page's backdrop was a
  pinned layer filling the screen at every scroll position, so everything on
  the page sat on artwork no matter how far down you were. The backdrop is
  now as tall as the hero: the hero and its buttons stay white over the
  photograph, and the page below it follows the theme

### Internal
- The analyzer's info list went from 133 to zero and infos are now fatal.
  One real warning had already gone unread inside that list of 133 and put
  `main` red
- The PR checks run as three parallel jobs, so analyze and test no longer
  wait behind the Android toolchain they never use, and one round reports
  every failure rather than stopping at the first

## [1.6.1+29] - 2026-09-14

Light mode, finished. 1.6.0 shipped the color system; this is the chrome it
did not reach.

### Fixed
- **The bars were black-on-black in light mode.** The top bar, the section
  switcher on desktop and the tab bar at the bottom of a phone each carried
  their own dark color, while the wordmark and icons on them had already
  moved to the theme. Choosing Light turned the glyphs dark and left the bars
  dark. They are light now, with dark icons and lettering, and take their
  tint from whichever of the eight palettes you picked
- **Live TV's header** sits on a shade over the channel artwork rather than
  on the page, so the same change would have turned *its* text black on a
  photograph. Those controls now know they are over artwork and stay white —
  in both themes, which is what they were always meant to do
- **Seven of the eight themes only half-applied.** The accent color was
  written out by hand in 156 places, so choosing anything other than the
  default violet recoloured part of the app and left the rest violet —
  including the selected section in the switcher, which is the one thing on
  screen whose job is to show you where you are
- Some screens kept whichever theme was active the first time you opened
  them, and ignored later changes — About, the update dialog, the P2P
  warning, and the player's accent
- A few remaining surfaces in light mode: the sheet behind anime sources,
  and the dropdowns in the video-player settings

## [1.6.0+28] - 2026-09-14

Maintenance release. Light mode became real, the player's menus stopped
running off the screen, and the audit that ran through this cycle is
recorded in [docs/ROADMAP.md](docs/ROADMAP.md).

### Added
- **Light mode, actually painted.** The System / Light / Dark switch in
  **Appearance & Interface** was wired up in 1.5.8 with nothing behind it:
  the app's roughly 1000 white text colors and 100 dark surface hexes
  ignored the theme, so choosing Light gave you one correct settings page
  and a dark everything else. They now resolve against the active theme, and
  the eight accent palettes stay distinguishable in light the way they are in
  dark. A dark build is unchanged — the dark values are the same colors
  that were there before, to the byte
- **A Google Cast button in the Movies, Series and Anime player.** Live TV
  had one; the main player had lost it
- **Audio track first** in the player's settings menu, ahead of subtitles and
  speed — it is the row most often wanted
- **Backups save through the system file picker.** Choosing a folder by
  typing a path does not work on Android, where the path you can see is
  usually not a path you can write to. Export and import now open the
  platform's own picker
- **Your own Simkl client ID.** Connect used to fail with no explanation when
  the bundled ID was rate-limited or revoked; the card now takes an ID of
  your own and says which of the four things went wrong when it cannot
  connect
- **Character names on the cast row.** Every actor was labeled "Cast"

### Changed
- **The Live TV player is now the main player with fewer parts**, rather than
  a second player that resembled it. Same gear, same popover placement, same
  menus; what it legitimately lacks — seeking, a seek bar, playback speed — a
  live feed has no use for
- **The player's menus fit the screen.** The speed menu could run off the top
  on a short device in landscape. Popovers are now sized to the space
  available and have no close button: tap away, or press back
- **Settings scroll from anywhere in the window on desktop.** The scrollbar
  sat beside the content column in the middle of the window rather than at
  its edge, and the wheel only worked over that column
- Every `package:http` request now carries a timeout. 54 of them had none, so
  a debrid provider or metadata addon that accepted a connection and then
  went quiet would hang whatever screen was waiting on it, with the spinner
  up and no error

### Fixed
- One scraper that never finished no longer holds the whole source search
  open — each gets 30 seconds, then the search moves on without it
- Subtitle language names are no longer wrong on two of the three providers.
  They each carried their own table; one had 63 languages, another the same
  63, and the union was 114
- Resuming from Continue Watching opens the player over the whole app rather
  than inside the current tab, so leaving it returns you where you were

## [1.5.8+27] - 2026-09-13

### Added
- **One search** for Movies, Series and Anime. The search icon used to mean
  different things depending on where you pressed it — an addon search on
  Movies and Series, a separate AniList page on Anime — and silently
  narrowed results to whichever section you were standing in. One page now
  answers for all three, with the section you came from pre-selected as a
  chip you can clear rather than a hidden mode. Anime's own filters (genre,
  season, format) are still there, reached through the page instead of
  beside it, and they carry your query across. Live TV keeps its own search:
  it matches a portal's streams by keyword rather than searching a title
  catalog
- **Live TV channels you can make yourself.** If a portal carries something
  the built-in catalog has no entry for, save it from the player's top bar
  and it becomes a real channel — likeable, listed, and found again by name
  across portals, because a channel tile is a saved search rather than a
  bookmark. They get their own row on the Live TV page, and can be deleted
  from the channel sheet
- **Cast in the Live TV player.** Movies, Series and Anime have had a cast
  button all along; Live TV had none
- **±30s skip** on the buttons either side of play, with a flash on the side
  of the screen that moved — including when the controls are hidden, which
  is exactly when a double-tap needs confirming. Repeat taps count up, so
  three quick skips read "30 seconds" rather than flashing "10" three times
- A **film-strip accent** under the wordmark, drawn in the theme's color
- **History**: the Continue Watching row now has a *See all* opening the full
  log of what you have watched, newest first. That log was already being
  recorded and saved to disk — every episode, up to 100 — with nothing in
  the app rendering it; the only reader was the player, looking up one entry
  to resume a position. It hangs off the row rather than living in Library,
  because Library's tabs mean what you chose to keep and this is a record of
  what happened
- Liked Live TV channels now have a **Liked** row at the top of the Live TV
  page, newest first. They only ever appeared in Library before, which is
  the wrong place for them: you open Library to manage what you saved, and
  Live TV to actually watch something

### Changed
- **The subtitle button answers instead of asking.** With nothing selected
  yet it used to open the track picker — the one thing a CC toggle should
  never do. It now turns on the subtitle **matching the audio you are
  listening to**, so the words on screen are the words in the room, falling
  back to the file's own default, then English, then whatever exists.
  Matching is by language rather than by spelling, since an `eng` audio
  track beside an `English` subtitle is the common case. The full picker is
  still one tap away behind the gear
- **One seek amount per control.** A phone was showing three ways to skip
  and two of them did the same thing. Now the double-tap zones are ±10s, the
  buttons beside play are ±30s, and the transport bar's duplicate pair is
  gone. Arrow keys and J/L still do ±10s on desktop
- **The player's menus lead back.** Stepping from Settings into Subtitles
  and then wanting Aspect ratio meant closing the panel and reopening the
  gear. Sub-menus now carry a back arrow — but only when you actually
  stepped into them, since an arrow to a screen you never came from is worse
  than none
- **Swipe-to-adjust is gone.** Dragging up and down set volume on one half
  of the screen and brightness on the other. Hardware keys and the OS do
  both more reliably, and an accidental swipe changed either one mid-watch
- **The Live TV player matches the others.** Play/pause is centered over the
  video rather than tucked at the left of the bar, the volume control is the
  shared one (which also lifts its ceiling from 100% to the app's 250%
  boost — portal streams are often quiet), the top-bar buttons wear the same
  pills, and a live-edge row sits where the seek bar would be, so its
  absence reads as deliberate rather than broken
- **Details pages share one section heading.** Movies/Series, Anime and
  Arabic anime had each drifted to their own weight, letter spacing and
  spacing beneath. Anime's credits now lead the page as they do elsewhere,
  with Staff following
- Library's tabs are now **Liked / Watchlist / Watched / Downloads**, with
  the media-type pills inside each. They were Saved / Continue / Downloads,
  where "Saved" mixed two unlike states behind a deliberately generic icon.
  Continue is gone: it rendered the same deduped list the Continue Watching
  row already shows. Live TV appears under Liked only — a channel cannot be
  watchlisted or marked watched
- The IPTV portal browser's ⭐ Favorites is now **Pinned**, with a pin icon. Live TV was offering a heart in one place and a star in
  another for what looked like the same intent. They are not the same: a
  heart marks a channel, which is stable, while the portal browser pins one
  provider's stream, which disappears when that provider rotates its list.
  Naming them differently says so. Pin rather than bookmark because Watchlist already owns the bookmark
  metaphor app-wide. Existing pins are unaffected — the stored data did not
  change

### Fixed
- **Series now show a Creator** where TMDB has no director. A series'
  credits are series-level crew, which for most shows is producers and no
  director at all — TV directors are credited per episode — so the Direction
  half came back empty even with everything else working. The showrunner is
  what a viewer means by "whose show is this"
- **Text no longer escapes its box in IPTV Portals & Playlists** — the
  modal's title, the source dropdown's descriptions, and both Manage-mode
  toolbars, all of which painted outside their containers on a phone
- **Live TV's controls appear immediately on a tap.** A single tap had to
  wait to see whether a second one followed before anything happened
- A settings dialog was pinned wider than a phone screen and overflowed on
  exactly the devices the app is mostly used on
- **Casting a live channel** told the receiver it was a normal recording,
  giving it a seek bar and a duration it could not honour; MPEG-TS streams
  were also announced as MP4, which hands the TV a decoder that cannot read
  them
- Cast and crew now actually load from TMDB. `MovieDetail.tmdbId` is read
  from a `moviedb_id` field that Cinemeta and most Stremio addons never
  send — they send `imdb_id` — so the id was null for essentially every
  title and the enrichment request was never made at all. The details page
  fell back to the addon's plain name strings, which is why there were no
  photos, why the role line read "Cast" instead of a character name, and
  why films showed no director. IMDb ids are now resolved through TMDB's
  `/find` endpoint first, with the result (including "no match") cached per
  title. The bundled API key was never implicated — no request reached it

### Changed
- Live TV now uses the same page template as Movies, Series and Anime. Its
  filter bar floats transparently over a full-bleed hero instead of sitting
  in a solid band that pushed the hero down — the bar already asked to be
  transparent, it just had nothing behind it to show through. Its own
  569-line hero carousel is gone, replaced by the shared one; the three hero
  settings (compact/minimalist/immersive, auto-rotate, rotation interval)
  all still work

## [1.5.7+26] - 2026-09-11

### Added
- Arabic anime pages get the same Watchlist / Watched / Like controls as
  everywhere else. They had no library controls at all, so a show from the
  Arabic catalog was the one thing in the app you could not save

### Changed
- Anime now offers the same three library actions as Movies and Series —
  **Watchlist**, **Watched**, **Like** — in place of its own AniList-style
  menu (Watching / Plan to Watch / Completed / Dropped). All three sections
  now share one set of verbs and one store, so the Library page's **Anime**
  tab finally matches something: it filters on `MyListItem.type == 'anime'`,
  and nothing had ever been written there. `AnimeLibraryService` keeps its
  own AniList-shaped list and is kept in step, with Watchlist mapping to
  Plan to Watch and Watched to Completed
- Direction and Cast are now one **Cast & Crew** row on movie and series
  detail pages, crew first. They were two sections built from two nearly
  identical card builders, which bought two scroll positions, two hover
  states (only one with arrows) and two chances for the card geometry to
  drift. Every card shows the person's name over what they did — the
  character for cast, the job for crew

### Fixed
- The anime details page reads playback progress from the store that
  actually has it. Anime plays through the shared player, which saves
  position to `ContinueWatchingService`, but the page asked
  `AnimeLibraryService.lastWatchedEpisode` — a field no code path writes.
  So Play offered "Play Ep 1" however far into a series you were, and the
  episode grid never marked anything as watched. Both now follow your real
  progress
- Clearing an anime's library status no longer deletes its watchlist entry
  outright. That entry is the only carrier of `lastWatchedEpisode`, so
  removing it to clear a status would take any stored progress with it —
  taking a show off your watchlist means "not planning to watch this", not
  "forget that I watched 12 episodes of it"
- Director names now appear on titles whose addon doesn't supply crew. The
  TMDB `/credits` response carries cast *and* crew, but the crew half was
  decoded and dropped, so Direction was empty for nearly everything even
  with a working key. Cast enrichment also no longer skips a title just
  because the addon sent cast photos — that short-circuit meant a
  photo-rich cast list still left the Direction half blank

## [1.5.6+25] - 2026-09-11

### Fixed
- The Linux taskbar icon and "pin to task manager" still didn't work after
  1.5.5's fix — the wrong GTK property was changed (GApplication's
  `application-id`, which the compositor doesn't use for this); the one
  that actually drives it (`prgname`) is now aligned to the Flatpak's app-id
  instead
- That same 1.5.5 fix had silently forked every install's on-disk library
  into an empty directory the moment it shipped — `path_provider`/
  `shared_preferences` are now pinned back to the stable id, independent of
  whatever the window/taskbar app-id is set to
- The in-app updater's 1.5.5 Flatpak fix told users to run
  `flatpak update`, which can never work for a bundle install (no live
  repo behind it) — now downloads the actual `.flatpak` asset and shows a
  `flatpak install --reinstall` command instead
- Trakt sync silently failed with no explanation. Trakt now requires a VIP
  subscription to register a new API app, which isn't set up; shows an
  info note instead of a dead-end "Connect" button. Simkl is unaffected
- Details pages (Movies/Series/Anime) had a large empty band at the top,
  left over from before they rendered fullscreen
- Movies/Series' Cast and Direction rows had different card heights,
  creating an inconsistent gap between them
- The browse header (search/filter pills) sat in its own band above the
  hero carousel, visibly cutting it off at the top — now floats
  transparently over the hero's top edge instead
- A Flutter 3.44.0 CMake bug intermittently broke the Linux CI build

### Changed
- The player's subtitle button is now a plain on/off toggle (YouTube's CC
  button); track and style picking moved into the Settings gear as a
  "Subtitles" row, which now also caps its height and scrolls instead of
  risking overflow on short mobile screens
- Cast/crew photos without a picture now show a generic silhouette instead
  of a colored gradient with initials
- The like/save/watched icons on Details pages now share the same boxed
  style
- Director now appears before Cast on Details pages, on both Movies/Series
  and Anime
- Settings' "General & Data" split into "Backup & Data" and "Keyboard
  Shortcuts"; TMDB and Discord Rich Presence moved into "Connect" (renamed
  from "Sync"), alongside Trakt and Simkl

## [1.5.5+24] - 2026-09-11

### Fixed
- The in-app updater offered a Flatpak install the AppImage to download
  (and, had it picked the right asset, would have told you to `chmod +x`
  and run a `.flatpak` file). It now detects the Flatpak sandbox and shows
  the `flatpak update` command instead, the same way it already
  special-cases macOS/iOS
- The release build's Flatpak job cache key was unique per commit, so it
  never actually hit -- every release rebuilt `libsecret` from source and
  re-downloaded the Freedesktop SDK/Platform runtime from scratch. Keyed
  on the manifest's own hash instead, so only a manifest change busts it

## [1.5.4+23] - 2026-09-11

### Fixed
- Settings' desktop/tablet layout showed categories as a 2-3 column grid;
  every category is now stacked one per row on every screen size, like
  mobile already was

## [1.5.3+22] - 2026-09-10

### Fixed
- The Linux window's title bar used the stock Flutter template's default: a
  native `GtkHeaderBar` with a hardcoded title, styled by whatever GTK
  theme happens to be available — inside a Flatpak sandbox, not
  necessarily the host's own theme, and unrelated to the app's own dark
  UI either way. It was also taller than a plain title bar. Now always
  renders a plain title, letting the window manager/compositor draw its
  own (themed, slimmer) decoration — confirmed by building and actually
  running the window on this machine

## [1.5.2+21] - 2026-09-10

### Fixed
- The Flatpak still didn't start after 1.5.1's libsecret fix: "Failed to
  create AOT data / Invalid ELF path specified". Flutter's Linux embedder
  resolves `data/` and `lib/libapp.so` relative to `/proc/self/exe`'s own
  directory (confirmed straight from the engine source, and from the
  executable's own `RUNPATH: $ORIGIN/lib`) — the manifest installed them
  as siblings of `/app/bin/` instead of inside it, so the executable could
  never find its own assets. Fixed by installing everything the exe needs
  under `/app/bin/` alongside it, the same layout `flutter build linux`
  already produces
- Every back button's vertical position is now standardized on the same
  shared inset (`AppSpacing.floatingTopInset`) — it previously varied by a
  few px depending on which page you opened it from. Details and Anime
  Details still float the button directly over their full-bleed hero
  rather than inside a header bar like every other page — a deliberate
  difference for that layout, not left over from this fix

## [1.5.1+20] - 2026-09-10

### Added
- Download resilience: an HTTP or HLS-segment download that drops mid-way
  or closes just short of the expected size now auto-reconnects (up to 5
  attempts) instead of failing outright
- A "Copy Stream URL" button in the player, next to Cast

### Changed
- Leaving the player no longer force-exits fullscreen if the app was
  already fullscreen before it opened (e.g. kiosk mode) — only fullscreen
  the player itself entered. F11 now also toggles fullscreen, alongside F

### Fixed
- The Flatpak package failed to launch at all: "error while loading
  shared libraries: libsecret-1.so.0: cannot open shared object file".
  `flutter_secure_storage_linux` needs libsecret, which isn't part of the
  base Freedesktop runtime — now built and bundled as its own module
- The Flatpak's metainfo version was hand-written and already stale
  (showing 1.3.0 for a 1.5.0 install); now stamped from the same
  resolved version every other platform's filename uses

## [1.5.0+19] - 2026-09-10

### Added
- **Built-in Providers** settings page: each built-in scraper now has its
  own switch, so you can cut the source list down to the handful that work
  for you instead of waiting on all 48. Torrent providers are marked, and
  say when the P2P master switch has silenced them. The roster is generated
  from the scrapers the app actually registers, not a written-down list, so
  porting or dropping a scraper adds or removes its row with nothing else
  to update
- A Flatpak build and packaging manifest for Linux, alongside the existing
  AppImage and tar.gz

### Changed
- Anime's page now uses `BrowseScaffold`, the same hero + row + loading/error
  arrangement Movies and Series already use, instead of its own hand-rolled
  hero carousel and state machine. No card's look or size changed — Anime's
  rows already used the shared `BrowseRowView`/`AnimeCard`, so this only
  consolidated the page chrome around them
- Live TV's channel row (`IptvSliderSection`) now renders through the same
  shared `BrowseRowView` every other row uses, instead of its own copy of
  the scroll arrows, hover state and section header. Channel cards keep
  their own logo/banner shape — `BrowseRowView` can now take a row-specific
  card sizing instead of always using the poster one
- Every page with its own back button (Details, Search, Settings, and
  everything else routed through `pushPage`) now renders fullscreen,
  covering the hub's top bar and section chips, instead of showing both at
  once
- Settings redesigned: every category tile is now the same shape and size
  (icon, title, a short badge, chevron) — no subtitle sentence, no header
  intro card. Trakt.tv and Simkl merged into one "Sync" category; App
  Updates folded into About; the P2P master switch moved into Built-in
  Providers, next to the rows it silences; Discord Rich Presence moved into
  General & Data. Remaining categories sort A-Z, About last. Tablet/desktop
  shows them as a centered grid instead of a single narrow column
- The repository's default branch is now `main`, not `master`
- Release builds now warn in CI when no `ENV_FILE`/`DOTENV` secret is
  set, instead of silently producing artifacts with an empty `.env` —
  which is what every release so far has shipped, leaving Trakt, Simkl,
  Discord Rich Presence and TMDB cast photos inert in the binaries
- A failed Windows release build now re-runs the failing CMake INSTALL
  target verbosely, so the underlying error is in the log. `flutter
  build` summarises MSBuild's output, so the v1.4.0 build failed twice
  showing only `MSB3073` with no reason

### Fixed
- Settings could open twice from a fast double-click on the gear icon
  (easy to do with a mouse), stacking two instances — back had to be
  pressed twice to actually leave
- A pushed `v1.2.0` tag now publishes as a full release. Both the release's
  `prerelease` flag and its "(dev)" title came from
  `github.event.inputs.dev_build != 'false'`, and that input is an empty
  string on a tag push — so every tagged release would have been labeled
  an untested dev prerelease. The title, the badge and the channel compiled
  into the binaries are now all read from one resolved value
- An unverified build now actually says so. `dev_build` only ever set the
  GitHub release's title and prerelease flag; the binary carried a
  hardcoded empty channel, so Settings, Updates and About reported a dev
  prerelease as a verified release and hid the prerelease badge. The
  marker is now baked in by the build from the same condition that sets
  the release flag, so the two cannot disagree

## [1.4.0+18] - 2026-09-09

### Added
- Seed count and a P2P/HTTP indicator on every stream-source picker
  (Movies, Series, Anime, Arabic Anime, and the in-player panel) — the
  seed count was already being parsed out of source titles and then
  never shown
- Support for a TMDB API key baked into the build, so cast photos and
  character names work on a fresh install instead of only after the
  user registers and pastes their own key (which still takes
  precedence). See `TMDB_API_KEY` in docs/RELEASES.md

### Changed
- Audio track selection moved behind the video player's settings gear,
  alongside playback speed and aspect ratio, instead of its own button
  in the transport bar. The row is hidden for media with only one audio
  track
- The genre/decade/sort/search filters now stay on one line and stay
  put while the page scrolls, with the hero carousel starting just
  below them. They previously wrapped onto a second row on phones and
  scrolled away with the hero
- Live TV's header moved onto the same shared pill bar as every other
  section, instead of its own SafeArea and padding
- One page transition everywhere. The 750ms circular reveal is gone —
  it revealed from a tap position most call sites never had, including
  the poster tap it was designed for
- One page gutter, `AppSpacing.pageInset` (16/20/24, mobile first),
  replacing the 8/16/18/20/24/28/48 spread across filter bars, back
  buttons, header rows, section titles, card rows and grids

### Fixed
- Anime Details now picks its layout from the window width like every
  other page, instead of from the platform — a desktop window dragged
  narrow kept desktop metrics (38px titles, a 1440px content cap) while
  Movie Details beside it switched to mobile ones
- Backing out of the video player no longer exits the app when playback
  was started from an anime episode's source sheet
- The TMDB key shipped with a build is now actually used — cast
  enrichment still checked only for a user-entered key, so the built-in
  one never took effect
- Audio Sync Offset is reachable again for media with a single audio
  track; it lives in the audio menu, which was being hidden in exactly
  that case
- Wrong seed counts on source badges: titles like `[12/12]` or
  `Files: 3` were read as seed counts, and the `25/3 peers` form
  reported the leecher count instead of the seeds
- The filter bar no longer counts the status bar twice on notched
  phones, which cost ~50px of every browse page
- Row titles no longer shift sideways when real content replaces the
  loading skeleton
- Resuming from Continue Watching now opens straight into the player.
  It was pushed inside the hub's navigator, so the section top bar and
  sidebar stayed drawn around a fullscreen video screen
- The "Resuming..." spinner not closing, and popping the page under
  the Continue Watching row instead of itself
- Anime Details' back button sitting under the status bar on phones
  with a notch
- The torrent icon in the player's sources panel disagreeing with its
  own P2P badge for a magnet link carrying no separate infoHash

## [1.3.0+17] - 2026-09-08

### Added
- Google Cast support in the video player (Android/iOS) — needs
  real-device verification before it can be considered done
- New HindMoviez scraper site
- Castilian (Spain) vs. Latino (Latin America) Spanish audio-dub
  detection, with their own badges

### Changed
- Video player UI simplified: play/pause and ±10s seek moved to a
  centered overlay; playback speed and aspect ratio consolidated
  behind one Settings button; fullscreen and duplicate Episodes
  buttons removed (both already reachable another way); download
  button removed (still available before playback starts)
- Double-tap now seeks ±10s on the left/right thirds of the video on
  touch platforms, keeping double-tap-to-fullscreen on the middle
  third and on desktop
- Swipe-to-adjust volume/brightness removed on mobile (hardware
  buttons and the OS already do this) — unchanged on desktop

### Fixed
- Arabic anime catalog and search scraping, following the source
  site's changed HTML structure
- Header pill controls (genre/decade/sort filters, search, Live TV's
  icon buttons) now keep a minimum 40×40 tap target even when
  icon-only, instead of shrinking to ~31px

## [1.2.1+16] - 2026-09-06

### Fixed
- The genre/decade/sort/search header on Movies, Series, Anime, and Live
  TV no longer stays pinned to the screen while the page scrolls
  underneath it
- The search icon, and Live TV's whole header, now match the same pill
  design used everywhere else instead of a bare icon and a bespoke
  gradient "glass" look
- Extra empty space above Library's header on mobile
- Tapping the video no longer toggles play/pause — it only shows/hides
  the controls now, same as before that was added; it conflicted with
  double-tap-to-fullscreen and added input latency for no real benefit
  over the dedicated play/pause button
- Gap between the back button and the search field on Search, Catalog,
  and Anime Search
- Row titles ("Popular", "New", ...) no longer sit flush against the
  card row underneath them

## [1.2.0+15] - 2026-09-06

### Added
- Audio dub/language detection and filtering for stream sources, player
  error filtering, and stream health checks — ported from upstream
  `ayman708-UX/PlayTorrioV3` (`ad0e40d`, `6c4d0cf`)
- Stremio catalog-extra and collection addon support — ported from
  upstream `f1f1310`
- Movies and Series split into two full top-level navigation sections
  (previously shared one section behind an internal pill toggle)
- Live TV channels can be favorited (heart on the channel card and in
  the channel detail sheet); favorited channels surface in Library
  under a new Live TV chip
- A Watched toggle chip in Library, alongside Watchlist
- One shared genre-tag pill row (`GenreTagRow`), filter/search pill row
  (`PillFilterHeaderBar`), and back button (`GlassBackButton`) — each
  replacing several hand-rolled, slightly-inconsistent implementations
  across Movies/Series/Anime/Anime-Arabic/Search/Catalog/Discover/IPTV
- A 760×600 minimum desktop window size, so the window can't be shrunk
  into the cramped mobile breakpoint

### Fixed
- The 5-section navigation bar no longer gets hidden behind Details,
  Search, Catalog, Discover, or Settings on tablet/desktop
- The Settings gear icon no longer drifts position between mobile,
  tablet, and desktop, or as the window is resized within a tier
- A catalog fetch failure (e.g. a transient network error) no longer
  silently looks like "no content" — it now surfaces a retryable error
- Subtitle translation language list trimmed from ~110 languages to a
  curated ~34 commonly-used set
- Android back button not popping pages pushed in the hub content area —
  `NestedNavigator` now handles the system back gesture via
  `NavigatorPopHandler`

### Changed
- New app icon, `assets/icon.png`, regenerated across all platforms

### Removed
- Custom Background & Wallpaper and Liquid Glass Setup — both leftover
  from PlayTorrioMod (the app this repo forked from); Liquid Glass
  themed a bottom dock that doesn't exist in this single-hub app, and
  its toggle defaulted off with no way to enable it, so every gated
  code path was already dead
- Library's own local search bar, superseded by the same per-page
  search icon every other page already uses

## [1.1.6+14] - 2026-09-04

### Added
- 30 new torrent/stream scraper sites and 7 new anime extractors, ported
  from upstream `ayman708-UX/PlayTorrioV3` (commit `b0aecf5`) side by side
  with Mov's own existing, non-overlapping set — see
  [ROADMAP.md](docs/ROADMAP.md#upstream-sync) for the full list and
  what was deliberately left out
- `stream_model.dart` getters (`quality`, `isHDR`, `codec`, `fileSize`,
  `sizeBytes`, `qualityRank`) now memoized instead of recomputing regexes
  on every access; new `seeders` getter
- Android "Direct Surface" player rendering toggle (`player_settings.dart`,
  `video_player_settings_page.dart`), now reachable from Settings

### Fixed
- AniList catalog 403s — request now sends a browser-like User-Agent/
  Origin/Referer and a 15s timeout instead of the old custom UA (ported
  from upstream `cc07994`)
- IPTV player now actually applies `PlayerSettings`' video controller
  configuration instead of bare defaults
- `app_info.dart` fallback version had drifted from `pubspec.yaml`

### Removed
- Dead code: `AnimeDetailsModal`, `MyListPage`, `ProfileRuntime` (a
  hardcoded-always-true guard) and its `profile_async_authorization.dart`
  re-export shim, the unused `flutter_inappwebview` dependency
- Duplicated desktop-Chrome User-Agent literal across 51 scraper/extractor
  files, collapsed into one shared constant

### Cleared
- `AppInfo.channel`'s `(dev)` marker — this release is the first to ship
  as a full, non-prerelease build; see ROADMAP.md § Blocked on a device

## [1.1.5+13] - 2026-09-02

### Added
- Watchlist / Watched / Like three-state buttons for Movies & Series
  (ported from PlayTorrioMod)
- `MediaSessionService` restored — Android/iOS lock-screen, notification and
  Bluetooth media controls for video playback
- Movies & Series browse page: inline type-switch pill, Continue Watching
  slot, Latest Releases row, Series-only upcoming calendar row, optional
  overlay header
- CI: release artifact filenames stamped with the app version

### Fixed
- Video player tap-to-play/pause and the volume-scroll menu conflict
- Library tap-to-details and Saved-tab poster sizing
- Details pages no longer block hub pill / bottom-bar navigation
- Anime hero carousel height brought in line with Live TV's
- Movies & Series hero reads the addon's own `background` field instead of
  cropping the portrait poster
- Grid covers no longer grow unbounded on wide desktop windows (7-column
  cap past 1600px)
- Windows "Unknown hard error" on close — candidate fix ported from
  PlayTorrioMod (`PlaybackCoordinator.disposeForShutdown()`), not yet
  verified close-while-playing on hardware
- Universal play bar suppressed during video playback (each source already
  opens a full-screen `PlayerScreen` with its own transport controls)
- `TorrentStreamService` kills an orphaned `torrserver.exe` before starting

### Changed
- `torrserver_flutter` 0.0.5 → 0.0.6 (PID-file tracking, real `GET
  /shutdown` call replacing the REST-echo orphan probe)
- Library's Saved tab dropped the heart icon and History tab
- Anime's language toggle became a flag+name dropdown
- `LibraryTabs` switched from an underline tab bar to `PillTabRow`

## [1.0.0] - 2026-08-31

### Changed
- Forked from [PlayTorrioMod](https://github.com/MediaHub-Org/PlayTorrioMod)
  as a watch-only app: Movies, Series, Anime, Live TV
- Removed Music, Podcasts, Audiobooks, Books, Manga, Comics modules and
  their settings tiles
- Collapsed the three-hub abstraction (`AppHub`, hub-pill nav) into a
  single Media hub
- Renamed package to `playtorriomov`; rebranded platform identity files
  (Android, iOS, Windows, macOS, Linux)
- Dropped `audio_service`/`xml` dependencies no longer needed post-fork

[1.1.5+13]: https://github.com/MediaHub-Org/PlayTorrioMov/releases
[1.0.0]: https://github.com/MediaHub-Org/PlayTorrioMov/commit/cc3a1b3

---

## Item index

What each `#N` refers to, for reading old commits and pull requests. #1–#14
closed before the roadmap was rewritten for maintenance mode and live in git
history only.

| # | Item |
|:--|:-----|
| #15 | Mobile-first, made checkable (`test/mobile_first_test.dart`) |
| #21 | The logo's film-strip rule |
| #28 | Google Cast — sender path fixed; receiver test still pending |
| #38 | Cast and crew actually load |
| #39 | Series creators |
| #40 | IPTV portal modal overflows (four, not two) |
| #41 | One details spine and one section heading |
| #42 | The Live TV player converged on the shared controls |
| #43 | Library tabs became the three states |
| #44 | One amount per seek control (±10s double-tap, ±30s buttons) |
| #45 | Live TV Liked row and portal pin |
| #46 | Channels you make yourself |
| #47 | Watch history |
| #48 | One search across Movies, Series and Anime |
| #49 | Settings scroll from anywhere in the window, not just the center column |
| #50 | Backup export/import through the system file picker |
| #51 | User-supplied Simkl client ID, and a reason when Connect fails |
| #52 | System / Light / Dark switch (the color migration is #59) |
| #53 | One ISO-639 table for subtitle providers (two were 51 languages short) |
| #54 | Wyzie subtitle downloads go through `SubtitleExtractor` like the rest |
| #55 | One master-URL builder for cinesrc/cine.su/bcine (was triplicated) |
| #56 | One pipeline for vidfast/vidup (was two ~200-line near-clones) |
| #57 | `print()` out of `lib/`, `avoid_print` enforced as a warning |
| #58 | A silent scraper no longer holds the stream search open forever |
| #59 | The color migration behind #52 — `AppColors`, and what it excludes |
| #60 | Every `package:http` call carries a timeout, enforced by a test |
| #61 | Nav chrome (top bar, section switcher, mobile tab bar) follows the theme |
| #62 | `HeaderPillSurface`: header pills know when they float over a hero |
| #63 | `AppColors.accent` — the palette picker reaches the whole app (was 156 hardcoded violets) |
| #64 | Light mode finished: every remaining dark literal is either a token or annotated as artwork |
| #65 | `OverArtwork`, the details backdrop bounded to its hero, and the last black backgrounds (Live TV, settings, genre chips) |
| #66 | Three parallel PR-check jobs, and the `prefer_const` sweep that emptied the analyzer's info list |
| #67 | Collections: CRUD, the fourth library action, and a Library rebuilt around them. Device-confirmed on a phone 2026-09-16 |
| #68 | Translation (i18n) — infra + Spanish/Arabic/Portuguese-BR shipped for nav, settings and the Library (~64 of ~500-800 strings); the display/canonical title split is still just decided, not built |
| #69 | Text scale and accessibility — ten high-traffic overflow fixes + in-app zoom shipped, capped at 1.3x; ~58 files still unaudited |
| #70 | Audio silent under Flatpak — `--socket=pulseaudio` added; confirmed on real speakers 2026-09-16 |
| #71 | Subtitle appearance settings now expand inline in Settings instead of opening as a pop-up |
