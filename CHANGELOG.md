# Changelog

All notable changes to PlayTorrioMov are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **The loading screen says what is loading.** Above the filling logo it now
  shows the title's own logo, or its name where there is no logo (anime has
  none), and under it the episode ("S1 · E3 · In Perpetuity"). The player had
  been handed the logo for a long time and never drew it, so a slow torrent
  waited on a screen that did not name the movie. A movie shows the detail's
  name, not the release's filename.

### Changed

- **On a TV, the details page starts on Play.** A remote used to land on the
  genre tags first, because reading order puts anything higher on the screen
  ahead of Play and, on a wide layout, the tags sit higher. The tags are gone
  from the details page (the genres are still in the info line under the
  title); they opened the Discover page for that genre and added a stop
  before the video.
- **The speed menu is a slider and nothing else.** The - and + buttons are
  removed: Left/Right on a remote and a drag on a screen already step the
  slider, so they were a third way to do it and one more thing to focus. On a
  TV a hint line says what the remote does ("Left/Right to adjust · OK to
  apply").
- **Sliders in the player no longer wear a frame.** The speed and volume
  sliders take focus when their menu opens, so the box that marked focus was
  on screen by default. Focus is now a thicker track and a larger thumb, as
  on the seek bar. Up and Down are no longer taken by these sliders, so a
  remote can leave them for the menu's Back button.

### Fixed

- **TV focus audit: rows and pills that showed nothing under a remote.** An
  `InkWell` over an opaque container hides its own focus and hover, so 38 rows,
  sheet options, cards and buttons (the sources and episodes panels, the cast
  and subtitle-style sheets, collections, Live TV, the video settings cards, the
  nav rail) showed no focus; each is now wrapped in `FocusFill`, which also
  answers a mouse (a light wash) and a press (a stronger one). Seven sort and
  catalog pills built on `PopupMenuButton` (Discover, Catalog, Library, Live TV
  sources) get the soft wash `FilterDropdown` already had. A source scan
  (`test/tv_focus_cues_test.dart`) keeps a bare `InkWell` from coming back.
  Not confirmed on a TV.
- **"Sources" filter pills lost focus.** The add-on pill is in the row only
  once the sources span more than one add-on, which is not known until the
  search is part-way through; a pill appearing ahead of the focused one rebuilt
  it as its neighbor and focus fell off the row. The pills now keep their own
  identity, and so do the source cards, which are re-sorted as add-ons answer.
- **The filter menus opened with focus still on the pill underneath.** A dialog
  route hands focus to nothing in it, so the first arrow went to the page behind
  the menu. A menu now takes focus on open, and a single-choice menu starts on
  the selected row.
- **On a TV, focus disappeared after any pointer event.** Flutter stops drawing
  focus the moment it sees a pointer (a remote app, an air mouse), and a TV has
  nothing to bring it back. The TV pins focus drawing on.
- **On a TV the speed menu closed after one press.** Every arrow was reported
  to the menu as a finished drag, so going from 1x to 1.5x lost the menu at
  1.25x. It now stays open while Left/Right step the speed and closes on OK
  or Back. Not confirmed on a TV.

## [1.9.7+55] - 2026-10-08

### Added
- **Source cards show the bitrate.** Parsed from the release title where
  stated, probed off the HLS master manifest for direct streams (cached
  per URL, four at a time, playlists only -- never a GET just to learn a
  file is an mp4), or estimated from size and runtime as a last resort.
  Ported from upstream's Oct 2/5 batch onto this fork's rewritten cards,
  with the manifest decoded as UTF-8 and concurrent probes for one URL
  deduplicated. Twins that state nothing still take numbers rather than
  reading the same word twice.

### Fixed
- **The first movie card no longer opens pre-selected and zoomed on
  desktop.** Focus hands itself to the first card so a remote has somewhere
  to be -- but the zoom followed focus unconditionally, so mouse viewers
  got a "selected" card they never touched. Focus styling now follows the
  keyboard highlight mode like the player menus already do: keys and D-pad
  still zoom, mouse and touch do not.

## [1.9.6+54] - 2026-10-08

### Fixed

- **Simkl Connect now uses the device-authorization flow Simkl actually
  issues to new apps.** The old `GET /oauth/pin` this replaced answers
  every current app registration with "this client_id is an OAuth 2.0 app,
  use POST /oauth2/device instead" -- so Connect could not have worked for
  any Simkl app registered today, regardless of how correct the client ID
  was. Verified against Simkl's real API with a live client ID, not
  assumed from docs.
- **Twin embedded subtitle tracks no longer read identically.** Two
  "Spanish" rows with matching titles fell through every naming rule and
  stayed twins. They now fall back to the format (a PGS beside an SRT),
  and only to numbers when the formats match too -- the audio menu's own
  shape for indistinguishable rows.
- **A rejected embedded track no longer stays ticked.** Selection claimed
  the track before mpv confirmed it, so a file mpv could not take still
  showed selected with nothing rendering. The menu now rolls back to the
  previous state on a miss, and selection reads mpv's own reported track
  id instead of a list position that drifts whenever a pseudo-track is
  skipped.
- **Simkl Connect asks for write scope up front.** The device-code request
  sent no `scope`, and Simkl answers that with a read-only token instead
  of an error -- so Connect succeeded and every write after it
  (scrobbling, watchlist moves, ratings) failed silently while the card
  showed connected. The request now asks for `media:read media:write`,
  the token's own scope is checked before it is stored, and a `slow_down`
  backs the poll off instead of hammering the same interval. Verified the
  request shape against the live endpoint with a real client ID.

### Changed

- **More air between a section's title and its card row** (Popular, and
  every other movies/series/anime row app-wide -- one shared header). The
  loading skeleton's placeholder is kept in step so content doesn't jump
  down when it replaces the shimmer.
- **The centered ±30s seek buttons are gone; only play/pause stays over the
  middle of the video.** Every platform already has a better way to do the
  same jump: double-tap zones and keyboard seek on touch/desktop, and the
  transport bar's own seek bar on a TV remote, which nudges 10s and
  accelerates up to a full 2 minutes per press the longer Left/Right is
  held. The buttons were a second, bigger-only affordance sitting over the
  middle of the picture for something every platform could already do.
  Untested against a real touchscreen or a TV remote -- say if the
  remaining ways to seek do not cover a case these did.
- **Play/pause also lives in the bottom bar now**, right before the volume
  control, so reaching for the bar to adjust something else doesn't also
  require waiting for the centered overlay to reappear just to pause.
- **Holding J/L or an arrow key seeks faster the longer it's held** (10s →
  30s → 1min → 2min), the same ramp the seek bar's own Left/Right already
  had -- this is the keyboard's way to reach what the removed ±30s buttons
  used to give with a single tap.
- **Popup menus (speed, audio, subtitles, stats, sleep, aspect) sit closer
  to the transport bar.** The clearance above the bar was counting its
  cosmetic top gradient as space to avoid, when nothing interactive lives
  there -- tightened twice this round after the first pass still left a
  visible gap.
- Replaced Google Drive backup with Dropbox as the one configured cloud
  destination (see Removed) -- the app's own Dropbox app key is now set, so
  Connect actually works instead of showing "not set up yet."

### Removed

- **Google Drive backup.** Built alongside Dropbox, then dropped in favor
  of carrying one cloud provider instead of two -- see
  `docs/SYNC_AND_BACKUP.md`'s "Google Drive: built, then removed" for the
  reasoning. Auto-backup now tries Dropbox, then WebDAV.

- **Subtitle panel rows mark selection by highlight only.** Every row
  carried an unchecked radio circle by default, which read as a choice
  waiting to be made rather than a list to browse. The fill, edge and bold
  title already say which row is on; the audio menu keeps its radios.
- **Online subtitle file rows name the file, not the provider.** Rows read
  "Provider · SRT · …" -- the shop, not the goods. They now read the
  release title with its SDH/forced markers, falling back to the format
  where the title is empty or a bare download id.

### Added

- **`,` and `.` step one video frame back/forward**, YouTube's own keys for
  it. Routed straight to libmpv's `frame-step`/`frame-back-step` -- there is
  no sane way to reimplement frame-accurate stepping on top of a
  duration-based seek. J/K/L and the arrow keys already matched YouTube's
  own shortcuts before this; now listed together in Settings → Keyboard
  Shortcuts.

### Fixed (unverified)

- **Attempted another pass at the white flash when toggling fullscreen on
  Windows.** Bumped the hidden "let the engine catch up before showing"
  delay from 50ms to 150ms, on the theory that a decoding video needs more
  slack than an idle window to paint its first frame at the new size. Not
  confirmed fixed -- say if it's still visible.

## [1.9.5+53] - 2026-10-08

Subtitle panel buttons that react to a tap, Simkl as the one sync service (Trakt's paid-VIP gate made it impractical to keep offering), and confirmed Dropbox/Google Drive backups restore each other.

### Changed

- **The subtitle panel's buttons light up under a finger, a mouse and a
  remote.** The on/off button, the Embedded / Online tabs and the filter
  chips drew their own fill over the ink that would have shown a press, so
  hovering or pressing one changed nothing; the icon buttons in the header
  lit on hover and focus but not on a tap. Each now lifts on hover, lifts
  more while pressed, and shows the violet wash while a remote or keyboard is
  on it. Not confirmed on a TV.
- **Refresh is only there on the Online list.** It searches the online
  providers, so on the Embedded list it did something nobody could see.
- **Two embedded tracks of one language say which is which.** A full English
  track beside a "Signs & Songs" one, the usual anime release, both read
  "English"; the second now reads "English · Signs & Songs", from the file's
  own track title. A language with one track, or tracks whose titles say
  nothing beyond Forced / SDH / a region, are named as before.

### Fixed

- **Refresh showed as switched on, in violet, when the subtitle panel
  opened.** The panel takes focus when it opens, and with no back button (it
  now opens straight from the player bar) the first control was Refresh, so
  it wore the focus ring and one press of OK on a remote started a search.
  Focus now starts on the on/off button, and the cue is drawn only while
  someone is navigating with keys or a D-pad, not for a touch or a mouse.
- **Embedded Chinese tracks titled in Chinese all read "Chinese".** A track
  titled 简体中文 or 繁體中文 now reads "Chinese (Simplified)" or "Chinese
  (Traditional)".
- **A track tagged `mul` read "MUL", and a muxer's private `qaa`-`qtz` tag
  read as a language.** `mul` is now "Multiple", and the private tags fall
  back to the track's own title.
- **A track whose only title was "Forced" or "SDH" was named "Forced"** with
  a Forced chip beside it. It now reads "Track N · SRT" with the chip.

### Changed

- **Simkl is the one sync service the app offers; the Trakt card in
  Settings → Sync is switched off.** Registering a *new* Trakt API app now
  needs a paid VIP subscription, which makes it impractical to offer next to
  Simkl's free one. Decided, not removed: `TraktService`, `TraktSettings`
  and the pasted-credentials path are unchanged, and turning the card back
  on is one constant (`_traktSyncEnabled` in `sync_settings_page.dart`) for
  whoever ends up with a working Trakt app.

### Fixed

- **Confirmed Dropbox and Google Drive restore each other's backup.** Both
  already went through the same `BackupService` envelope and the same file
  name by construction; a new test
  (`backup_cross_provider_compatibility_test.dart`) now pins both the shared
  name and that Drive's multipart upload never alters the envelope's bytes,
  so a drift here fails a test instead of a restore.

## [1.9.4+52] - 2026-10-07

### Added

- **An anime episode's rail card shows its own art and name**, where AniList
  has them (it does for some shows, not most) -- a thumbnail and a title
  under "EP N", the same shape as the Series rail's TMDB stills. Falls back
  to today's plain numbered card wherever AniList has nothing to show.
  A sequel or split-cour season often numbers the data continuing the
  franchise's whole count (My Hero Academia's later seasons, Solo Leveling's
  season 2 -- that season's own episode 1 is titled "Episode 159" or
  "Episode 25"), rather than restarting at 1 the way the season's own
  episode count does; the matching reads that offset back out of the data
  itself, so these still show art instead of silently missing every episode.
  A one-release-for-the-whole-run show (One Piece: a single AniList id for
  1000+ episodes) can carry a small, internally consistent but unrelated
  fragment instead -- 69 entries numbered 62-130, nowhere near this
  season's own episode 1 -- which an early version of this confidently (and
  wrongly) matched to episode 1, showing episode 130's art under it. The
  offset is now required to explain at least half of the season's own
  episodes before it is trusted at all, which this fails and a real season's
  data passes comfortably.
- **Video Quality, in Settings -> Video Player**: Good / Better / Best, each
  with its rough data cost per hour (0.38 / 1.40 / 6.84 GB), the way a
  streaming app's own data-usage setting reads. It is a sort bias, not a
  filter -- it decides which source the Sources list reaches for first on a
  title with more than one, never hides any of them. Defaults to Best, which
  sorts identically to the highest-quality-first order every build has
  always used, so nobody sees a change until they open the setting.
- **Dropbox backup, in Settings -> Backup**, alongside the existing WebDAV
  option: a PKCE connection (no redirect URI, so the code Dropbox shows is
  pasted back in, the same shape as Trakt's device code), then Upload/
  Download of the same backup file every destination writes. Needs a
  `DROPBOX_APP_KEY` this build does not carry yet -- see
  docs/SYNC_AND_BACKUP.md.
- **Auto-backup, in Settings -> Backup**: on by default once a destination
  is connected, backing up at app open if it has been a day/week/month
  (your choice) since the last one -- there is no background-task runner in
  this app, so "at app open" is what "automatic" can mean without one.
  Prefers Dropbox, then Google Drive, then WebDAV when several are
  connected.
- **Google Drive backup, in Settings -> Backup**, alongside Dropbox and
  WebDAV: Connect opens Google in the browser and the approval lands back
  in the app on its own (no code to paste -- Google retired that flow), then
  Upload/Download of the same backup file every destination writes, under
  the same name. Uses the narrow `drive.file` scope, so the app only ever
  sees files it created itself. Needs a `GOOGLE_DRIVE_CLIENT_ID` this build
  does not carry yet -- see docs/SYNC_AND_BACKUP.md. Auto-backup prefers
  Dropbox first, then Drive, then WebDAV. Untested against a live Google
  project -- say if the consent screen complains.
- **Trakt takes pasted API credentials, like Simkl and TMDB already do.**
  Every published build ships an empty `.env`, and a Trakt user cannot
  always register their way out of that the way a Simkl user can -- new
  Trakt apps need VIP. So the Sync card's dead-end note is now a working
  door: anyone holding a working Client ID + Secret (their own app from
  before the VIP gate, or the maintainer's) pastes both into the card and
  connects, no rebuild and no `.env` edit. The build's own keys remain the
  fallback when present.

### Changed

- **Casting carries on from where the phone was, and the phone goes quiet.**
  Every cast started at 0:00 and left the phone playing alongside the TV.
  The picker now starts the receiver at the player's position (not within
  the first 5 seconds, not within the last 15, and never for a live
  channel), and pauses the phone once the receiver has accepted the stream.
  While a session is live the picker shows a "Stop casting" row (nothing
  called `disconnect` before) and marks which device is the connected one.
  Not tried against a receiver.

### Fixed

- **A `.tsv` or `.tsx` file is no longer announced to the receiver as a
  transport stream.** `.ts` was matched anywhere in the path and query; it
  now has to be a whole extension.
- **The loading logo now actually fills.** It was cut with
  `Align(heightFactor)`, which the tight constraints of the `Stack` around it
  ignore, so the whole logo showed from the first frame and the progress was
  invisible. It is clipped to the filled fraction from the bottom now, and
  the test checks the visible rectangle instead of only that a clip exists.
  Not seen on a device.

- **Fullscreen toggle flash (Windows)**: entering or leaving fullscreen
  hides the window, changes its state, then shows it again, on purpose --
  that swap is the fix for an older shrink-then-grow flash (see 1.8.6). But
  Windows still played its own open/restore animation over that swap,
  which could show a blank or briefly stretched frame as the window
  reappeared, before Flutter had painted it at the new size. The window now
  disables DWM's transition animations for itself, and the hide/show swap
  waits a short moment before revealing the window, giving the engine time
  to paint the new size first. Untested against every Windows build and
  compositor setting -- say if it still flashes.
- **The Library's Collections / Continue / Downloads bar filled the header's
  full width**, with the three pills adrift in the middle of a near-empty
  capsule. Setting `alignment` on the capsule's `Container` to center its
  content made the whole `Container` -- border and fill included -- expand
  to fill its own parent instead; centering now happens around it instead,
  so the capsule hugs the pills. Shared by the IPTV sources page, which used
  the same row.
- **A rail's scroll arrows moved while you were clicking them.** Every
  horizontally scrolling rail (Home's sliders, Browse's rows, Continue
  Watching, and anime's cast/episodes/relations/recommendations) parked its
  arrow 60px past the edge and slid it in over 250ms on hover -- a pointer
  already moving toward where the arrow was about to land could click while
  it was still travelling. The six copies of this are now one shared
  `RailEdgeArrows` widget that fades the arrow in at a fixed position
  instead of sliding it, so there is nothing left to chase. It also gives a
  D-pad/remote proper `ExcludeFocus` on a hidden arrow everywhere, which
  three of anime's four rails were missing.

- **The anime episode rail's "Jump to ep #" box**: the hint text sat high in
  its fixed-height box and the go-arrow's own default 48px tap target (more
  than the whole 34px-tall box) forced the row taller than its border,
  which is the "looks off" a fixed-height box cannot hide on its own.

## [1.9.3+50] - 2026-10-04

### Changed
- **The transport bar is three buttons: stats, subtitles, and a gear.**
  Speed, audio, sleep timer and aspect shared the row before and crowded the
  per-scene choices on a narrow phone; now they live one tap behind the gear,
  each row carrying its current value so the menu also reads as status. The
  gear's dot says something in there is off-default.
- **Filter menus tick the active choice and cap their height.** Genre,
  decade, rating and sort pills mark the current value with a check, and a
  long list scrolls inside a fixed ceiling instead of running off the
  screen.
- **Every player control gets its own button; the gear is gone.** The bar
  is stats, speed, audio, subtitles, sleep timer and aspect -- each reached
  for mid-stream, each one tap. An earlier pass grouped the set-once ones
  behind a gear, but use pulled them back out one by one until the menu
  guarded only the rarely touched. Quality survives as the tappable badge
  beside the title, opening the Sources panel (a torrent has no in-stream
  variants -- each quality is a different release). Copy Stream URL moves
  into the stats popover beside the data it copies, freeing the top bar to
  episodes, download, fullscreen and cast. Volume stays a desktop tool,
  fullscreen leaves mobile and TV, and popovers clear the bar with visible
  air so the seek row's end time stays uncovered.
- **Audio and subtitle rows carry the file's own detail as chips.** Codec
  and channel layout for audio (E-AC-3, 5.1), format for embedded
  subtitles (SRT, PGS -- bitmaps ignore the appearance panel, so knowing
  which rows are bitmaps saves restyling the unstyleable). The language
  stays the lead; the container's own title stays out as the noisier
  spelling of the same facts.
- **A series with nothing watched offers its first episode by name.**
  "Play Episodes" never said which one; now it reads "Play S1 E1" and
  plays exactly that, mirroring the anime page's "Play Ep 1".
- **Anime episodes are an EP rail like Series, and the dead SUB/DUB bar is
  gone.** The switcher set a flag nothing read (the sheet was never told),
  while the sheet itself filters by SUB/DUB with counts and per-source
  badges. Episodes now scroll horizontally as numbered cards with the
  series rail's watched/current language and hover play, keeping the
  50-chunking and jump for long anime. Characters and Staff sit closer,
  as one credits group.
- **The player's popovers sit just above the playback line.** They used to
  clear only the buttons row, so a menu covered the seek bar it belongs to
  and the timeline could not be seen or scrubbed while one was open. The
  clearance now mirrors the transport bar's own build, so the card reads as
  attached to the timeline. Not seen on a device.
- **Series episode cards mark watched and current like the anime grid.**
  Finishing an episode dims its card and accents the furthest one reached,
  read live from the same history log, so rewatching shows where you were
  on both kinds of details page.
- **The series Play button resumes like the anime one.** It always said
  "Play Episodes" and started over; now it names the furthest started
  episode and continues there.

### Added
- **Home rows can be toggled per section.** Films, Series and Anime each get
  a row manager under Appearance, shaped like the Live TV category manager:
  everything shows by default, a checkbox hides a row, and rows from newly
  installed catalogs appear until hidden. Series also gains the
  Documentaries shelf, and Films and Series gain a Coming Soon rail for
  dated unreleased titles -- all derived locally, no new fetches.
- **Stream statistics in the transport bar, ahead of the speed button.** A
  torrent reports its swarm the way a client does -- download speed, peers,
  how much has arrived and the info hash -- while an HLS playlist or a plain
  HTTPS stream reports its host and how much is buffered instead. The swarm
  poll starts when the panel opens and stops when it closes. Not seen on a
  device.
- **A fullscreen button in the player's top bar, next to Download.** The
  icon follows the window itself, so F11, a double-tap and the button never
  disagree about which way the window is.

### Fixed
- **A series details page opens on Season 1, not the specials.** The opener
  picked the lowest season number, so a show with extras landed on Season 0
  -- which most shows carry little or nothing for, reading as an empty
  episode rail. Season 0 still exists in the data but is never shown as
  "Season 0": it gets a pill of its own labeled Specials, here and in the
  player's episode panel, while the numbered list starts at 1. Only a title
  with nothing else still opens on what it has.
- **The details rails fade the correct edge in right-to-left layouts.** The
  edge-fade gradients never received the reading direction, which threw at
  paint time in debug builds and silently faded the wrong side in Arabic
  release builds.
- **Audio rows show their flag, not the globe, for raw mpv tags.** Tracks
  carry codes (`eng`, `spa`) while subtitles carry names ("English"), and
  the flag lookup only knew names -- so the same language drew a flag in
  one menu and a globe in the other. Codes normalize through the shared
  language table first now.
- **Fullscreen toggles without the shrink-then-grow flash.** Entering left
  through unmaximize-then-fullscreen with the window visible, painting every
  size between; both directions now flip while briefly hidden, so it reads
  as one cut.

## [1.9.2+49] - 2026-10-03

### Changed
- **The player's menus come in the shape each screen is good at.** Subtitles,
  audio, speed, volume, sleep timer and aspect were one 20 rem card anchored
  bottom-right whatever they were shown on, so on a phone the subtitle list was
  squeezed into what the video left, and on a TV it was a small card at the edge
  of a large picture. They are now (`playerPanelStyleFor`, `PlayerSheet`):
  - **a bottom sheet** on a phone held upright (or any narrow upright window),
    the full width, up to 88% of the height;
  - **a side sheet**, the full height, over a dimmed video, on a phone on its
    side, a tablet and a TV (about 42% of the width, 22-32 rem);
  - **the popover as before** on a pointer in a wide window (desktop).
  The subtitle list takes the whole sheet. The sheet draws the surface, the
  menus inside just lay out, and a menu still takes focus when it opens.
  Not on a device yet: all of it is tested in widget tests only, and the
  breakpoints (upright and under 900 wide, touch, TV) are a first guess.
  **Closing**, decided per shape rather than the same everywhere:
  - a bottom sheet has a **grabber** and a **drag down**, plus a tap on the
    scrim and Back; no X (it would sit where a thumb has to cross to reach the
    list, and the grabber already says "pull");
  - a side sheet on a **touch screen** has an **X** in a strip of its own at the
    top, a **swipe toward its edge** (left in a right-to-left layout), a tap on
    the scrim and Back, since a side panel has no grabber to suggest the swipe;
  - a side sheet on a **TV** has none of those: Back closes it, an X would be one
    more stop for the D-pad, and a swipe means nothing.
  A drag past a third of the way, or a fling, sends it away; less springs back.
  The popover and the episodes and sources panels (already full-screen on a
  phone) are unchanged.

### Added
- **The player's loading screen is the app logo filling up, without a percentage number.**
  It replaces the title logo pulsing over a backdrop. The bar only moves
  forward: it jumps to a mark for each step it can name (asking for the
  stream, resolving it, handing it to the player) and then fills the rest
  from real numbers, mpv's buffer and, for a torrent, TorrServer's preload.
  The screen now stays up until the first frame is decoded (the old one went
  away when mpv *accepted* the URL, leaving a black video while it buffered),
  with a 45 s safety so it can never hide a picture for good. The logo fills
  progressively like Stremio; the controls still work underneath, so you can
  back out. Live TV now uses the same loading treatment while opening and
  buffering a channel. Not yet seen on a device.

### Fixed
- **Cast waits for the receiver before sending media.** The plugin reports
  success as soon as it requests a connection, before the receiver session
  exists; media was therefore sent too early. Cast now waits up to 20 seconds
  for the connected event. The picker stays open while connecting/loading,
  prevents duplicate attempts, and shows a translated retry message if the
  receiver rejects or times out. WebM URLs are sent with their actual content
  type instead of being mislabeled as MP4. Not yet confirmed against a real
  receiver; streams requiring Referer/User-Agent headers remain unsupported
  by the Cast SDK path.
- **The Android playback notification's Play/Pause now follows the player.**
  The coordinator only learned the player had paused when a position tick
  arrived, and a paused video sends none, so the notification kept showing
  Pause and pressing Play was ignored as "already playing". The player now
  reports play and pause as they happen, and the notification's Play and
  Pause call the player directly. Also, Android 13+ hides every notification
  until `POST_NOTIFICATIONS` is granted and nothing asked for it, so the
  notification may never have appeared there; the app now asks on launch.
  Not confirmed on a device.
- **"Similar Content" on the detail pages loads again.** It depended on one
  scraped site alone. It now asks TMDB first (its recommendations, then
  similar titles) and falls back to the old source. The parsing is tested
  offline; the live request is not (the build sandbox could not reach either
  service), so check a movie and a series on a device.
- **Posters in a collection (and the catalog and anime grids) are portrait
  again.** The grids gave every card a fixed shape (0.62), but a card is a
  poster plus a fixed block of text, so on a phone's three columns the text
  ate the poster down to nearly square. The cell height is now worked out from
  its width (`posterGridDelegate`), keeping the poster 1:1.48.
- **The player's D-pad reaches everything on the TV (#80).** Device testing of
  v1.9.1 found four things, now fixed (not yet confirmed on a TV):
  - **The audio, speed, sleep timer and aspect menus could be opened but not
    used.** Focus stayed on the button that opened the menu, so the arrows went
    to whatever was nearest that button (the seek bar), not to the menu's rows.
    A menu now takes focus when it opens (`PlayerMenuAnchor`), keeps the arrows
    on its own rows until it closes, and its rows show the focus wash even when
    selected.
  - **The volume could not be changed or muted.** Its slider claimed the arrows
    a remote moves around the bottom row with, so it could neither be used nor
    left. On a TV the bottom row has a volume button instead, which opens a
    panel like speed and audio do (`PlayerVolumeMenu`): the slider takes focus,
    Left/Right change the level through the boost range (to 250%), OK mutes and
    unmutes, Back closes it; the panel says so on a TV. The Live TV player does
    the same. Off a TV the bar keeps its slider. The buttons beyond it (speed,
    audio, subtitles, sleep timer, aspect) can be reached with Right.
  - **Seeking with the arrows showed no change.** Ten seconds is about a pixel
    on a two-hour bar. A key seek now moves the thumb at once and shows the new
    time in the bubble for a moment; a held key goes in growing steps (10 s, 30 s,
    1 min, 2 min) and commits when it pauses.
  - **Up from the seek bar had an extra stop before play/pause.** Directional
    traversal picks the nearest control above a full-width bar, which was a seek
    button when the bar was reached from the side. On a TV the hops between the
    rows are named: Down from the centered buttons is the seek bar, Down from the
    bar is the volume button, Up from the bottom row is the bar, Up from the bar is
    play/pause.
  Also: any key press now keeps the bars up another four seconds, including
  the ones a control handles itself, which never reached the timer before and
  let the bars vanish mid-press.

## [1.9.1+48] - 2026-10-01

The TV polish release: everything the first Android TV device tests of
v1.9.0 turned up -- the icon-rail side menu, the player's bars and D-pad,
focus cues on every kind of control, a poster that leaves room for Play --
plus the whole `rem` size migration, so a larger text size now scales gaps,
bars and buttons along with the text. Driven on a TV through the dev builds (up to
v1.9.0-dev.7); the changes after that (the second focus pass, the poster,
the chips) have not been seen on a device.

### Added
- **The app now has a proper Android TV banner (#78).** Device testing of
  v1.9.0 found the app listed on a TV's home screen, as intended, but with
  the square phone icon stretched into the banner slot instead of a real
  wide card -- `android:banner` was never set. Added a generated
  320x180-and-up banner at every density (`res/mipmap-*/banner.png`),
  composited from the app icon plus a "PlayTorrioMov" / "Home for Cinema"
  wordmark in the icon's own two-purple gradient, and wired it up in the
  manifest.

### Changed
- **Search has the same three filters on Films, Series and Anime.** The type
  chips (All, Movies, Series, Anime) are joined by a decade menu and a minimum
  rating menu, the same on every type; anime used to be the only one with a
  menu (a genre list). They are the two filters every catalog can answer --
  addons' search results carry a name, poster, year and rating but no genres,
  so a genre filter would have worked for anime and quietly matched nothing
  elsewhere -- and they are applied to the results that came back, so changing
  one is instant. A title that does not state its year or rating is left out
  while that filter is on. The row stays on one line at every width: it
  measures the words and uses the widest of three layouts that fits
  (everything in words; the type in words and the menus as icons; everything as
  icons, with the names as tooltips and semantics labels). Test fonts are wide,
  so the real breakpoints on a device are narrower than in the widget tests.
  Removed: the anime genre menu on Search.
- **Settings rows show which one the remote is on (#80).** Settings tiles are
  an `InkWell` over an opaque container, so the `InkWell`'s own focus tint was
  painted underneath the container and never seen: a D-pad moved down a
  settings page with no cue at all. The ten tiles and cards in the settings
  pages (categories, appearance, decoders, buffer presets, About links, the
  Trakt/Simkl code, the add-on toggle) now draw a soft violet wash, with no
  border, over themselves (`FocusFill`). The theme also gives every control that takes its
  cue from it a visible one -- list tiles, checkboxes, radios, switches and
  slider thumbs a 30% tint of the palette color, dialog and form buttons a
  clear wash. Not confirmed on a TV.
- **Back peels one layer at a time in the players (#80).** Back used to leave
  the player outright, so on a TV a remote's Back with the subtitle panel open
  threw away the film instead of the panel. Now one press closes whatever
  panel or menu is open (subtitles, audio, speed, sleep timer, episodes,
  sources, sync); with nothing open and the bars showing, a TV's Back puts the
  top and bottom bars away; with those away, the first press shows "Press Back
  again to exit" and a second within two seconds leaves. Off a TV only the
  first layer applies (a phone's Back or Esc closes a panel, then leaves).
  Esc on a keyboard follows the same ladder. The decision is a pure function
  (`decideBackPress`) with a test per row; the Movies/Series/Anime player and
  the Live TV player share it. A widget test also holds that the D-pad can
  walk from play/pause down through the seek bar to the bottom row and back.
  Not confirmed on a TV.
- **The genre, catalog and category chips show where the remote is (#80).**
  Discover and Catalog's genre/catalog chips, the Live TV search categories,
  the magnet file filters and the anime adult toggle drew a ring around the
  chip, which a scrolling row has no room for and which is the same violet as a
  selected chip. Focus now lightens the chip inside its own bounds (new
  `HoverButton.focusFillRadius`). The library and Live TV sources tabs and the
  Settings choice chips, whose own focus tint is a few percent of the text
  color, got a stronger tint and the soft wash respectively. Not confirmed on a
  TV.
- **The details poster no longer pushes Play off a TV screen (#80).** The
  poster column was a fixed 17.5 rem wide and the poster 2:3, so it was always
  26 rem tall: on a 960x540 TV layout it filled the screen and left the Play
  button under it at the bottom edge. The poster now gives up width to keep
  Play and the library row on screen (down to a floor), centered above the
  full-width buttons. A window tall enough for both is unchanged. Movies/series
  and anime details share it (`DetailsPosterFit`). Not confirmed on a TV.
- **TV focus cues, second pass (#80).** Device testing of dev.7 found five
  things, now fixed (not yet confirmed on a TV):
  - The side menu's violet border hugged the icon and left its name outside
    it; it now surrounds the icon and the name together, with a faint violet
    fill.
  - Details' play button drew a pill-shaped ring around a rounded rectangle, so
    the two never lined up. It has no ring now: it grows, brightens and glows
    in its own colors. The same mismatch was in twenty other buttons that wrap
    a rounded rectangle (cards, chips, hero dots, search and library buttons);
    their ring now follows the button's own corner radius.
  - The filter pills, Search and Settings showed focus with a hard ring that
    was hard to tell apart on a row of pills. They now get a soft violet wash
    behind them and a slight lift, painted outside the pill's box so the row
    does not shift as focus moves along it.
  - The player's seek bar has no border when focused: the bar turns a stronger
    violet, thicker, with a violet thumb. Left/Right still seek, and holding
    them repeats.
  - On a TV the volume is one stop: Left/Right change the player's own level
    (0-250%, boost above 100%, separate from the TV's volume that the remote's
    volume keys change), holding repeats, and OK mutes and unmutes. Up and Down
    are no longer taken by the slider, which had made it a trap: all four
    arrows were spoken for, so a remote that reached it could not leave.
- **The TV side menu rests as a rail of icons and opens on focus (#80).** The
  first device test confirmed it works; the feedback was that a permanently
  wide menu takes room from the posters. It is now a narrow icon rail
  (`AppRem.menuRail`) that opens into the labelled panel while the remote is
  inside it, over the content rather than pushing it, and closes when focus
  leaves. Only the icon pills take focus (the labels hang outside them), so a
  wide item cannot sit over the first card's column and make Right skip it.
  Hidden behind a button was the other option: it needs a first press just to
  find the menu. Not confirmed on a TV.
- **Poster cards lose the focus ring (#80).** A focused card already scales up
  and lifts, and the violet ring on top only covered the poster. The ring stays
  on pills, header icons, the menu and the hero buttons, which do not move.
- **Watch Sources rows show the release's file name and fewer tags.** The
  row's title is the release's own file name again (up to two lines), with the
  site under it; the tags are down from as many as eight to quality, HDR, a
  torrent's seed count, size and audio language. Container, release source,
  codec and P2P/HTTP are in the file name. The in-player sources panel and the
  anime episode sheet follow: `sourceDeliveryBadges` no longer emits the gray
  P2P/HTTP pill (it told nobody anything), leaving just a torrent's seed-health
  count, and the anime sheet drops the empty row a direct link would leave.
  New `StreamSource.releaseName`.
- **The player's remote-key decision is a tested function.** What an arrow or
  OK means to the player on a TV (bars back, Left/Right seek while hidden,
  first arrow to play/pause) moved out of `PlayerScreen`'s key handler into
  `decideRemoteKey` (`remote_key_decision.dart`), with a test per row. No
  behavior change; it is the part that regressed silently before, and a test
  that pumps the whole screen cannot see it. Not confirmed on a TV.
- **Sizes are `rem` and named tokens, done in batches.** The code
  measured layout in bare numbers (`SizedBox(width: 12)`, `height: 40`), so a
  larger text size grew the text and left every gap, bar and button where it
  was. `lib/services/app_units.dart` adds `context.rem(AppRem.md)` (one rem is
  16 logical pixels at the default text size and follows the user's text size,
  clamped to 0.85-1.3), the `AppRem` tokens and `AppType` font-size constants
  (not scaled twice). This first batch migrates the side menu, the hero
  Play/Details buttons (now `HeroActionButton(compact:)`, callers pass no
  numbers) and the focus helpers, and `test/units_no_raw_pixels_test.dart`
  fails on a bare size in any migrated file. The second batch moves the hub
  chrome: top bar, section chips, filter dropdown, header pills and section
  headers (`TopBar.height` is now optional and defaults to `AppRem.bar`).
  The third finishes the chrome: the phone's bottom tab bar, the pill filter
  bar, the music mini-player bar and the logo. The mini-player's height is a
  floor now, so its text can grow. The fourth moves the poster cards and rows:
  `MovieCard`, `AnimeCard`, `BrowseRowView`, `BrowseScaffold` and the card
  sizing (`MovieCardSizing.of(context)` / `fromWidth(width, scale:)`, and
  `sizingOf` now also receives the text-size factor), so a card's bounds, its
  text block and the row gaps follow the text size; at the default size they
  are the same 108-168 px as before. The fifth starts the pages with the movie/series
  details page (its spacing scale and every size are rem now; its credit and
  similar cards are separate widgets and not yet migrated). The sixth does the
  anime details page the same way; the two pages now share one set of sizes
  (`lib/widgets/details/details_metrics.dart`) instead of each keeping a copy.
  The ninth and last does everything still in pixels (the remaining pages and
  widgets), and the guard test now scans all of `lib/pages` and `lib/widgets`
  instead of a list, with no file exempt: the three widgets whose height is a
  measured budget (the credit and similar cards, the Continue Watching band)
  take the text-size factor, and `BrowseScaffold`'s `belowHeroExtent` now
  receives it too. The eighth does settings and
  the update/P2P dialogs (every page under
  `lib/pages/settings`, `lib/widgets/updater`, `lib/widgets/p2p`). The seventh
  does the video player: every widget in `lib/widgets/player`, both
  player pages and the Live TV player. `AppType` is now a half-step ramp, and
  the player menus' shadow lists are functions of the context
  (`PlayerTheme.menuShadowOf`) because their sizes are rem. The rest of the
  code is not migrated yet; see the roadmap. Unverified on a device: the hero
  buttons and side menu keep their look at the default text size apart from a
  few pixels (the anime Play button is now the same size as the movie one).
- **Poster cards are smaller, and no longer plateau at one flat size on a
  wide window (#80).** Real-device feedback said cards were "very big" even
  at the default (100%) text size, which rules out the text-zoom slider as
  the cause -- this is the card grid's own sizing. `MovieCardSizing` and
  `IptvCardSizing` each carried a step table of five or six fixed pixel
  widths (138-205px and 145-205px); both landed on the same flat, largest
  value for *any* window 1400px and up, a desktop browser and a TV alike,
  and nobody had checked that value against an actual TV before now. Both
  now compute width as a continuous fraction of the available width instead
  (`AppSpacing.cardWidthForScreenWidth`), clamped between 108px and 168px --
  smaller at every size than the old tables, and no longer capped at the
  same number for an arbitrarily wide window. The details page's Related
  and Similar rows, which had their own separate isDesktop-or-not two-value
  guess, now compute from the same shared formula instead of a third
  set of numbers. Unverified against a real TV or a real 100%-zoom desktop
  window -- the old sizes were only ever confirmed too big by the report
  that prompted this, not measured against a specific target, so what
  "right" looks like here still needs eyes on an actual screen.

### Fixed
- **The video player showed no bars on a TV and only paused (#80).** Its
  controls appeared on pointer movement, which a remote does not produce, so
  after the first four seconds they were gone for good and OK only toggled
  play. Any arrow or OK now brings them back and keeps them up; with them
  hidden, Left/Right seek 10 s (as a streaming app's remote does) and Up/Down
  show them; with them up the first arrow lands on play/pause. Hidden controls
  no longer take focus, which is how a remote ended up moving between buttons
  nobody could see. The Live TV player reveals its controls the same way and OK
  toggles play there too. Not confirmed on a TV.
- **A TV gets a side menu instead of the top bar (#80).** Two rounds of
  hand-bridging the top bar from the content (`TvFocusBridge`) did not work on
  a real remote, while ordinary traversal inside the content did. The bar sits
  outside the content's `Navigator`, and each route's focus scope is a wall
  traversal cannot cross, so the fix is to stop crossing it: on a TV the
  sections, Search and Settings are a vertical `TvSideMenu` built *inside* the
  content route, in the same scope as the rows. Left from the first card of a
  row reaches it, Up/Down move through it, OK switches section, Right returns.
  The top bar and the phone's bottom tab bar are not drawn on a TV.
  TV detection also now counts the `leanback` and `television` system
  features, not just the UI mode, which some boxes do not report. The bridge
  stays for keyboards on other platforms. Covered by widget tests
  (`tv_side_menu_test`); not confirmed on a TV.
- **Focus is now visible on filter pills, Search and Settings (#80).** The
  header pills' dropdowns, the Search and Settings buttons and the
  icon-only header pill had only Material's faint focus overlay, which
  vanishes on a translucent pill or a dark bar. `FocusHighlight` draws the
  same accent ring the rest of the app uses around them.
- **Cards no longer carry a Movie/Series/Anime label over the poster.** The
  movie card faded a type badge in over the top-left of the poster whenever it
  was hovered or focused, hiding a corner of the artwork exactly when someone
  was looking at it; the anime card's permanent format pill did the same on
  the other corner. The type is already the second line under a movie card,
  and the format is the second line under an anime card when it has no genre.
- **The top bar still could not be reached, and the hero's Play/Details
  buttons showed nothing under the remote (#80).** Device testing of
  `v1.9.0-dev.3` moved through Films rows but not out of Films. Three fixes:
  - `TvFocusBridge` no longer depends on `TvModeService.isTv`, which
    evidently did not hold on that box; it now yields only to a focused text
    field and to an open popup menu or dialog.
  - The hero's Play/Details pair were Material `ElevatedButton` and
    `OutlinedButton`, whose only focus cue is a faint overlay that vanishes on
    a saturated fill over a photo. They are now `HeroActionButton`, built on
    `HoverButton` like every other target: explicit select/enter, the lean,
    and a focus ring sized to the button. Movies, Series and Anime.
  - The hero's and rows' scroll arrows are parked off-screen until a pointer
    hovers, but stayed focusable, so a D-pad could land on an invisible
    arrow. They are excluded from focus while hidden.
  The dropdown menu opened from a header pill now uses the pill's corner and
  edge (10px, the pill's border) instead of a rounder, borderless box.
  Unconfirmed on a TV.
- **A TV remote can now reach the top bar's section chips, and get back
  (#80).** The content sits in its own `Navigator`, and each route has its
  own focus scope, which directional traversal cannot cross. `TvFocusBridge`
  wraps the hub's chrome and content: on TV, Up/Down first try the ordinary
  move (`focusInDirection` reports whether it worked) and only when that
  fails hand focus across, Up from the top of the content to the nearest
  chip and Down from the bar to the first row below it. In-content
  navigation is never second-guessed, and off TV it does nothing. Covered by
  a widget test on the same shape (chips above a nested `Navigator`); not
  confirmed on a TV.
- **Up and Down still did nothing on a TV, in every catalog row (#80).**
  The cacheExtent change did not fix it because the cause was elsewhere:
  `BrowseRowView` wraps every row in `FirstFocusScope`, which built a real
  `FocusScope` around each row. Directional traversal only considers the
  nodes inside the focused node's nearest scope, so every row was an island
  the D-pad could move sideways within and never leave. `FirstFocusScope`
  now anchors its subtree with a plain non-focusable `Focus` instead, so all
  rows share the page's scope and Up/Down reach the neighboring rows. This
  also puts the grids' filter chips in the same scope as their cards. A new
  widget test presses Right then Down across two wrapped rows. Not confirmed
  on a TV yet.
- **A real remote could barely navigate the app at all (#80).** Device
  testing of v1.9.0 on an actual TV found several D-pad problems the
  earlier phases' testing (all done by reading code, not by using a
  remote) had missed:
  - **The player swallowed every arrow-key press for volume/seek.** A
    screen-wide key handler claimed arrowUp/Down/Left/Right unconditionally
    for volume and ±10s seek, so a D-pad could never move focus onto any of
    the player's own buttons -- including the volume slider, which already
    had its own correct left/right-to-adjust handling that this outer
    handler never let a D-pad reach. Those four keys now fall through to
    normal focus movement on an actual TV (`TvModeService.isTv`); off TV
    they keep the existing desktop-player convention unchanged. The
    hardware volume keys and J/K/L (VLC's seek/play keys) are unaffected
    either way.
  - **OK/center could not pause or play.** The same handler answered Space
    and K for play/pause but never the D-pad's actual center-button key
    (`LogicalKeyboardKey.select`) or a gamepad's A button. Added as a
    fallback alongside the existing shortcuts.
  - **The top bar's section chips didn't respond to OK.** Unlike every
    other D-pad-activatable control in the app (`HoverButton`,
    `InteractiveCardShell`, the player's own buttons), the chip switcher
    relied on `InkWell`'s own default key handling instead of the explicit
    select/gameButtonA wiring everything else uses. Rebuilt on the same
    `Focus` + explicit key handling pattern as the rest of the app.
  - **Only the first catalog row was reachable.** `BrowseScaffold`'s
    `CustomScrollView` used Flutter's default 250px cache extent, so a row
    more than about one screen down was not laid out at all yet -- nothing
    for directional focus traversal to find there, regardless of which key
    was pressed. Raised to 2000px, and `HoverButton`/`InteractiveCardShell`
    now scroll a newly focused item into view
    (`Scrollable.ensureVisible`) as focus moves, so the viewport keeps
    advancing (and laying out further rows) as a D-pad user works down a
    page instead of only ever seeing what was already on screen.
  - **Cards were hard to tell apart from unfocused ones at a couch's
    distance.** Every poster/channel card (`InteractiveCardShell`) relied
    on a ~4% hover-lean alone as its focus indicator, judged enough during
    earlier, non-device-tested work; real testing said otherwise. Cards now
    also get the same `FocusRing` border every icon/text target already
    uses.

  **Not resolved by this pass, and flagged rather than guessed at:**
  whether a D-pad can reach the top bar's section chips *from* the content
  area (as opposed to the chips now correctly responding to OK once
  reached) is still unconfirmed. The content area renders inside its own
  `Navigator`/`FocusScope` (`NestedNavigator`), which may bound directional
  focus traversal to that scope and prevent it from ever considering the
  persistent chrome outside it as a candidate -- a real gap if so, but one
  that needs a device to confirm before attempting a fix that could just as
  easily make in-content navigation worse.

- **"Watch Sources" packed three more focusable targets into every source
  row on TV (#80).** Real-device testing found the copy-magnet, download,
  and decorative play-chevron icons on each `_SourceCard` were three extra
  D-pad stops per row, on top of the whole card already opening the source
  when pressed -- the same kind of confusion the rest of this pass's fixes
  were about removing. All three are now hidden on TV (`TvModeService.isTv`);
  a card's only action there is itself, tap to play. Download and
  copy-magnet stay reachable from inside the player once a source is open,
  so nothing is lost, only the couch-distance action row is. The sources
  panel is also widened from a 40% to a 50% share of the desktop-tier
  layout on TV, since the per-source badges are what's left to read at
  couch distance once the icon row is gone.

- **Six more fixed heights around text now grow with the text scale (#69).**
  The watch-screen filter pill, the cast sheet's device row, the
  subtitle-sync step buttons, the episodes panel's sources button and the
  Sources & Filters rank badge were `height:`/`width:` boxes around a label;
  each is now a `minHeight`/`minWidth` floor with the same size at 1x, so a
  large text scale grows the box instead of clipping the text. The search
  page's type-chip rail sits in a horizontal `ListView` that needs a bounded
  height, so it takes the text-scaled height (still 44 at 1x) instead. A
  re-scan of `lib/` found these were the only ones wrapping text; the rest
  of the old "~42 files" estimate wrapped icons, images or spinners.
  Unprobed: these were changed by reading, and `text_scale_overflow_test`
  was not extended to cover them.

- **Chip and card rails now grow with the text scale (#69).** Ten
  horizontal rails sat in a fixed-height `SizedBox` (Catalog's two filter rows,
  Anime Search's filter row, Search's type chips, the seasons row, Live TV's
  category pills, the anime cast and staff rows, and the anime relations and
  recommendations cards), which clipped their text at 2x-3x. They take
  `AppSpacing.textScaledHeight` instead: unchanged at 1x, larger with the
  text scale. Unprobed: `text_scale_overflow_test` does not cover them.

### Removed
- **The separate Anime search page is gone: anime is searched in the one
  search.** Search already asked AniList alongside the addons and offered an
  Anime chip with a genre menu; the Anime Filters button led to a second page
  with its own search box, 18+ gate, season/format/status/sort/year pickers
  (bottom sheets that slid up from below) and a duplicate set of rows. All of
  it (`AnimeSearchPage`, about 870 lines, and its test) is removed, along with
  that button and the anime row's "See all". What remains is one search box,
  the type chips, and the genre menu under the Anime chip (a popup, not a
  sheet). Not kept: season, format, status, year and the 18+ browse. The
  strings only that page used are still in the ARB files, like the 80-odd
  other orphans listed by a scan; they are a separate cleanup.
- **The Profile tab's own Settings button is gone again.** v1.9.0 gave the
  renamed Profile tab a second Settings entry point in its own header,
  alongside the existing global gear in the top bar. It just duplicated a
  screen already one tap away everywhere else, and on a TV cost an extra
  D-pad hop for nothing the always-visible gear didn't already cover.
  Settings stays reachable exactly one way: the global icon next to Search.

## [1.9.0+47] - 2026-09-28

The Android TV release. All four phases of #80 land here: detection, type
scaling, sheets-to-full-screen on TV, and focus order/indicators -- plus a
nav reorganization (Profile tab, global search) that shipped alongside it.
Nothing in this entry has been driven on a real Android TV or Android TV
emulator; see each item's own note on what was and wasn't verified.

### Added
- **The app declares Android TV support, and the player transport and watch
  screen respond to a D-pad or a keyboard (#78).** The manifest gained the
  leanback feature and launcher category needed just to appear on a TV.
  `PlayerIconButton` -- play/pause, seek, volume, every transport button --
  now takes focus and shows the same `FocusRing` two of its neighbours
  already used; `HoverButton`, the shared wrapper the details rails and
  cards use, now does the same for everything else, reusing its hover lean
  as the focus indicator. `watch_screen.dart` was the first file converted;
  the sweep has since covered every remaining bare `GestureDetector` in
  `lib/`: the rest of the player transport (seek bar, volume, episodes and
  sources panels, subtitle sync bar), the shared `InteractiveCardShell` (so
  every movie poster and IPTV channel card on the catalog grids gets focus
  for free), `AnimeCard`, the hub's hero-carousel page dots, the
  Details/Anime Details/Catalog/Discover/Search/Collection/Library/Addons
  pages, the IPTV channel sheet, portal browser and multiview/timeshift
  player, the Universal Play Bar, the Continue Watching card, the IPTV
  hero slide, and the remaining smaller shared widgets. A handful of
  gestures were deliberately left pointer-only (full-screen tap-to-reveal
  surfaces, tap-outside-to-dismiss barriers, and one `onLongPress`) because
  a D-pad has no equivalent action for them -- see the roadmap for exactly
  which and why.
- **Grids and result lists land focus on their first card, not the chrome
  above it (#80).** `BrowseScaffold`'s hub pages (Films, Series, Anime, Live
  TV) already skipped the auto-rotating hero to focus the first row; the
  same one-shot landing, extracted into a shared `FirstFocusScope`, now
  covers the Catalog, Discover, Search, Collection, Library shelf, IPTV
  search and portal browser, Anime and Anime Search results, and the
  multi-view channel picker. A D-pad or keyboard viewer opening any of
  these no longer has to hunt for the first navigable item.
- **Small and plain focus targets get a real ring, not just a lean
  (#80).** `HoverButton` reused its hover-scale as the focus cue by
  design, but a ~4% lean is easy to miss on a bare icon or a short line of
  text, especially at TV viewing distance. `FocusRing` (previously
  player-only) moved to `lib/widgets/common/` and `HoverButton` gained an
  opt-in `showFocusRing` flag, now set on all 37 icon-only, text-only and
  icon+text `HoverButton` targets across the app -- scroll arrows,
  favorite toggles, filter chips, the season selector, sub/dub and Play
  buttons, and more. The 5 targets that wrap a poster, backdrop or other
  card keep the lean alone, where it already reads clearly. This closes
  out #80's phase 4.
- **The app knows when it's actually running on an Android TV, and the
  smallest labels size up for it (#80).** `TvModeService` asks Android's
  `UiModeManager` over a platform channel at startup -- not a width guess,
  which would also fire on a wide tablet or a desktop window. On a real TV,
  `TvType.scale()` multiplies a badge or label's `fontSize` by 1.4 wherever
  the app had one under 11px (a source's codec badge, a channel's LIVE
  marker, an episode number, a rating pill, and 49 more, found by auditing
  every `fontSize:` in `lib/`) -- illegible from a couch is now merely
  small. Off Android, nothing changes.
- **Bottom sheets push as full-screen pages on TV instead (#80).** A modal
  sheet dismisses by a drag gesture or a tap outside it, neither of which a
  D-pad/remote can produce; a normally pushed route already answers to the
  remote's hardware Back button like every other page in the app. The new
  `showAdaptiveSheet` is a drop-in replacement for `showModalBottomSheet`
  that checks `TvModeService.isTv` and pushes via the app's existing
  `pushPage` on TV, unchanged otherwise; all 8 call sites (the anime stream
  sheet -- now behind its own `AnimeStreamSheet.show()` factory so its
  three call sites share one control point -- the IPTV channel sheet,
  collection picker, Cast device picker, the anime search filter picker,
  and the IPTV portal's category sheet) now go through it. Each sheet's own
  layout is unchanged, so on TV it may still show as a rounded-corner panel
  rather than full-bleed content -- the dismiss gesture was the actual
  functional problem, and it's now solved either way. This closes out
  #80's phase 3; all four phases are complete.
- **The Library tab is now Profile, search moved to the top bar, and
  Settings is reachable from within it too.** The hub's fifth section kept
  its content (Watchlist/Watched/Liked shelves, Continue Watching,
  Downloads) but is now labeled Profile with an account icon, and gained a
  Settings button in its own header -- alongside the existing global gear
  in the top bar, not instead of it. Search used to be four separate
  buttons, one embedded in each of Films/Series/Anime/Live TV's own header
  (repeating the same icon, and invisible from Profile, which never had
  one); it is now one `SearchIconButton` in the top bar next to Settings,
  present on every section including Profile, opening the unified
  `SearchPage` everywhere except Live TV, which keeps its own
  keyword-in-portal search (`IptvSearchPage`) since it isn't a title
  catalog. `PageSearchButton`, now unused, is deleted.

### Fixed
- **A departing episode card could no longer steal focus mid-transition
  (#80).** The Details page's season switcher keeps the outgoing season's
  episode row in the tree while it fades out, and it was still reachable by
  D-pad or Tab during that 550ms window. Its outgoing children are now
  wrapped in `ExcludeFocus`. (Checked the app's other `AnimatedSwitcher`,
  on the watch screen -- it only switches a single icon, nothing to
  exclude.)

### Removed
- **The floating scroll track is gone from Films, Series, Anime and Live
  TV.** `CustomScrollTrack` drew a draggable thumb with hover-only up/down
  arrows over the catalog pages at desktop width -- which, on a TV, is
  every width, since the tier is picked by screen size and a TV is wide.
  Its arrows and drag gesture need a pointer that a D-pad cannot produce,
  so it rendered as dead, unusable chrome there. It offered nothing a mouse
  wheel or a trackpad did not already do, so it is removed rather than
  gated to real desktops.

## [1.8.13+46] - 2026-09-28

Live TV grows up: sources become a page, portals go live-only, four new
language rows, categories filter, seeded playlists and captions. The
Library centers, sorts both ways and reads series years as ranges.

### Added
- **Series years read as ranges.** `2020–2023` renders `2020 - 2023` on
  cards and details rows, and every numeric use -- title matching, similar
  titles, Library sorting -- takes the start year. Stripping punctuation
  had turned ranges into years like `20192023`.

### Changed
- **Anime Continue Watching holds anime only.** Its filter fell through to
  a default-true branch and listed every movie beside the anime.

### Added
- **Continue and Downloads sort five ways.** Recent, title A-Z and Z-A,
  newest-first and oldest-first behind one Sort pill, the same orders the
  shelves already answer. Rating is honestly absent: no saved title
  carries one yet, so there is nothing to sort by.

### Added
- **Live TV's hero fills the viewport like every other section.** It used
  the scaffold's shorter default; the same band extent Films, Series and
  Anime pass now sizes it, with no band widget riding along.
- **Sources show one list at a time.** Xtream Panels and M3U Playlists get
  a view toggle on top instead of stacking both down the page.

### Changed
- **Library tabs sit in the middle.** The pills hugged the left edge while
  the content below them centered; the row centers when it fits and still
  scrolls when the labels outgrow a phone.

### Added
- **Library content centers on wide screens.** Collections, Continue
  Watching, Downloads and every shelf cap at the same width instead of
  sprawling across ultrawide windows.
- **Anime genre filtering without leaving search.** A genre pill beside the
  Anime chip narrows results in place; season, format, status and sort stay
  one tap away on the Anime Filters page.
- **A Music row on Live TV.** MTV, VH1 and Trace, completing the genre
  shelves beside Movies, News, Kids and Documentaries.
- **Portal browsers filter by region.** Shelves filed per region
  (`AR | Sports`, `UK | News`) get a language pill that narrows categories
  and streams together; regionless shelves stay either way.
- **Combined playlist groups split apart.** `News;Public` was one ugly
  bucket; each group is its own shelf now, with the channel listed under
  both.
- **Live TV starts with six public playlists.** All Languages, English,
  Español, España, Sports and News from iptv-org load on first run, in the
  background, so the shelves are not empty before any portal is added. A
  deleted default stays deleted.
- **Live TV sources are a page.** Portals and playlists moved out of the
  modal into a Sources page with an add form, discovery, favorites and a
  remove-all per section. Copy and delete sit on the row itself now, not
  behind an overflow menu. Deleting asks first; the modal's multi-select
  edit mode is gone with it.
- **Live TV has captions on/off.** Portal feeds that carry subtitles show
  them now, styled by the shared subtitle settings, with a CC toggle on the
  transport bar. There is no track menu: a live feed does not list tracks
  the way a file does.

### Changed
- **Sub/Dub chips name their counts.** An empty category is dimmed and
  inert rather than a tap leading to a "no sources" dead end.
- **Source rows share one icon tile.** Portals and playlists read as the
  same kind of thing, centered against text of any height.
- **No scroll arrows in the portal browser.** The wheel, the scrollbar and
  the gesture move the lists; four floating buttons did nothing they do
  not.
- **Live TV settings link to Sources.** The Portals section keeps the row
  display preferences and gains the way in; management happens on the page.
- **Live TV speaks Spanish, German, Russian and Chinese.** La 1, La 2, 24h
  and Teledeporte; Das Erste, ZDF, RTL, n-tv and WELT; Channel One Russia,
  Rossiya 1, NTV and RT; CCTV-1, CCTV-4, CCTV News and CGTN -- each on its
  own row, off the same keyword matching the rest of the catalog uses.
  Existing installs gain the rows automatically: a saved category list
  keeps what it had and appends what it was missing.

### Removed
- **The Live TV category pill.** The cards already tag their category and
  every portal carries its own categories -- the header filter repeated
  both without adding a way to browse.
- **The Portals & Playlists modal.** Two tabs, two edit modes and its own
  copy of every display preference settings already owns.
- **Movies and Series tabs in the portal browser.** A portal's VOD is not
  live, and the tabs rebuilt Films/Series navigation inside a source
  browser. Portals open live channels only now.
- **The top-bar fullscreen button on Live TV.** The transport bar carries
  it on desktop, and two buttons for one job crowded the channel title out
  of its own bar.

### Fixed
- **The Sources page survives large text.** Its scrape-source pill named
  its natural width and ran 156px past the panel at 3x scale. Found by the
  3x probe (#69), which now holds 40 cases.

## [1.8.12+45] - 2026-09-27

Classic Masterpieces rows on Films, Series and Anime; the Library sorts
both ways; and the subtitle menus list languages, survive large text, and
no longer offer `mon`, `und` or `auto` as something to watch.

Sources & Filters is two settings instead of three, and both take more than
one choice. The player's `C` key toggles subtitles, its menus list languages
rather than files, and the sleep timer can wait for the video to end.

### Added
- **A Classic Masterpieces row on Films and Series, and Classics on Anime.**
  Ranked by the catalog's own ratings, highest first, and skipped when
  there is nothing acclaimed to show. Anime's classics are its all-time
  best that are at least a decade old -- the series that defined what
  came after.
- **One title, one row.** Addon catalogs overlap, so the same film showed
  up under Popular, Top and Featured at once. The first row keeps it now,
  and a row left with nothing is dropped.
- **The Library shelf sorts both ways.** Title A-Z and Z-A, newest-first
  and oldest-first, beside the recent order that was already there. Live TV
  favorites follow the title directions; a year sort falls back to recent
  for channels, which have no year.
- **Watch Sources filters read Audio, Quality, Sources, Size.** The order a
  viewer narrows a list in: what is heard, how it looks, where it comes
  from, how big it is.
- **Details pages prefer the TMDB synopsis in your language.** The addon's
  English text stays the fallback: without a configured key, or when TMDB
  sends nothing, there is nothing to prefer. One cached request per title,
  next to the credits fetch that already runs there.
- **Live TV's hero is the same height as every other section.** The
  user-selectable banner style made this one carousel a different size for
  no reason a viewer could name, so the setting, its styles and its rows in
  the settings page are gone.
- **The Library's Continue Watching and Downloads tabs filter by type.**
  All, Films, Series and Anime pills, matching the shelf filter.
- **Films everywhere.** The section was Films while the Library filter chip
  and collection titles still said Movies; only English disagreed, the other
  three languages already said Films.
- **The Arabic anime catalog is gone.** The separate Arabic feed, its
  English/Arabic mode pill and its details/stream sheets are removed; anime
  is AniList end to end, with the same genre pills and a new decade filter.
  Arabic audio and subtitle support elsewhere is untouched.
- **Resetting a genre or decade filter works again.** Tapping "All Genres"
  or "All Decades" did nothing: a null menu value never reaches the picker,
  so both reset options carry a value that arrives now. Anime gains the
  decade filter Films and Series already had.
- **The backup file reads like a document now.** Indented with sorted keys,
  so two exports diff to nothing and a file can be opened, read, and
  hand-fixed on the day that matters. The envelope also names the release
  that wrote it, for restores across versions.
- **The ORIGINAL audio badge is gone.** It marked the track the file opened
  with, which is not the same as the track the film was made in -- a release
  defaulting to the dub badged the dub. The menu is languages and a tick now,
  nothing else.
- **Source rows read scraper, quality and container.** The watch-screen card
  printed the provider id ("111477"), then the same long release name twice
  as title and description. One compact title plus badges now: quality,
  delivery with seed health, container (MKV/MP4), release source
  (REMUX/BluRay/WEB-DL), codec, size and audio languages. A numeric file id
  shows the scraper instead.
- **Provider names come from the registered roster.** Most built-in scrapers
  stamp every source `PlayTorrioHTTP`, so cards and download rows resolve the
  site behind a source ("HindMoviez") through the scraper list instead. A
  Stremio release title matches nothing and keeps its manifest name.
- **Continue Watching badges, season parts and the Arabic sheet's status
  lines follow the app language.** Source-type and countdown badges, the
  `Movie` type label and collection `Part N` are keys now. `S01E01` shapes
  stay codes -- as universal as episode numbers -- and hardcoded Arabic
  stays Arabic until a native review says otherwise.
- **`C` toggles subtitles on and off.** It used to open the subtitle panel.
  Turning them on matches the language you are hearing, so an English audio
  track gets English subtitles rather than whatever the file happens to
  default to. The panel is one tap on the transport bar, and `A` still opens
  the audio menu.
- **A sleep timer that can wait for the video to end.** Six options, one row
  each: 10, 15, 30, 45 and 60 minutes, then "End of video", which pauses when
  the film does rather than after a count. The custom stepper and the
  "pauses at 02:14" line under every preset are gone -- the list is a list of
  numbers now, and the end time is arithmetic a viewer can do. #76

### Changed
- **Audio tracks are labelled by language.** A row said whatever the
  container's own title was -- "English [DD+ 5.1]", "JPN 2ch" -- which put
  codec and channel detail in the one field a viewer reads to answer "which
  language is this". Rows read "English", "Italian", "Portuguese (Brazil)"
  now, and the track the file opens with carries an **ORIGINAL** badge. The
  codec and channel line under each row is gone too.
- **The subtitle on/off control is one button.** It reads "Turn subtitles
  off" while they are on and "Turn subtitles on" while they are off, so the
  label always names where a press takes you. It was two chips, one of which
  was always inert.
- **Subtitle rows are languages, not files.** Four OpenSubtitles files for
  Arabic are one row with a count; picking it takes the best of them. The
  provider, format, quality and release tags are not shown -- none of it
  changes which language a viewer wants, and the list of files buried the
  languages it was supposed to be listing.
- **Embedded subtitle tracks are labelled by language too.** A container
  title is written by whoever muxed the file and is routinely "eng",
  "[Full] SDH" or "English (US) PGS". Forced and hearing-impaired are still
  read off the title and shown as their own badges.
- **The subtitle panel has Embedded and Online tabs, with All / CC-SDH /
  Forced filters.** The file's own tracks and the online downloads were one
  merged list, so the tracks already in the file -- usually the answer -- sat
  among a hundred downloads. The filters narrow whichever tab is showing.
- **Forced subtitles live under their own chip.** Forced tracks hid among
  full translations they are not: they cover only foreign-language dialogue,
  whichever side it comes from. The filter chips are three independent kinds
  now -- Subtitles, CC-SDH, Forced -- instead of an All that could never say
  whether forced tracks were in or out; tapping the active chip falls back
  to Subtitles.
- **Regional subtitle variants are separate languages.** Spanish (ES) and
  Spanish (LATAM) are different recordings, not two spellings of one label,
  and they used to collapse into a single "Spanish" group -- so the choice
  was hidden rather than simplified. An *untagged* "Spanish" joins the ES
  group now instead of sitting beside it as a near-duplicate. Untagged
  Spanish stays plain "Spanish": naming it Spanish (ES) would state a region
  no metadata names, and a wrong region is worse than a bare language. The same
  for Portuguese (BR) and (PT), and for English (US) and (UK). Only the
  Chinese *script* split still collapses, because Simplified and
  Traditional are the same audio.
- **Every player menu is the same width.** They were 280, 320 and 330, so
  the panel moved sideways as a viewer switched between them, and grouping
  any two under one icon would have been a layout change rather than a
  wiring change. `PlayerTheme.menuWidth` is the one number now.
- **Selection is marked the same way in every menu.** The aspect menu drew a
  trailing check while the audio, subtitle and sleep menus drew a leading
  radio, so the same gesture was drawn two ways depending on which menu was
  open. All four use the radio.
- **Audio sync is gone.** The only sync a viewer reaches for is the subtitle
  one, and a second control with the same name in a different menu was a
  coin flip. Subtitle sync is unchanged.
- **Two tracks in one language are told apart.** A file with both Spanish
  dubs listed "Spanish" twice, so the choice between them was invisible.
  Every language now follows one pattern: a canonical base with the title's
  region swapped in -- `Spanish (ES)`, `Spanish (LATAM)`, `Chinese
  (Traditional)` -- so "Chinese" never sits beside a second spelling of
  itself. The audio menu additionally numbers repeats (`Spanish (ES) #1`),
  where identical rows would otherwise collide with no recourse; embedded
  lists do not number, since a handful of tracks are told apart by trial.
- **Spanish and Portuguese forced tracks are recognized.** Only the English
  word "forced" was matched, so a track titled "Espanol (Forzados)" got no
  badge and sat outside the Forced filter. The Spanish and Portuguese
  spellings count too.
- **Online subtitles with no language are not offered.** A result whose
  language field is empty or an unknown code cannot be listed -- the row
  would have no name -- and cannot be chosen deliberately, because there is
  nothing to choose it by. The menu enforces this itself now rather than
  trusting every search path to have filtered first.
- **A track with no language shows its container title, then its format.**
  Untagged, untitled tracks read "Track 17 \u00b7 SRT" now instead of a bare
  number: the language cannot be known, but the format is still something a
  viewer picking by trial can act on.
- **Online subtitles break ties alphabetically.** The list leads with the
  language being heard, then orders by how many files each language has.
  Two languages with the same count used to fall wherever the providers
  happened to answer, so Spanish could sit above Chinese with ten files
  each. The tie now breaks alphabetically, which is stable.
- **The subtitle file count is gone.** The row picks the best file for the
  language, the way Netflix and Disney+ do, so "5 files" was a number about
  an implementation the viewer never sees, beside a choice that is always
  one.
- **Bold and Italic are two small icon toggles.** They were full-width tiles
  with a switch each, for one bit of state apiece. A B and an I that light up
  is what every text editor uses, and it takes a quarter of the height.

### Added
- **Downloads can be played, paused and resumed.** The row's only control was
  Delete, so a paused download could not be restarted and a finished one
  could not be watched -- the file was on the device with no way to open it.
  A finished download now has Play, a running one has Pause, and a paused,
  failed or canceled one has Resume. Delete asks first, because it removes
  the file.
- **A download says what it is.** Quality, source (P2P / Debrid / HTTP) and
  the audio languages, as small chips under the title. The quality and the
  languages are read off the source when the download starts and stored on
  the task, because the source object is gone by the time the row is drawn.
  A P2P row also shows its peer count while it runs.
- **A download names its scraper.** The delivery word (P2P / Debrid / HTTP)
  says how a file arrived, not where it came from, so two rows reading
  "1080p · HTTP" were indistinguishable. The chip reads off the stored
  source name, preferring the add-on's own short name.
- **A completed download whose file is gone says so.** It would otherwise
  offer Play and then fail.

### Changed
- **A file's own subtitles are no longer turned on by themselves.** The
  choice was made per file, from scratch, every time -- so it surprised the
  viewer and could not learn: someone who turned subtitles off got them back
  on the next episode. Auto-select is only defensible with a remembered
  preference, and there is not one yet. The list is still there, still leads
  with the language being heard, and the viewer picks.
- **Changing the subtitle font, size, color or position no longer turns an
  embedded track off.** `applySubtitleStyling` took a `forceLibass` flag, and
  every appearance setter called it without the flag -- so the styling call
  honored the `useLibass` preference, which is off by default, and set
  `sub-visibility=no`. The flag is gone; whether libass is used is now one
  piece of state, set in one place and read in one place, so no call site can
  forget it.
- **A source row reads scraper, quality and container.** It read the full
  release name -- audio tags, codec, size, group and all -- as a paragraph
  in a 12px row. Rows read "VixSrc · 1080p · HLS" now. Delivery (P2P / HTTP)
  and seed health already have their own badges above the title, so nothing
  is lost. A magnet whose name carries no extension gets no container
  rather than a guessed one.

### Fixed
- **The subtitle menu no longer overflows at large text sizes.** Its toggle,
  tabs and filter chips were fixed chrome above a scrolling list; at a large
  accessibility scale they took the whole card and the list overflowed by
  over a hundred pixels. They scroll with the rows now -- identical when
  everything fits, reachable when it does not. Found by the 3x text-scale
  probe (#69), which also covers the audio menu, the Downloads rows, the
  search idle state and the Library collections tab.
- **Embedded tracks tagged `mon`, `und` or `unknown` no longer fake a
  language.** `mon` (subtitles matching the audio) was never filtered in the
  player, so it surfaced as a fallback-titled row; `und`/`unknown` rendered
  as "UND" rows and blocked the title-guess that would have named them
  ("English SDH"). The first is dropped, the other two fall back to the
  container title like any untagged track.
- **The Cast sheet scrolls, and its title no longer pushes the close button off
  the edge.** Two separate faults in the same sheet. The title, the `Spacer`
  and the close button sat in one flat row with no flex on the title, so the
  title took its natural width -- 321px past the edge at a large text size.
  And the sheet had no scrollable at all, so any content taller than the modal
  allows painted past the bottom. That second one is not only an accessibility
  problem: a viewer with several Cast devices on the network hits it at
  ordinary text size, which nobody had seen because the sheet has never been
  opened with devices actually listed in it (#28 is still unconfirmed against
  a receiver). #69
- **Arabic lays out on the correct side.** `Row` and the Material widgets
  mirror themselves for a right-to-left locale; `EdgeInsets.only(left:)` does
  not -- it is still the left edge in Arabic. 37 paddings across 21 files were
  physical, and two of them applied a whole *page* inset that way, so Live
  TV's search page and the watch-history page hugged the wrong edge entirely.
  Two more were the Arabic anime pages themselves. English rendering is
  unchanged. #68
- **Text no longer runs outside its box at large accessibility sizes** in the
  cast and Similar rails on a details page, and in the four search fields of
  Live TV's portal browser. Each is a box whose height is fixed by the layout
  around it rather than by its own text. #69
- **Forty-two more strings are translated into Spanish, Arabic and
  Portuguese.** Live TV's portal browser carried its own English copies of
  four settings rows the settings page already translates; the empty-sources
  screen, the "source failed to play" screen, the Play Next prompt, the
  Calendar row's heading, the collections picker's empty state, the anime
  genre and source-count lines, the sources panel's provider and scraping
  lines, and the sync overlay's NOW badge were all English. A third needed no
  new key -- they duplicated one that already existed. #68
- **"1 Season" and "3 Seasons" read correctly**, and will in every language.
  It was `Season${count > 1 ? "s" : ""}`, which is the construction that
  cannot survive translation; it is a plural in the message file now. #68
- **Titles can show in their own language.** A switch in Appearance →
  Language. Off by default, because the original title is the one every source
  agrees on and the one you would search for -- and because a translated title
  is not a stable name: Spain and Latin America give the same film different
  Spanish ones. It changes what you read and nothing else; your library, search
  and matching keep using the English title, so a show saved with the switch on
  is the same show saved with it off. Anime only for now: AniList sends four
  titles per show, while a movie or series arrives with one. #68
- **Arabic turns the scroll arrows around.** `Row` and `ListView` mirror
  themselves in a right-to-left layout; an arrow's glyph does not, and neither
  does a `Stack`, so a rail's "scroll back" button kept pointing left while the
  list ran the other way -- and on the details page it sat on the wrong side of
  the screen entirely. Hero titles and logos, side panels, trailing buttons and
  a tab row now follow the reading direction too. The player's seek controls are
  deliberately unchanged: whether a video timeline should mirror is a question
  about the timeline, not the buttons. #68

### Accessibility
- **Icon-only Close and Back buttons announce themselves.** 34 buttons had no
  tooltip and so no label for a screen reader, and no hover hint for a
  pointer. Both labels are translated. #68 #69
- **Every icon-only control announces itself, button or not.** The thirteen
  that were left are an `Icon` inside a `GestureDetector` rather than an
  `IconButton` -- a scroll arrow, a pin, a download, play/pause, the subtitle
  sync reset, the search-match arrows. A screen reader announced neither a name
  nor that they were pressable. The rails' arrows read their label off their own
  icon, so the label cannot drift from the glyph. #69
- **Text stays inside its box in five more places at a large text size:** the
  details page's credits and Similar cards, the error screen every failed load
  lands on, the seek bar, the subtitle sync bar and the Calendar row. The two
  cards were the long-standing gap -- their clamps were arithmetic nobody could
  measure, because the page they lived on fetches over the network. They are
  public widgets now, and measured. #69
- **Every remaining icon-only button announces itself too.** The seven that
  were left -- the catalog search, the two favorite stars, the two deletes in
  the portals modal, the custom-decoder button and the jump-to-episode arrow
  -- have labels, and the watchlist, watched and collection buttons on a
  details page now report their *state* as well as their name, which a
  tooltip alone does not do. A screen reader could not previously say whether
  Watched was on. #69
- **The online subtitle list no longer marks every row as selected.** The
  comparison was `selectedVariant?.downloadUrl == variant.downloadUrl`, and
  when both sides were empty every row matched -- so the whole list drew with
  a filled radio button. A variant with no URL is now never the selected one.
- **Picking a language's second file marks the language.** The row was marked
  only when its *best* file was the one playing, so choosing the second file
  for Arabic left the Arabic row unmarked -- which read as "nothing is
  selected" while a subtitle was on screen.
- **A file row no longer repeats its own format.** A provider that names its
  files "Movie.srt" produced rows reading "SubtitleCat · SRT" beside a title
  that already said SRT. The format is dropped when the title ends in it.
- **The same title from two providers is two choices, not one.** Dedupe
  ignored the provider, so the survivor was whichever answered first -- a
  SubtitleCat file could be dropped in favour of an OpenSubtitles one with no
  way to tell. They are different downloads from different hosts.
- **A provider's own identical rows are collapsed.** SubtitleCat
  lists a file once per language it has been translated into, and the
  translations share a title and a URL: those are one choice, not four.
  Rows that read identically -- same provider, title, format and flags --
  keep the first rather than numbering "#1" and "#2", because a number on
  the same choice twice is still the same choice twice. Anything that
  differs in something visible stays separate, and the same title from two
  providers stays two choices.
- **Exactly one online subtitle row is ever marked.** The mark compared the
  download URL alone, and one provider lists the same file under every
  language it was translated into -- so picking it ticked a row in each
  language. The row's own language must match too, which names one group,
  and an open language moves its tick down to the file instead of showing
  two. The same download link under different titles is one row now, for
  the same reason.
- **Selecting a file's own subtitle cannot silence itself anymore.** The
  selection call was awaited bare, so a throw skipped the libass call below
  it: the overlay was already off because of the selected state, libass was
  never turned on, and the track rendered nowhere. The call is guarded and
  libass is enabled either way, which is the last release's behavior -- the
  styling ran regardless, because the call was fired and forgotten.
- **A file's own subtitles take the engine that fits them.** Sending every
  embedded track through libass silenced the text ones: the overlay was
  hidden for a renderer that only draws ASS. Only ASS goes through libass
  now; other text tracks are drawn from the text mpv emits, which is what
  older releases did, with mpv's own rendering off so the line is not drawn
  twice; bitmap tracks (PGS) render through mpv's OSD with visibility left
  on, since they emit no text at all. The codec decides, falling back to
  the container title muxers write it into.
- **Untagged tracks named by a bare code are labeled.** A file that tags no
  language but titles a track "chi" shows Chinese now instead of "Track N".
  Only a known code or an outright display name counts -- free text is never
  guessed from, because a wrong guess mislabels the track.
- **A rejected subtitle selection says so.** The player's property set never
  throws, so a bad track id failed silently with the menu showing selected
  and mpv on nothing. The id is read back and retried once, the picker
  reports a miss honestly, and the diagnostics dump every subtitle entry
  mpv knows, so an id mismatch shows itself in one paste.
- **The Forced and CC/SDH filters work on a file's own subtitles.** Both are
  read off a track's *title* -- "forced" and "SDH" are words a muxer writes
  there, and there is no other place they appear. But the player overwrote
  the container's title with the language name before building the track, so
  the check ran against "Spanish" and could never match. The filters were not
  broken; they were looking in a field that had been emptied. The container's
  own title is now kept alongside the display name.
- **"Movie_CC" is recognized as a hearing-impaired track.** The marker used
  `\b`, and an underscore is a word character, so `\bcc\b` never matched the
  way release names actually spell it. The check now treats anything that is
  not a letter or digit as a separator, so dots, underscores and brackets all
  work.
- **A filter that matches nothing says so.** It used to read "No subtitles
  available for this stream", which is wrong -- the tracks are there, the
  filter is hiding them.
- **Norwegian is no longer shown as "NB".** `nb` is Bokmål, which is what a
  provider means by "Norwegian", and it was missing from the language table.
  Nynorsk (`nn`) is kept apart from it, because it is a different written
  form rather than a spelling of the same one.
- **Thirty-three more language codes render as names.** Marathi, Cantonese,
  Afrikaans, Zulu, Georgian and the rest were showing as raw three-letter
  codes -- "MAR", "YUE", "AFR" -- which read as noise rather than as a
  language.
- **A duplicated language is named one way or the other, not both.** A file
  with two Spanish tracks could show "Spanish (LATAM)" beside "Spanish #1",
  which reads as two different kinds of thing when they are the same kind of
  thing, and the number says nothing a viewer can act on. The group now uses
  regions throughout or numbers throughout.
- **The embedded subtitle list leads with the language you are hearing.**
  It used to lead with the file's own default track, which is the muxer's
  opinion rather than the viewer's. The tracks matching the selected audio
  now come first -- the same track the `C` key would pick -- and everything
  else follows alphabetically. When nothing matches the audio the whole list
  is alphabetical: there is no second-best language to promote, and a
  promoted track would only be in the way of someone scanning for one.
- **"Auto" is no longer offered as a subtitle language.** It is mpv's own
  pseudo-track, not a language, and it reached the picker as a row reading
  "Auto" -- which cannot be chosen deliberately, because there is nothing to
  choose it by. It is filtered out of the list, and the language helper
  returns nothing for it rather than capitalizing it into a name.
- **Online subtitles are never downloaded on their own.** A search that
  turns up two hundred languages is a list to choose from, not a decision to
  make on the viewer's behalf: fetching one costs bandwidth, takes a moment,
  and puts a subtitle on screen that nobody asked for. The list is populated
  and the viewer picks. The only automatic subtitle is the file's own
  embedded track, which is already on disk.
- **A file's own subtitles actually render now.** The previous fix was
  self-defeating: it turned libass on and then called
  `applySubtitleStyling`, which honours the `useLibass` preference -- off by
  default -- and turned it straight back off. The styling call now takes a
  `forceLibass` flag for embedded tracks, which have no other way to reach
  the screen. The scale slider had the same problem and is fixed with it.
- **The online subtitle list is fifteen languages, not two hundred.** A
  provider search returns a couple of hundred languages, most with a single
  file. The list is now sorted by how many files each language has -- the
  ones a provider actually has coverage for -- and capped, with a "Show all"
  row at the end.
- **A language's other files are reachable.** One tap picks the best file,
  the way Netflix and Disney+ do, and opens the rest at the same time, so a
  wrong pick is visible without a second gesture to discover. Tapping the
  open row again collapses it. The file rows are labelled by provider and
  format, which is the only thing that tells two files for one language
  apart.
- **A file's own subtitles load when playback starts.** They did not appear
  at all: an embedded ASS/SSA track is rendered by libass and never emitted
  as text, and the default `useLibass: false` turned mpv's own rendering off
  in favour of a Flutter overlay that had nothing to draw. An embedded track
  now turns libass on, because it has no other way to reach the screen.
- **A file's own subtitles are turned on automatically.** A file that ships
  subtitles ships them for a reason, and a viewer should not have to open a
  menu to find out they were there. The track chosen matches the language
  being heard, then the file's own default, then the first. Once only, so a
  viewer who turned them off is not overruled by a later track update.
- **Embedded tracks are listed alphabetically**, after the file's own
  default. The order was the muxer's, which is arbitrary -- a twelve-track
  disc put its languages in whatever order they were authored, so the list
  looked shuffled.
- **An audio track with no language tag is no longer called "Audio".** A P2P
  stream often tags none, and the fallback chain is now the container's own
  title, then -- for a file with a single track -- the language the release
  name detects, then the codec, then "Audio". An untagged lone track used
  to read "AAC", which never answers which language is being heard; the
  release name usually does. The container's own title still wins when it
  says something, and several untagged tracks still fall back to the codec
  rather than guessing which row is which language.
- **A multi-select filter's checkmark appears on the first tap.** The menu's
  items were captured when the dialog opened, so the tick only showed
  after closing and reopening it. The rows are rebuilt from the setting on
  every change now, which also keeps the filters multi-select: picking
  "English or Spanish" stays expressible without reopening the menu
  between taps.
- **The audio and quality pills say "Any Audio" and "Any Quality"** when
  nothing is selected, matching "All Sizes" beside them rather than a bare
  "Any" that could belong to either.
- **A multi-select filter's checkmark appears on the first tap.** The menu's
  items were built once, when the dialog opened, so the tick only showed
  after closing and reopening it.
- **"More options" in the subtitle appearance editor is reachable.** The
  panel sets its own height and the anchor bounds it; when the card asked for
  more than the anchor could give, the two became nested scrollables and the
  bottom of the panel could not be scrolled to. The card is clamped to the
  room it actually has.
- **The "More options" row has a visible tap ripple.** The glass card paints
  its background with a `DecoratedBox`, and a `ListTile` under one has
  nowhere to draw its ink.

### Changed
- **The source filters are multi-select.** Audio language and video quality
  both take several choices now; a source matching *any* of them is shown.
  Before, each was one choice, so "English or Spanish" was not expressible
  and had to be re-picked every time you switched between them. An empty
  selection means no filter, which is what "All" used to mean.
- **The audio-language filter and the preferred-audio ranking are one list.**
  They were two of the page's three blocks, and both said "audio language"
  while doing different jobs: the filter chose which *sources* to offer, from
  the release name, and the ranking chose which *track* to play inside a file
  that carries several. They were always the same choice asked twice, so the
  list is now read both ways — it shows sources in any of its languages, and
  the player tries them in the order you put them. #75
- **Five languages became detectable from a release name.** Arabic, Chinese,
  Korean, Portuguese and Turkish were offered by the ranking, which only ever
  needed to read a file's own track tags. As filter entries they would have
  hidden every source, because the release-name detector had no pattern for
  them. A test now asserts every offered key is one the detector can look for.

### Fixed
- **An update keeps the filters you had set.** The stored value changed shape
  — one string per filter became a list — so both shapes are read on load. A
  language that was ranked but not filtered on is folded into the list too,
  rather than dropped.
- **`SettingChoiceChip` can report a deselection.** It deliberately swallowed
  Material's "now unchecked" callback, which is right for a row of mutually
  exclusive choices and wrong for a multi-select one — tapping a selected
  chip is how you turn it off, and the tap did nothing. Rows that allow
  several chips at once opt back in with `multiSelect: true`.

## [1.8.11+44] - 2026-09-25

The source list remembers how you like it filtered, there is a new quality
filter, and the player now picks your audio language inside multi-audio files.

### Added
- **Video-quality filter on the sources screen**: 4K / 1080p / 720p / 480p,
  next to the existing size, source and audio-language filters. A source
  whose resolution was not detected never matches a specific quality.
- **Sources & Filters settings page** (`Settings > Sources & Filters`): the
  audio-language and quality filters are now a global default rather than a
  per-episode choice, plus a **preferred audio languages** ranking.
- **Preferred audio languages**: rank the languages you want in priority
  order. When a multi-audio file plays, the player switches to the first
  track matching the highest-ranked language it actually carries. Empty (the
  default) always keeps the file's own default track. This works on the
  *real* tracks in the file -- the source list cannot know them, because a
  release named `MULTI` does not say which languages are inside.
- **A clearer empty source list**: when a filter hid every source, the list
  now says so and offers to clear the filters, instead of the generic "no
  sources found" that sends you looking for add-ons that are fine.
- **The source filters sit in their own scrollable row**: a bordered strip
  under the "Watch Sources" heading, with an edge button at each end that
  fades in only while there is a pill past that edge. Before, the pills shared
  the heading's line on desktop and scrolled on a phone with nothing to show
  that a pill was hidden off the edge. A plain mouse wheel over the row now
  scrolls it sideways, which it did not before -- only Shift+wheel and a
  trackpad swipe worked, and neither is discoverable. On a phone the row keeps
  the edge fade but not the button: the row is dragged there, and a button
  over the first and last pill would swallow taps meant for them.

### Changed
- **The audio-language filter is remembered.** It used to reset to "All
  Audio" every time a title was opened. It now persists, and the dropdown on
  the sources screen and the settings page write the same value, so whichever
  was changed last is the one that applies.

### Fixed
- **A `MULTI` source now matches every language filter, not just `multi`.**
  It used to match a concrete language only when that language was named, or
  when no other language was -- so `MULTI · Spanish` showed under Spanish but
  not under English, which a bare `MULTI` would have. "Multi-audio" means the
  file has several dubs and names none of them, so it now stands for all of
  them rather than hiding sources that would have played.

## [1.8.10+43] - 2026-09-22

The Subtitle Appearance panel stays put, its sample sits where real subtitles
will, and the phone-sized subtitle panel no longer overflows.

### Changed
- **Subtitle Appearance**: the small preview strip inside the panel (added in
  1.8.9) is removed. The sample on the video already shows the style, and the
  strip took room a phone-sized panel needs for the controls.

### Fixed
- **Subtitle Appearance stays where the subtitle menu is**: opening it used to
  throw the panel to the top of the screen. The panel no longer moves. The
  sample shown on the video sits exactly where real subtitles will -- the true
  centre for "center", following the side, vertical position and margin
  sliders -- even if the panel, on the right, covers part of it.
- **Phone subtitle panel overflow**: on a phone-width panel the CC / SDH / Forced
  filter row ran 126 px past the edge (since 1.8.8). It scrolls sideways now,
  and its "Search online" link, which the "Find more" bar under the list
  duplicates, is gone.

## [1.8.9+42] - 2026-09-22

A clearer subtitle list and a simpler Subtitle Appearance editor; choosing a
subtitle no longer closes the panel.

### Changed
- **Subtitle list**: a row reads "Arabic · Standard" with a quiet
  "OpenSubtitles · SRT" line under it, instead of the provider's file id
  (`13628256`) and a shouting provider badge. A release name is kept when the
  provider gives one; its quality (`1080p`, `WEB-DL`, `x264`) becomes small
  tags, so a subtitle made for the release you are watching stands out.
  Rows that would read the same (several files with only an id) are numbered
  "Standard #1", "#2"...
  Auto-translated subtitles carry a badge saying so, and the download count
  shows where the provider reports one.
- **Choosing a subtitle keeps the panel open** — including *Auto* and *Off* —
  so trying several to compare them is one tap each. Tap outside the panel or
  use the back arrow to leave.
- **Subtitle Appearance**: the background is one opacity slider (0-100 %)
  instead of a list of boxes, and the "50 % Indigo" one is gone; whatever tint a
  preset or an earlier choice gave the box is kept. A preview of the sample sits
  pinned above the controls, so a slider's effect is visible even where the
  panel covers the video. Fonts are chips, each in its own face, instead of a
  dropdown that opened a separate menu. Every slider now has the same
  layout, and the spacing between controls is even.

## [1.8.8+41] - 2026-09-21

Subtitles that follow your settings, macOS for Intel again, a much larger part of
the app in Spanish, Arabic and Portuguese, and Discord Rich Presence removed.

### Fixed
- **Subtitle position**: the Left / Center / Right buttons and the vertical
  position slider did nothing on the default subtitle engine, because
  media_kit's own subtitle view pins its text to the bottom centre. The player
  now draws the subtitle text itself, so alignment, vertical position and
  bottom margin all take effect. (Live TV's player still uses the old view.)
- **CC / SDH and Forced filters**: they ignored mouse and touch — only a
  remote's select key worked. They respond to a click now, show how many
  subtitles each would leave, and dim when there are none. *All* clears both.
- **CC detection**: a subtitle named `Movie.2020.SDH` or `Movie_CC` is now
  recognised as hearing-impaired; only `Movie SDH` (with a space) was.

### Added
- **Sample subtitles**: while the Subtitle Appearance editor is open, the video
  shows "Testing subtitles…" in the current style, and the subtitle panel moves
  to the top so it does not hide them.
- **"In this video" strip**: the embedded subtitle tracks, with the file's
  default first, and the online subtitle currently loaded, sit at the top of
  the subtitle menu, one tap away. Tracks the file marks default or forced
  (read from libmpv) and ones titled CC / SDH carry badges.
- **Flags for 15 more subtitle languages**: Albanian, Bengali, Bosnian,
  Catalan, Icelandic, Kurdish, Macedonian, Malay, Mongolian, Pashto, Sinhala,
  Slovak, Slovenian, Somali and Swahili (the Catalan and Kurdish flags are
  drawn, as flag services do not carry them). The language table also learns
  the Kurdish, Mongolian, Pashto, Sinhala, Somali and Swahili codes.

### Changed
- **Subtitle Appearance, simplified**: one scrolling page — Text, Background,
  Outline, Position — instead of five tabs, with the rarer options (font, scale,
  shadow, bottom margin, and the two advanced switches) under *More options*.
- **Advanced / ASS, simplified**: a four-way override choice and an engine
  radio pair became two switches: *Use my style on styled subtitles* and
  *Native subtitle engine (libass)*. Saved values are unchanged.

### Changed
- **Simkl setup**: when the build has no Simkl client ID, the Connect card now
  says so plainly and offers two buttons: *Open Simkl developer page* and *Add
  a client ID*. The dialog lists the three steps (including the redirect URI to
  enter), has a paste button, and refuses text that cannot be a client ID (a
  URL, a sentence) instead of saving it and failing with a 401 later.

### Removed
- **Discord Rich Presence**: it did not work, so the setting, the service, the
  `dart_discord_presence` dependency, the `DISCORD_APP_ID` build key and every
  call that fed it are gone. Also gone: `simklClientSecret`, which nothing read
  (Simkl's PIN flow signs in with the client ID alone).

### Changed
- **Much more of the app translated (#68)**: the player (controls, menus,
  the sources and episodes panels, the cast sheet, loading and error screens
  and snack bars), the Films, Series, Discover, Search, Anime browse and
  Library pages, the shared error view and the mini player, the subtitle style editor, the skip button and text sync
  overlay, the P2P warning and
  update dialogs, and Live TV's page, settings page, portals modal, portal
  browser, channel sheet, player and multi-view now follow the app language, in all four.
  868 keys in all.

### Fixed
- **Subtitle style editor (phones)**: the Bold and Italic toggle tiles ran off
  the edge on a 360px screen, in every language: two tiles share a row and
  their icon, title and switch did not fit. The title now wraps.
- **Text scale (#69)**: Live TV's settings page no longer overflows at 3× text
  scale: three label/value rows (rotation interval, grid columns, sidebar
  width) let the label wrap and cap the value's growth.
- **Anime page language switch**: the English/Arabic switch showed flags as
  emoji, which Windows draws as two letters; it uses the bundled flag images.
- **Audio menu**: the "default audio stream" line and the "Audio Sync Offset"
  label could run past the card in a language longer than English; they wrap
  and shorten instead.

### Added
- **macOS for Intel**: releases carry a `macOS-x86_64` DMG and ZIP again,
  alongside `macOS-arm64`. One build, thinned into two bundles, each verified
  to hold only its own architecture. The in-app updater now picks the download
  that matches the Mac it is running on. Untested on an Intel Mac: CI proves
  the binary's architecture, not that it launches.

## [1.8.7+40] - 2026-09-21

The header is one row on tablet, desktop and TV.

### Changed
- **One-row header (tablet, desktop, TV)**: the section chips moved up into the
  top bar, between the logo and Settings, and the second bar under it is gone
  — the content starts 44px higher and nothing else moved. On a tablet
  (600–900px) the wordmark gives way to the logo icon so everything fits.
  Chips now show a focus ring, so a remote's position reads from across the
  room. Phones are unchanged: sections stay in the bottom tab bar.

## [1.8.6+39] - 2026-09-20

A download button in the player, a simpler playback speed menu, and a fix for
fullscreen on Windows.

### Added
- **Download from the video player**: a download button in the player's top
  bar, next to *Copy Stream URL*, for movies, series and anime. It downloads
  the source currently playing, through the same path as the download button
  on the sources list (duplicate check, folder prompt on phones, snack bar).
  Hidden for a file that is already local, and for a video opened with no
  title behind it, such as a bare magnet from search.

### Fixed
- **Fullscreen (Windows)**: pressing F to leave fullscreen dropped a maximized
  window to its small restored size instead of back to maximized. Entering
  fullscreen has to unmaximize first, which discarded the state; it is now
  remembered and restored, on leaving with F and on leaving the player.

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
  [INFO.md](docs/INFO.md#upstream) for the full list and
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
| #68 | Translation (i18n) — Spanish/Arabic/Portuguese-BR, 994 keys, with tests holding the hardcoded-text tail, the RTL padding and alignment, the icon-only tooltips and the spelling; icon direction turns with the reading direction; anime carries a display/native title toggle, movies and series carry one title; data strings (catalog descriptions, AniList genres) stay English on purpose |
| #69 | Text scale and accessibility — 32 high-traffic widgets (including the details-page cards) probed at 3x and capped at 1.3x, every icon-only control labelled button or not; the unprobed tail (mostly pages a test cannot construct) is deliberately unranked |
| #70 | Audio silent under Flatpak — `--socket=pulseaudio` added; confirmed on real speakers 2026-09-16 |
| #71 | Subtitle appearance settings now expand inline in Settings instead of opening as a pop-up |
| #72 | Source filters (audio language, video quality) persisted as a global default, set from a new Sources & Filters settings page |
| #73 | Preferred audio languages: a ranked list applied to the real tracks inside a multi-audio file, plus the `MULTI` filter fix |
| #74 | The source-filter pills on their own scrollable row, with edge buttons showing when a pill is hidden past either end (desktop; the phone keeps the fade alone) |
| #75 | Sources & Filters became two multi-select settings, with the audio filter and the preferred-audio ranking merged into one ordered list |
| #76 | Sleep timer gained 10 and 45 minute presets and an End of video mode |
| #77 | Xtream/portal movies and series as parent sources — decided not viable for now; see the roadmap's "Not doing" table |
| #78 | Android TV support: manifest, focusable controls across `lib/`, the TV banner |
| #79 | Casting a scraper source gets stuck loading (open; see the roadmap) |
| #80 | TV-native UX: TV-mode detection, type scale, full-screen sheets, focus order and rings, and the first real-remote fixes (player arrows, chips, catalog rows, card rings, Watch Sources, poster sizing) |
