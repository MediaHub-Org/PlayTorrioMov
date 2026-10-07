# Sanity-checks a generated .excalidraw diagram (default: docs/INFO.excalidraw,
# after gen_info_diagram.ps1 writes it; pass -Path for another one, e.g. after
# gen_backup_sync_diagram.ps1).
#
# The diagram is generated, so a mistake in the layout is a mistake in the
# script -- but the script cannot see the result. This reads the file back
# and reports the four things that are invisible in the source: elements
# missing a field Excalidraw requires, boxes that overlap each other, arrows
# whose endpoints land inside a box they were not aimed at, and text wider
# than the box it is bound to. All four are silent in the editor; they just
# look wrong, or the file does not open at all.
param([string]$Path = 'docs/INFO.excalidraw')
$ErrorActionPreference = 'Stop'

$doc = Get-Content $Path -Raw | ConvertFrom-Json
$boxes = @($doc.elements | Where-Object { $_.type -eq 'rectangle' })
$arrows = @($doc.elements | Where-Object { $_.type -eq 'arrow' })
$texts = @($doc.elements | Where-Object { $_.type -eq 'text' })

"elements: $($doc.elements.Count)  boxes: $($boxes.Count)  arrows: $($arrows.Count)"

$problems = 0

# Every element carries these, whatever its type. A missing one is what makes
# the editor refuse the file rather than draw it wrong.
$common = @(
  'id', 'type', 'x', 'y', 'width', 'height', 'angle', 'strokeColor',
  'backgroundColor', 'fillStyle', 'strokeWidth', 'strokeStyle', 'roughness',
  'opacity', 'groupIds', 'frameId', 'index', 'roundness', 'seed', 'version',
  'versionNonce', 'isDeleted', 'boundElements', 'updated', 'link', 'locked'
)
$byType = @{
  text  = @('fontSize', 'fontFamily', 'text', 'textAlign', 'verticalAlign',
            'containerId', 'originalText', 'lineHeight', 'baseline')
  arrow = @('points', 'lastCommittedPoint', 'startBinding', 'endBinding',
            'startArrowhead', 'endArrowhead')
}

foreach ($element in $doc.elements) {
  # A rectangle has no extra fields, so the lookup is absent rather than
  # empty -- and @($null) would put a null in the list and blow up the
  # property lookup below.
  $extra = if ($byType.ContainsKey($element.type)) { $byType[$element.type] } else { @() }
  $required = $common + $extra
  foreach ($field in $required) {
    if ($null -eq $element.PSObject.Properties[$field]) {
      "MISSING FIELD  $($element.id) ($($element.type)) has no '$field'"
      $problems++
    }
  }
  # A null index is tolerated by the web app but is not what it writes, and
  # the VS Code plugin is stricter about it.
  if ($element.type -ne 'text' -and $null -eq $element.index) {
    "NULL INDEX  $($element.id)"
    $problems++
  }
}

for ($i = 0; $i -lt $boxes.Count; $i++) {
  for ($j = $i + 1; $j -lt $boxes.Count; $j++) {
    $a = $boxes[$i]; $b = $boxes[$j]
    $overlapX = $a.x -lt ($b.x + $b.width) -and $b.x -lt ($a.x + $a.width)
    $overlapY = $a.y -lt ($b.y + $b.height) -and $b.y -lt ($a.y + $a.height)
    if ($overlapX -and $overlapY) {
      "OVERLAP  $($a.id) [$($a.x),$($a.y)]  vs  $($b.id) [$($b.x),$($b.y)]"
      $problems++
    }
  }
}

# An arrow's own x/y is its start; the end is start + the last point.
#
# Both ends are checked against the boxes, not just the end. An arrow that
# starts in mid-air is the failure mode this diagram actually had: the boxes
# were shrunk to fit their text and eleven arrows were left floating in the
# gap, because their coordinates had been written against the old heights.
# Nothing in the file said so -- it just looked wrong.
$tolerance = 2
foreach ($arrow in $arrows) {
  $endX = $arrow.x + $arrow.points[-1][0]
  $endY = $arrow.y + $arrow.points[-1][1]
  foreach ($box in $boxes) {
    $insideX = $endX -gt $box.x -and $endX -lt ($box.x + $box.width)
    $insideY = $endY -gt $box.y -and $endY -lt ($box.y + $box.height)
    if ($insideX -and $insideY) {
      "ARROW ENDS INSIDE A BOX  $($arrow.id) -> $($box.id) at [$endX,$endY]"
      $problems++
    }
  }

  foreach ($end in @(
    @{ name = 'start'; x = $arrow.x; y = $arrow.y },
    @{ name = 'end'; x = $endX; y = $endY }
  )) {
    $touches = $false
    foreach ($box in $boxes) {
      $nearX = $end.x -ge ($box.x - $tolerance) -and $end.x -le ($box.x + $box.width + $tolerance)
      $nearY = $end.y -ge ($box.y - $tolerance) -and $end.y -le ($box.y + $box.height + $tolerance)
      if ($nearX -and $nearY) { $touches = $true; break }
    }
    if (-not $touches) {
      "ARROW $($end.name.ToUpper()) IS DETACHED  $($arrow.id) at [$($end.x),$($end.y)]"
      $problems++
    }
  }
}

# Excalidraw renders bound text at its natural width -- it does not wrap to
# the container -- so a line longer than its box spills out of both sides.
# The hand-drawn font averages about 0.54em per character, which is close
# enough to catch a line that is over, and deliberately loose enough not to
# flag one that is merely full.
foreach ($text in $texts) {
  if (-not $text.containerId) { continue }
  $box = $boxes | Where-Object { $_.id -eq $text.containerId }
  if (-not $box) { continue }
  $perChar = $text.fontSize * 0.54
  foreach ($line in ($text.text -split "`n")) {
    $estimated = $line.Length * $perChar
    if ($estimated -gt $box.width) {
      "TEXT OVERFLOWS  $($text.id) in $($box.id): $($line.Length) chars ~ $([int]$estimated)px > $($box.width)px"
      "    `"$line`""
      $problems++
    }
  }
}

# A wrong Set-Content encoding silently replaces every em dash and middle
# dot with U+FFFD -- this is exactly how that was found the first time, by
# reading the file back rather than trusting what the script thought it wrote.
foreach ($text in $texts) {
  if ($text.text -and $text.text.Contains([char]0xFFFD)) {
    "ENCODING CORRUPTED  $($text.id): $($text.text)"
    $problems++
  }
}

if ($problems -eq 0) { 'OK: no overlaps, no arrow ends inside a box, no text overflow, no encoding corruption' }
else { "$problems problem(s)" }
