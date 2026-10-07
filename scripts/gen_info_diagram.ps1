# Generates docs/INFO.excalidraw -- the "how PlayTorrioMov works" diagram.
#
# Written as a script rather than by hand: the file is ~40 elements of
# near-identical JSON, and hand-editing it is how the previous version ended
# up with a stray line and no arrows. The element builders themselves live in
# excalidraw_lib.ps1, shared with the other gen_*_diagram.ps1 scripts.
. "$PSScriptRoot/excalidraw_lib.ps1"

$elements = [System.Collections.Generic.List[object]]::new()

# ── Palette ────────────────────────────────────────────────────────────────
$C = @{
  entry   = '#a5d8ff'   # blue    -- entry / shell
  source  = '#b2f2bb'   # green   -- where content comes from
  play    = '#ffd8a8'   # orange  -- playback
  support = '#d0bfff'   # purple  -- supporting services
  store   = '#ffec99'   # yellow  -- persistence
  ink     = '#1e1e1e'
  edge    = '#1e1e1e'
}

# ── Layout ─────────────────────────────────────────────────────────────────
# Eight bands, top to bottom: entry, the hub's sections, where content comes
# from, the source list, playback, the player's own menus, the services
# playback pulls in, and persistence. Arrows only ever point down, so the
# reading order is the flow and no arrow has to be followed backwards.
#
# Every line of box text is kept inside its box. Excalidraw renders bound
# text at its natural width -- it does not wrap to the container -- so a line
# longer than the box spills out of both sides. At fontSize 16 the hand-drawn
# font averages about 8.6px per character, so a 420-wide box holds ~48 and a
# 300-wide box at fontSize 14 holds ~40. The lines below are written to those
# budgets, and check_info_diagram.ps1 is what catches it when one is not.
#
# The heights are the ones the Excalidraw plugin settles on when it opens the
# file: it measures each bound text and shrinks the box to fit, so a box
# written taller than its text comes back shorter the first time anyone looks
# at it. Writing the settled height here means the file does not change under
# the plugin, and a diff after opening it is a real edit rather than the
# editor's own tidying. The text elements carry `autoResize` for the same
# reason -- it is what the plugin writes, and its absence is what makes it
# rewrite them.

Add-Title -X 60 -Y 40 -Text 'PlayTorrioMov — how it works' -Size 30

# Legend, in a row under the title. The colours are the only thing in the
# diagram that is not self-explanatory, so they are named once here rather
# than guessed at from the boxes.
Add-Box -Id (New-Id) -X 60 -Y 95 -W 200 -H 27 -Fill $C.entry -FontSize 13 `
  -Text 'entry / shell' | Out-Null
Add-Box -Id (New-Id) -X 280 -Y 95 -W 200 -H 27 -Fill $C.source -FontSize 13 `
  -Text 'where content comes from' | Out-Null
Add-Box -Id (New-Id) -X 500 -Y 95 -W 200 -H 27 -Fill $C.play -FontSize 13 `
  -Text 'browsing and playback' | Out-Null
Add-Box -Id (New-Id) -X 720 -Y 95 -W 200 -H 27 -Fill $C.support -FontSize 13 `
  -Text 'services playback pulls in' | Out-Null
Add-Box -Id (New-Id) -X 940 -Y 95 -W 200 -H 32 -Fill $C.store -FontSize 13 `
  -Text 'persistence' | Out-Null

# Band 1: entry
Add-BandLabel -X 60 -Y 154 -Text 'STARTUP'
$main = Add-Box -Id (New-Id) -X 460 -Y 180 -W 420 -H 70 -Fill $C.entry `
  -Text "main.dart`nWidgetsFlutterBinding · MediaKit`n~20 services initialised in parallel"
$hub = Add-Box -Id (New-Id) -X 460 -Y 310 -W 420 -H 70 -Fill $C.entry `
  -Text "HubPage`nAdaptiveNavShell + MediaHub`none nested Navigator"
Add-ArrowBetween -From $main -To $hub

# Band 2: the hub's sections
Add-BandLabel -X 60 -Y 414 -Text 'SECTIONS'
$movies = Add-Box -Id (New-Id) -X 60 -Y 440 -W 210 -H 30 -Fill $C.entry -Text 'Movies'
$series = Add-Box -Id (New-Id) -X 300 -Y 440 -W 210 -H 30 -Fill $C.entry -Text 'Series'
$anime = Add-Box -Id (New-Id) -X 540 -Y 440 -W 210 -H 30 -Fill $C.entry -Text 'Anime'
$live = Add-Box -Id (New-Id) -X 780 -Y 440 -W 210 -H 30 -Fill $C.entry -Text 'Live TV'
$library = Add-Box -Id (New-Id) -X 1020 -Y 440 -W 210 -H 30 -Fill $C.entry -Text 'Library'

Add-ArrowBetween -From $hub -To $movies
Add-ArrowBetween -From $hub -To $series
Add-ArrowBetween -From $hub -To $anime
Add-ArrowBetween -From $hub -To $live
Add-ArrowBetween -From $hub -To $library

# Band 3: where content comes from
Add-BandLabel -X 60 -Y 548 -Text 'CONTENT SOURCES'
$addons = Add-Box -Id (New-Id) -X 60 -Y 580 -W 300 -H 63 -Fill $C.source -FontSize 14 `
  -Text "Addons`nStremio-compatible`ncatalog + stream add-ons"
$scrapers = Add-Box -Id (New-Id) -X 380 -Y 580 -W 300 -H 63 -Fill $C.source -FontSize 14 `
  -Text "Built-in scrapers`n~50 sites`nScraperManager -> StreamService"
$iptv = Add-Box -Id (New-Id) -X 700 -Y 580 -W 300 -H 63 -Fill $C.source -FontSize 14 `
  -Text "Live TV`nXtream portals`n+ M3U playlists"
$animeSrc = Add-Box -Id (New-Id) -X 1020 -Y 580 -W 300 -H 45 -Fill $C.source -FontSize 14 `
  -Text "Anime`nAniList · Anime Arabic"

Add-ArrowBetween -From $movies -To $addons
Add-ArrowBetween -From $series -To $scrapers
Add-ArrowBetween -From $anime -To $scrapers
Add-ArrowBetween -From $live -To $iptv
Add-ArrowBetween -From $library -To $animeSrc

# Band 4: the source list
Add-BandLabel -X 60 -Y 718 -Text 'BROWSING'
$watch = Add-Box -Id (New-Id) -X 460 -Y 750 -W 420 -H 70 -Fill $C.play `
  -Text "WatchScreen`nsource list · filter pills`nsort · multi-select"
Add-ArrowBetween -From $addons -To $watch
Add-ArrowBetween -From $scrapers -To $watch
Add-ArrowBetween -From $iptv -To $watch
Add-ArrowBetween -From $animeSrc -To $watch

# Band 5: playback
Add-BandLabel -X 60 -Y 888 -Text 'PLAYBACK'
$player = Add-Box -Id (New-Id) -X 460 -Y 920 -W 420 -H 70 -Fill $C.play `
  -Text "PlayerScreen`nmedia_kit / libmpv · transport`nkeyboard shortcuts"
Add-ArrowBetween -From $watch -To $player

# Band 6: the player's own menus
Add-BandLabel -X 60 -Y 1058 -Text 'PLAYER MENUS'
$menuAudio = Add-Box -Id (New-Id) -X 60 -Y 1090 -W 300 -H 45 -Fill $C.play -FontSize 14 `
  -Text "Audio & Subtitles`ntrack pickers · sync · style"
$menuSpeed = Add-Box -Id (New-Id) -X 380 -Y 1090 -W 300 -H 45 -Fill $C.play -FontSize 14 `
  -Text "Speed & Aspect`nplayback rate · crop / scale"
$menuSources = Add-Box -Id (New-Id) -X 700 -Y 1090 -W 300 -H 45 -Fill $C.play -FontSize 14 `
  -Text "Sources & Episodes`nswitch source · next episode"
$menuSleep = Add-Box -Id (New-Id) -X 1020 -Y 1090 -W 300 -H 45 -Fill $C.play -FontSize 14 `
  -Text "Sleep timer & Cast`n10-60 min · end of video · DLNA"

Add-ArrowBetween -From $player -To $menuAudio
Add-ArrowBetween -From $player -To $menuSpeed
Add-ArrowBetween -From $player -To $menuSources
Add-ArrowBetween -From $player -To $menuSleep

# Band 7: what playback pulls in
Add-BandLabel -X 60 -Y 1228 -Text 'SERVICES'
$p2p = Add-Box -Id (New-Id) -X 60 -Y 1260 -W 300 -H 63 -Fill $C.support -FontSize 14 `
  -Text "P2P`nTorrServer + libtorrent`nmagnet -> HTTP stream"
$subs = Add-Box -Id (New-Id) -X 380 -Y 1260 -W 300 -H 63 -Fill $C.support -FontSize 14 `
  -Text "Subtitles`nembedded (libass)`n+ online providers"
$meta = Add-Box -Id (New-Id) -X 700 -Y 1260 -W 300 -H 63 -Fill $C.support -FontSize 14 `
  -Text "Metadata`nStremio baseline + TMDB`nSimkl sync · AniList"
$debrid = Add-Box -Id (New-Id) -X 1020 -Y 1260 -W 300 -H 63 -Fill $C.support -FontSize 14 `
  -Text "Debrid & Downloads`nReal-Debrid and friends`noffline files"

Add-ArrowBetween -From $menuAudio -To $p2p
Add-ArrowBetween -From $menuSpeed -To $subs
Add-ArrowBetween -From $menuSources -To $meta
Add-ArrowBetween -From $menuSleep -To $debrid

# Band 8: persistence, fed by everything above it
Add-BandLabel -X 60 -Y 1398 -Text 'PERSISTENCE'
$storage = Add-Box -Id (New-Id) -X 460 -Y 1430 -W 420 -H 70 -Fill $C.store `
  -Text "Storage`nSharedPreferences + sqflite`nsettings · library · history"
Add-ArrowBetween -From $p2p -To $storage -Dashed $true
Add-ArrowBetween -From $subs -To $storage -Dashed $true
Add-ArrowBetween -From $meta -To $storage -Dashed $true
Add-ArrowBetween -From $debrid -To $storage -Dashed $true

# ── Write ──────────────────────────────────────────────────────────────────
Write-ExcalidrawFile -Path 'docs/INFO.excalidraw'
