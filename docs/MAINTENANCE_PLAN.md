# Maintenance and refactor plan

**Why now.** The app is in a good state: it builds on every platform, the suite
is green (197 test files) and the roadmap's open list is device checks only.
That is the moment to make the code cheaper to change, before the next feature
makes it dearer. This plan says what to change, in what order, and how to know
each step did not break anything.

Measured on `v1.9.7+55` (2026-10-08), not guessed:

| Fact                                               | Value                                                                                                                                                    |
|:---------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| Dart files / lines under `lib/` (no generated l10n) | 332 / about 102,600                                                                                                                                      |
| Test files                                          | 197                                                                                                                                                      |
| Files over 1,000 lines                              | 21. The five largest: `player_screen.dart` 3,685, `watch_screen.dart` 2,755, `details_page.dart` 2,433, `iptv_portal_browser_page.dart` 2,160, `iptv_player_page.dart` 2,080 |
| The same key-activator set, copied                  | 17 files declared their own (now one)                                                                                                         |
| The same logo-or-title block, copied                | `details_page.dart` and `watch_screen.dart` each build it, with different size constants                                                                 |
| Press / hover / focus primitives                    | `HoverButton`, `PlayerIconButton`, `FocusRing`, `FocusFill`, `FocusHighlight`, and the subtitle panel's `_MenuPill`: six, each with its own rules        |
| Deprecated `withOpacity`                            | 28 calls in 3 files, hidden by `deprecated_member_use: ignore` in `analysis_options.yaml`                                                               |
| Empty `catch`, `TODO`, `FIXME`                      | 0 / 0 / 0 (the triage in #29 held)                                                                                                                       |

Nothing here is broken. The cost is that a one-line change to the player means
reading 3,700 lines, and a fix in one of six focus primitives has to be
remembered in the other five.

## Ground rules

These keep a refactor from being a rewrite.

1. **One extraction per pull request, and no behavior change in it.** If a PR
   moves code, it only moves code. A fix found on the way goes in its own PR.
2. **A test first, where there is none.** For the player that means pulling a
   decision out into a pure function and pinning it, the way
   `remote_key_decision.dart` and `back_press_decision.dart` already do. Move
   the code only once the test exists and is green.
3. **Same analyzer, same suite, same bundle.** `flutter analyze --fatal-infos`
   clean and `flutter test --exclude-tags network` green before and after.
   Report the line counts before and after in the PR.
4. **Keep the comments.** The long comments in these files record why a thing is
   the shape it is. A move carries them; it does not summarize them.
5. **Device-only behavior stays on the Pending list.** A refactor of the player
   cannot be proven from here, so each one that touches playback adds its device
   check to `ROADMAP.md` instead of claiming it is verified.

## Order of work

Ordered by value for risk: the cheap, mechanical wins first, the player last
because it is the largest and the least testable from a desk.

### Step 1 — Mechanical dedupe (low risk, high repetition) — **done**

Shipped on this branch: 17 private key sets became `kActivateKeys` /
`kActivateKeysWithSpace` (a test now fails on a new copy), the logo-or-title
block is `TitleOrLogo` (details, sources and the loading screen), and the 28
`withOpacity` calls are `withValues`. Not done: `deprecated_member_use: ignore`
stays, because turning it on shows **37** other deprecations -- 28 `activeColor`
on switches (the replacement changes how a switch looks, so it needs eyes on a
device), 6 `cacheExtent`, and one each of `value`, `textScaleFactor` and
`onReorder`. That is the next mechanical PR.

- **One `activateKeys` set** in `lib/widgets/common/`, replacing the 13 private
  copies. They differ in one place at most (`space` is in `HoverButton`'s and
  not in the genre row's), so the shared set takes the union and the one
  caller that must not react to Space says so.
- **One `TitleOrLogo` widget** for the details page, the sources page and the
  player's loading title. Each takes only its own size caps. The player's
  `PlayerLoadingTitle` is the third copy of this idea.
- **`withOpacity` to `withValues`**, 28 calls, then drop
  `deprecated_member_use: ignore` so the next deprecation is not silent.

Exit: three PRs, each a pure replacement, suite unchanged.

### Step 2 — One press/hover/focus primitive

Six widgets answer "what does a control look like when a finger is on it, a
mouse is over it, a remote is on it". Each fix (the subtitle panel's Refresh
button was one) has to be remembered six times. Consolidate to one base that
owns, in one place:

- hover, pressed and focus states and their colors,
- the rule that focus is drawn only in `FocusHighlightMode.traditional`, so a
  panel that takes focus on open does not look switched on for a touch viewer,
- Enter, Select and Game-A activation.

`HoverButton`, `PlayerIconButton` and `_MenuPill` become thin wrappers that
choose a shape. `FocusRing`, `FocusFill` and `FocusHighlight` are the visual
variants of the same state and fold in as options.

Risk: every screen has focus behavior, and TV focus is the thing hardest to
check from here. Do it one call-site family at a time, with the TV checks in
the roadmap's Pending list as the gate.

### Step 3 — Split the big pages along seams that already exist

Each of these is several widgets and a state machine in one file. Split by the
section the file already has, not by line count.

| File                          | Seams to cut along                                                                                                                                                             |
|:------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `details_page.dart` (2,433)   | Hero (desktop and mobile layouts), the rails (cast, similar, collection, episodes), `_EpisodeCard`, the metadata fetching. The rails already take plain data.                  |
| `watch_screen.dart` (2,755)   | Source loading and filtering, the source card, the filter pills. The card and the filters are widgets with a clear input.                                                      |
| `anime_details_page.dart`     | Same shape as the details page; share the hero and the episode card once Step 1 lands.                                                                                         |
| `iptv_portal_browser_page.dart`, `iptv_player_page.dart` | The Live TV player is a subset of the main player (#14) and carries its own copy of the control wiring; plan it together with Step 4.            |
| `video_player_settings_page.dart` (1,848) | One section per card; each card becomes a widget in its own file.                                                                                                      |

Exit: no page file over about 1,500 lines. Generated-looking tables
(`hardcoded_channels.dart`) are exempt.

### Step 4 — The player, last

`player_screen.dart` is 3,685 lines and owns the load pipeline, the subtitle
roster, ten menus, casting, skip segments, history and the TV key handling.
Cut it into controllers with a narrow interface, each pulled out behind a pure
decision function and a test:

1. **Load pipeline** (resolve, open, first frame, progress). Already has
   `PlayerLoadProgress`; the sequencing around it moves into a
   `PlayerLoadController`.
2. **Subtitle state** (embedded roster, selection, online search, delay). The
   embedded-track building is a long block inline in the screen today and is
   already covered by pure functions in `subtitle_languages.dart`.
3. **Menus host** (which menu is open, parent, back behavior). `back_press_decision`
   is the first piece of it.
4. **Casting handoff and history writes.**

Do not start this step until Steps 1 and 2 are merged: the player is where the
shared primitives matter most, and it should be moved once.

### Step 5 — Services that grew

- `trakt_service.dart` (1,846) and `simkl_service.dart` (1,398): split into
  auth, sync and item mapping. Trakt sync is switched off (see the roadmap's
  decided list), so this is the lowest-priority split in the plan.
- `iptv_network.dart` and `iptv_controller.dart`: split by protocol (M3U,
  Xtream, Stalker); the offline response-shape tests from #31 are the net.
- `player_settings.dart` (1,484): preferences, mpv property application and the
  buffer presets are three jobs.

## Dependencies and platform

| Item                              | State                                                                                                                                          | Action                                                                                                    |
|:----------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------------------------------|
| Flutter                           | `3.44.0` pinned in all three CI jobs                                                                                                           | Move all three together, and only after a dispatch build with an empty `release_tag` passes on every platform |
| `media_kit` and its native libs   | Pinned to the Predidit fork at one commit                                                                                                      | Re-check the fork for fixes when a playback bug shows up; do not float the pin                           |
| Packages with newer versions      | 54 held back by constraints (e.g. `file_picker` 8 to 13, `flutter_secure_storage` 10 to 11, `cached_network_image` 3 to 4, `torrserver_flutter` 0.0.6 to 0.0.7) | One package per PR, majors only when a changelog shows a reason. `torrserver_flutter` first: it is the torrent engine |
| Runner images                     | `ubuntu-24.04` pinned; `windows-latest` and `macos-latest` still float                                                                         | Pin them the same way the moment either announces a migration                                            |
| `pubspec.lock`                    | Churns on a local `pub get` (see `RELEASES.md`)                                                                                                | Keep restoring it before commit                                                                          |

## What not to do

- No architecture change (state management package, dependency injection) for
  its own sake. The `pages -> widgets -> services -> models` rule holds and the
  codebase is consistent with it.
- No renaming sweep. Names are load-bearing in places (`*_menu.dart` is globbed
  by a test).
- No refactor in the same PR as a feature.
- No new dependency for something small.

## How this list is kept

Each step becomes numbered items in `CHANGELOG.md`'s index when it ships, and
`ROADMAP.md` carries only what is still open. If a step turns out to be wrong
once started, say so here and cross it out; a plan that is never corrected is
the thing that stops being read.
