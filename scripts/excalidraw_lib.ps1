# Shared element builders for this repo's generated .excalidraw diagrams.
#
# Dot-sourced by each gen_*_diagram.ps1 rather than copied into it: this file
# used to be the first third of gen_info_diagram.ps1, byte-for-byte, and a
# second diagram meant a second copy drifting from the first one fix at a
# time. Each diagram script still owns its own palette ($C) and layout --
# only the element shapes (box, arrow, title, band label) and the id/seed/
# index counters live here.
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

# Every box's geometry, by id. Arrows are placed from this rather than from
# hard-coded coordinates: a box that changes height moves its own edges, and
# an arrow written against the old height ends up floating in the gap. That
# is exactly what happened when the Excalidraw plugin shrank every box to fit
# its text -- eleven of the twenty-eight arrows came away from the boxes they
# were meant to join, and nothing in the file said so.
$script:geom = @{}

function Add-Box {
  param(
    [string]$Id, [double]$X, [double]$Y, [double]$W, [double]$H,
    [string]$Fill, [string]$Text, [double]$FontSize = 16,
    [string]$Stroke = $C.edge, [bool]$DashedStroke = $false
  )
  $textId = "$Id-t"
  $elements.Add([ordered]@{
    id = $Id; type = 'rectangle'; x = $X; y = $Y; width = $W; height = $H
    angle = 0; strokeColor = $Stroke; backgroundColor = $Fill
    fillStyle = 'solid'; strokeWidth = 2
    strokeStyle = $(if ($DashedStroke) { 'dashed' } else { 'solid' })
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

# Writes $elements (built by the functions above) to an .excalidraw file.
# Every diagram script ends by calling this -- it is the one place the JSON
# shape (appState, files, the version/source stamp) is decided, so the two
# diagrams cannot drift on it independently.
function Write-ExcalidrawFile {
  param([string]$Path)
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
  # -Encoding utf8NoBOM explicitly: this PowerShell's own default for
  # Set-Content mangled every em dash and middle dot into U+FFFD the first
  # time this ran, silently -- ConvertTo-Json had already encoded them
  # correctly, so this is the one write that must not re-encode them wrong.
  $json = $doc | ConvertTo-Json -Depth 12
  Set-Content -Path $Path -Value $json -NoNewline -Encoding utf8NoBOM
  "Wrote ${Path}: $($elements.Count) elements"
}
