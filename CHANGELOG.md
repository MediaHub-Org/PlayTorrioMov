# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- **The hero carousel now fills the screen down to Continue Watching.** It was
  sized as a fraction of the *screen* — 0.52 of it on desktop, capped at 560px —
  which left the row below it sharing the fold with the start of two more, and
  on a phone was measured against a height the page never had: the top bar, the
  section chips and the bottom tab bar all come off it first. The hero is sized
  from the viewport it was actually given, minus the exact height of the band
  beneath it, so the hero and the Continue Watching row come to one screen and
  that row is the last thing above the fold. No breakpoint table: the size is
  arithmetic on the window, clamped only at the ends so a half-height window
  still shows real artwork and a very tall one does not get a poster the height
  of a door. The band's height is now a single formula
  (`ContinueWatchingSlider.bandHeight`) used both to lay the row out and to size
  the hero, with a test that measures the rendered row against it, so the two
  cannot drift

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
  no addons at all, so every catalogue had nothing to query for the rest of
  the session. A cold start is exactly when that call is most likely to
  fail — DNS cold, connection pool empty, the radio still waking. It is
  retried now when a page next asks for a catalogue, so recovering costs a
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
- macOS ships one universal build instead of two identical ones labelled Intel
  and Apple Silicon, with a check that fails the build if it stops being
  universal. Releases are about six minutes shorter

## [1.6.2+30] - 2026-09-14

The light-mode corners 1.6.1 could not reach, and the details page that was
blocking most of them.

### Fixed
- **"Could not load movies" on the Anime page.** The error card defaulted to
  that heading and no page ever replaced it, so Anime and Live TV both told
  you your *films* had failed while the line underneath correctly named the
  anime catalogue. Each page now says what it was actually loading
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

Light mode, finished. 1.6.0 shipped the colour system; this is the chrome it
did not reach.

### Fixed
- **The bars were black-on-black in light mode.** The top bar, the section
  switcher on desktop and the tab bar at the bottom of a phone each carried
  their own dark colour, while the wordmark and icons on them had already
  moved to the theme. Choosing Light turned the glyphs dark and left the bars
  dark. They are light now, with dark icons and lettering, and take their
  tint from whichever of the eight palettes you picked
- **Live TV's header** sits on a shade over the channel artwork rather than
  on the page, so the same change would have turned *its* text black on a
  photograph. Those controls now know they are over artwork and stay white —
  in both themes, which is what they were always meant to do
- **Seven of the eight themes only half-applied.** The accent colour was
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
  the app's roughly 1000 white text colours and 100 dark surface hexes
  ignored the theme, so choosing Light gave you one correct settings page
  and a dark everything else. They now resolve against the active theme, and
  the eight accent palettes stay distinguishable in light the way they are in
  dark. A dark build is unchanged — the dark values are the same colours
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
- **Character names on the cast row.** Every actor was labelled "Cast"

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
  catalogue
- **Live TV channels you can make yourself.** If a portal carries something
  the built-in catalogue has no entry for, save it from the player's top bar
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
- A **film-strip accent** under the wordmark, drawn in the theme's colour
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
- **The Live TV player matches the others.** Play/pause is centred over the
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
  Arabic catalogue was the one thing in the app you could not save

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
  string on a tag push — so every tagged release would have been labelled
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
  [ROADMAP.md](docs/ROADMAP.md#upstream-tracking) for the full list and
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
