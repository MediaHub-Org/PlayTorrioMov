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
    index = $null; roundness = [ordered]@{ type = 3 }
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
    index = $null; roundness = $null
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    fontSize = $FontSize; fontFamily = 1; text = $Text
    textAlign = 'center'; verticalAlign = 'middle'
    containerId = $Id; originalText = $Text; lineHeight = 1.25
    baseline = [int]($FontSize * 0.9)
  })
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
    index = $null; roundness = [ordered]@{ type = 2 }
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
      index = $null; roundness = $null
      seed = (New-Seed); version = 1; versionNonce = (New-Seed)
      isDeleted = $false; boundElements = @()
      updated = 1; link = $null; locked = $false
      fontSize = 12; fontFamily = 1; text = $Label
      textAlign = 'center'; verticalAlign = 'middle'
      containerId = $null; originalText = $Label; lineHeight = 1.25
      baseline = 11
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
    index = $null; roundness = $null
    seed = (New-Seed); version = 1; versionNonce = (New-Seed)
    isDeleted = $false; boundElements = @()
    updated = 1; link = $null; locked = $false
    fontSize = $Size; fontFamily = 1; text = $Text
    textAlign = 'left'; verticalAlign = 'top'
    containerId = $null; originalText = $Text; lineHeight = 1.25
    baseline = [int]($Size * 0.9)
  })
}

# ── Layout ─────────────────────────────────────────────────────────────────
# Five bands, top to bottom: entry, where content comes from, the source
# list, playback, and what playback pulls in. Arrows only ever point down,
# so the reading order is the flow.

Add-Title -X 60 -Y 40 -Text 'PlayTorrioMov — how it works' -Size 30

# Band 1: entry
Add-Box -Id (New-Id) -X 380 -Y 110 -W 260 -H 70 -Fill $C.entry `
  -Text "main.dart`ninitialises every service, then HubPage"
Add-Box -Id (New-Id) -X 380 -Y 220 -W 260 -H 60 -Fill $C.entry `
  -Text 'HubPage — nav shell (Movies / Series / Anime / Live TV)'
Add-Arrow -X1 510 -Y1 180 -X2 510 -Y2 220

# Band 2: content sources
Add-Box -Id (New-Id) -X 60 -Y 340 -W 250 -H 90 -Fill $C.source `
  -Text "Addons (Stremio-compatible)`ncatalog + stream add-ons"
Add-Box -Id (New-Id) -X 385 -Y 340 -W 250 -H 90 -Fill $C.source `
  -Text "Built-in scrapers (~50 sites)`nScraperManager -> StreamService"
Add-Box -Id (New-Id) -X 710 -Y 340 -W 250 -H 90 -Fill $C.source `
  -Text "Live TV`nXtream portals + M3U playlists"

Add-Arrow -X1 510 -Y1 280 -X2 185 -Y2 340
Add-Arrow -X1 510 -Y1 280 -X2 510 -Y2 340
Add-Arrow -X1 510 -Y1 280 -X2 835 -Y2 340

# Band 3: the source list
Add-Box -Id (New-Id) -X 380 -Y 490 -W 260 -H 70 -Fill $C.play `
  -Text "WatchScreen`nsource list, filters, quality / audio"
Add-Arrow -X1 185 -Y1 430 -X2 440 -Y2 490
Add-Arrow -X1 510 -Y1 430 -X2 510 -Y2 490
Add-Arrow -X1 835 -Y1 430 -X2 580 -Y2 490

# Band 4: playback
Add-Box -Id (New-Id) -X 380 -Y 620 -W 260 -H 70 -Fill $C.play `
  -Text "PlayerScreen`nmedia_kit / libmpv"
Add-Arrow -X1 510 -Y1 560 -X2 510 -Y2 620

# Band 5: what playback pulls in
Add-Box -Id (New-Id) -X 60 -Y 760 -W 250 -H 100 -Fill $C.support `
  -Text "P2P`nTorrServer + libtorrent`n(magnet -> HTTP stream)"
Add-Box -Id (New-Id) -X 385 -Y 760 -W 250 -H 100 -Fill $C.support `
  -Text "Subtitles`nembedded (libass)`n+ online providers"
Add-Box -Id (New-Id) -X 710 -Y 760 -W 250 -H 100 -Fill $C.support `
  -Text "Metadata`nTMDB / Simkl / Trakt`nAniList (anime)"

Add-Arrow -X1 440 -Y1 690 -X2 185 -Y2 760
Add-Arrow -X1 510 -Y1 690 -X2 510 -Y2 760
Add-Arrow -X1 580 -Y1 690 -X2 835 -Y2 760

# Band 6: persistence, fed by everything
Add-Box -Id (New-Id) -X 380 -Y 920 -W 260 -H 70 -Fill $C.store `
  -Text "Storage`nSharedPreferences + sqflite"
Add-Arrow -X1 185 -Y1 860 -X2 440 -Y2 920 -Dashed $true
Add-Arrow -X1 510 -Y1 860 -X2 510 -Y2 920 -Dashed $true
Add-Arrow -X1 835 -Y1 860 -X2 580 -Y2 920 -Dashed $true

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
