# Generates docs/INFO.excalidraw -- the "how PlayTorrioMov works" diagram.
#
# Written as a script rather than by hand: the file is ~40 elements of
# near-identical JSON, and hand-editing it is how the previous version ended
# up with a stray line and no arrows.
$ErrorActionPreference = 'Stop'

$script:seed = 1000000
function New-Seed { $script:seed++; return $script:seed }
$script:n = 0
function New-Id { $script:n++; return "ptm$($script:n.ToString('D3'))" }

# Excalidraw orders elements by a fractional index string, not by array
# position. A null index is tolerated by the web app but is not what it
# writes, and the VS Code plugin is stricter about it. Zero-padded so a
# plain lexicographic sort is also the numeric one.
$script:idx = 0
function New-Index { $script:idx++; return "a$($script:idx.ToString('D4'))" }

$elements = [System.Collections.Generic.List[object]]::new()

# Every box's geometry, by id. Arrows are placed from this rather than from
# hard-coded coordinates: a box that changes height moves its own edges, and
# an arrow written against the old height ends up floating in the gap. That
# is exactly what happened when the Excalidraw plugin shrank every box to fit
# its text -- eleven of the twenty-eight arrows came away from the boxes they
# were meant to join, and nothing in the file said so.
$script:geom = @{}

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

function Add-Box {
  param(
    [string]$Id, [double]$X, [double]$Y, [double]$W, [double]$H,
    [string]$Fill, [string]$Text, [double]$FontSize = 16,
    [string]$Stroke = $C.edge
  )
  $textId = "$Id-t"
  $elements.Add([ordered]@{
    id = $Id; type = 'rectangle'; x = $X; y = $Y; width = $W; height = $H
    angle = 0; strokeColor = $Stroke; backgroundColor = $Fill
    fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
    roughness = 1; opacity = 100; groupIds = @(); frameId = $null
    index = (New-Index); roundness = [ordered]@{ type = 3 }
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false
    boundElements = @([ordered]@{ type = 'text'; id = $textId })
    updated = 1; link = $null; locked = $false
  })
  $elements.Add([ordered]@{
    id = $textId; type = 'text'; x = $X; y = $Y; width = $W; height = $H
    angle = 0; strokeColor = $C.ink; backgroundColor = 'transparent'
    fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
    roughness = 1; opacity = 100; groupIds = @(); frameId = $null
    index = (New-Index); roundness = $null
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    fontSize = $FontSize; fontFamily = 1; text = $Text
    textAlign = 'center'; verticalAlign = 'middle'
    containerId = $Id; originalText = $Text; lineHeight = 1.25
    baseline = [int]($FontSize * 0.9)
    autoResize = $true
  })
  $script:geom[$Id] = @{ x = $X; y = $Y; w = $W; h = $H }
  return $Id
}

function Add-Arrow {
  param(
    [double]$X1, [double]$Y1, [double]$X2, [double]$Y2,
    [string]$Label = '', [bool]$Dashed = $false
  )
  $id = New-Id
  $dx = $X2 - $X1; $dy = $Y2 - $Y1
  $elements.Add([ordered]@{
    id = $id; type = 'arrow'; x = $X1; y = $Y1
    width = [math]::Abs($dx); height = [math]::Abs($dy)
    angle = 0; strokeColor = $C.edge; backgroundColor = 'transparent'
    fillStyle = 'solid'; strokeWidth = 2
    strokeStyle = $(if ($Dashed) { 'dashed' } else { 'solid' })
    roughness = 1; opacity = 100; groupIds = @(); frameId = $null
    index = (New-Index); roundness = [ordered]@{ type = 2 }
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    points = @(@(0, 0), @($dx, $dy))
    lastCommittedPoint = $null
    startBinding = $null; endBinding = $null
    startArrowhead = $null; endArrowhead = 'arrow'
  })
  if ($Label -ne '') {
    $lx = ($X1 + $X2) / 2 - 60
    $ly = ($Y1 + $Y2) / 2 - 10
    $elements.Add([ordered]@{
      id = "$id-l"; type = 'text'; x = $lx; y = $ly; width = 120; height = 20
      angle = 0; strokeColor = '#868e96'; backgroundColor = 'transparent'
      fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
      roughness = 1; opacity = 100; groupIds = @(); frameId = $null
      index = (New-Index); roundness = $null
      seed = (New-Seed); version = 1; versionNonce = (New-Seed)
      isDeleted = $false; boundElements = @()
      updated = 1; link = $null; locked = $false
      fontSize = 12; fontFamily = 1; text = $Label
      textAlign = 'center'; verticalAlign = 'middle'
      containerId = $null; originalText = $Label; lineHeight = 1.25
      baseline = 11
      autoResize = $true
    })
  }
}

function Add-Title {
  param([double]$X, [double]$Y, [string]$Text, [double]$Size = 28)
  $elements.Add([ordered]@{
    id = (New-Id); type = 'text'; x = $X; y = $Y
    width = 700; height = ($Size * 1.4)
    angle = 0; strokeColor = $C.ink; backgroundColor = 'transparent'
    fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
    roughness = 1; opacity = 100; groupIds = @(); frameId = $null
    index = (New-Index); roundness = $null
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    fontSize = $Size; fontFamily = 1; text = $Text
    textAlign = 'left'; verticalAlign = 'top'
    containerId = $null; originalText = $Text; lineHeight = 1.25
    baseline = [int]($Size * 0.9)
    autoResize = $true
  })
}

# An arrow from one box to another, placed from the boxes' own geometry.
#
# $FromEdge and $ToEdge name the side the arrow leaves and arrives on, so the
# endpoints follow a box that changes size. $FromOffset and $ToOffset slide
# the endpoint along that side, which is how five arrows leave one box
# without all landing on the same pixel.
function Add-ArrowBetween {
  param(
    [string]$From, [string]$To,
    [string]$FromEdge = 'bottom', [string]$ToEdge = 'top',
    [double]$FromOffset = 0.5, [double]$ToOffset = 0.5,
    [bool]$Dashed = $false
  )
  $a = $script:geom[$From]
  $b = $script:geom[$To]
  if (-not $a) { throw "Add-ArrowBetween: no box '$From'" }
  if (-not $b) { throw "Add-ArrowBetween: no box '$To'" }

  $x1 = if ($FromEdge -eq 'left') { $a.x } elseif ($FromEdge -eq 'right') { $a.x + $a.w } else { $a.x + $a.w * $FromOffset }
  $y1 = if ($FromEdge -eq 'top') { $a.y } elseif ($FromEdge -eq 'bottom') { $a.y + $a.h } else { $a.y + $a.h * $FromOffset }
  $x2 = if ($ToEdge -eq 'left') { $b.x } elseif ($ToEdge -eq 'right') { $b.x + $b.w } else { $b.x + $b.w * $ToOffset }
  $y2 = if ($ToEdge -eq 'top') { $b.y } elseif ($ToEdge -eq 'bottom') { $b.y + $b.h } else { $b.y + $b.h * $ToOffset }

  Add-Arrow -X1 $x1 -Y1 $y1 -X2 $x2 -Y2 $y2 -Dashed $Dashed
}

function Add-BandLabel {
  param([double]$X, [double]$Y, [string]$Text)
  $elements.Add([ordered]@{
    id = (New-Id); type = 'text'; x = $X; y = $Y; width = 500; height = 20
    angle = 0; strokeColor = '#868e96'; backgroundColor = 'transparent'
    fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
    roughness = 1; opacity = 100; groupIds = @(); frameId = $null
    index = (New-Index); roundness = $null
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    fontSize = 13; fontFamily = 1; text = $Text
    textAlign = 'left'; verticalAlign = 'top'
    containerId = $null; originalText = $Text; lineHeight = 1.25
    baseline = 12
    autoResize = $true
  })
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
  -Text "Metadata`nTMDB · Simkl · Trakt`nAniList (anime)"
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
$doc = [ordered]@{
  type = 'excalidraw'
  version = 2
  source = 'https://marketplace.visualstudio.com/items?itemName=pomdtr.excalidraw-editor'
  elements = $elements
  appState = [ordered]@{
    gridSize = 20
    gridStep = 5
    gridModeEnabled = $false
    viewBackgroundColor = '#ffffff'
  }
  files = [ordered]@{}
}

$json = $doc | ConvertTo-Json -Depth 12
Set-Content -Path 'docs/INFO.excalidraw' -Value $json -NoNewline
"Wrote docs/INFO.excalidraw: $($elements.Count) elements"
