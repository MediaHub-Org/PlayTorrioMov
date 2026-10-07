# Generates docs/SYNC_AND_BACKUP.excalidraw -- companion diagram to
# docs/SYNC_AND_BACKUP.md. Two columns on purpose: the doc's whole point is
# that sync (watch-history, Trakt/Simkl) and backup (this app's own local
# state) are two separate things that keep getting asked about as one, and a
# shared column boundary says that before a single word of the legend does.
#
# Same generator pattern as gen_info_diagram.ps1 -- see its own header comment
# for why this is a script and not a hand-edited JSON file. Checked the same
# way: ./scripts/check_info_diagram.ps1 -Path docs/SYNC_AND_BACKUP.excalidraw
. "$PSScriptRoot/excalidraw_lib.ps1"

$elements = [System.Collections.Generic.List[object]]::new()

# ── Palette ────────────────────────────────────────────────────────────────
# Blue and gray carry the same meaning as INFO.excalidraw's legend (entry/
# shell, and -- new here -- "built but switched off"); sync and backup are
# this diagram's own two colors, kept apart from INFO's green/orange/purple/
# yellow so the two files are never confusable at a glance.
$C = @{
  entry  = '#a5d8ff'   # blue   -- Settings UI
  sync   = '#99e9f2'   # cyan   -- watch-history sync
  backup = '#ffec99'   # yellow -- this app's own state
  off    = '#e9ecef'   # gray   -- built, switched off
  ink    = '#1e1e1e'
  edge   = '#1e1e1e'
}

Add-Title -X 60 -Y 40 -Text 'Sync & Backup — two separate things' -Size 28

# Legend
Add-Box -Id (New-Id) -X 60 -Y 92 -W 190 -H 27 -Fill $C.entry -FontSize 13 `
  -Text 'Settings UI' | Out-Null
Add-Box -Id (New-Id) -X 270 -Y 92 -W 230 -H 27 -Fill $C.sync -FontSize 13 `
  -Text 'watch-history sync' | Out-Null
Add-Box -Id (New-Id) -X 520 -Y 92 -W 230 -H 27 -Fill $C.backup -FontSize 13 `
  -Text 'this app''s own state' | Out-Null
Add-Box -Id (New-Id) -X 770 -Y 92 -W 230 -H 27 -Fill $C.off -FontSize 13 `
  -Text 'built, switched off' | Out-Null

# ── Column headers ───────────────────────────────────────────────────────────
Add-BandLabel -X 60 -Y 150 -Text 'SYNC -- goes to Trakt/Simkl''s own service, never read back as metadata'
Add-BandLabel -X 700 -Y 150 -Text 'BACKUP -- this app''s own data, round-tripped through one JSON envelope'

# Band: Settings UI
$syncSettings = Add-Box -Id (New-Id) -X 60 -Y 176 -W 580 -H 55 -Fill $C.entry -FontSize 14 `
  -Text "sync_settings_page.dart"
$backupSettings = Add-Box -Id (New-Id) -X 700 -Y 176 -W 580 -H 55 -Fill $C.entry -FontSize 14 `
  -Text "backup_settings_page.dart"

# Band: auto-backup trigger -- sync has no equivalent, it scrobbles as you
# watch rather than on a schedule, and that asymmetry is worth showing as a
# gap rather than papered over with a matching box that does nothing.
$auto = Add-Box -Id (New-Id) -X 700 -Y 271 -W 580 -H 50 -Fill $C.backup -FontSize 14 `
  -Text "AutoBackupService -- at app open, if due (day/week/month)"
Add-ArrowBetween -From $backupSettings -To $auto

# Band: providers
Add-BandLabel -X 60 -Y 361 -Text 'PROVIDERS'
$simkl = Add-Box -Id (New-Id) -X 60 -Y 388 -W 280 -H 60 -Fill $C.sync -FontSize 13 `
  -Text "Simkl`nPIN device flow -- SIMKL_CLIENT_ID`nthe one offered"
$trakt = Add-Box -Id (New-Id) -X 360 -Y 388 -W 280 -H 60 -Fill $C.off -FontSize 13 `
  -DashedStroke $true `
  -Text "Trakt`nbuilt the same way`n_traktSyncEnabled = false"
$local = Add-Box -Id (New-Id) -X 700 -Y 388 -W 180 -H 60 -Fill $C.backup -FontSize 13 `
  -Text "Local`nexport / import`na picked file"
$webdav = Add-Box -Id (New-Id) -X 900 -Y 388 -W 180 -H 60 -Fill $C.backup -FontSize 13 `
  -Text "WebDAV`nown server`nURL + user + pass"
$dropbox = Add-Box -Id (New-Id) -X 1100 -Y 388 -W 180 -H 60 -Fill $C.backup -FontSize 13 `
  -Text "Dropbox`nPKCE, pasted code`nDROPBOX_APP_KEY"

Add-ArrowBetween -From $syncSettings -To $simkl -FromOffset 0.25 -ToOffset 0.5
Add-ArrowBetween -From $syncSettings -To $trakt -FromOffset 0.75 -ToOffset 0.5
Add-ArrowBetween -From $auto -To $webdav -FromOffset 0.3 -ToOffset 0.5 -Dashed $true
Add-ArrowBetween -From $auto -To $dropbox -FromOffset 0.7 -ToOffset 0.5 -Dashed $true
Add-ArrowBetween -From $backupSettings -To $local -FromOffset 0.15 -ToOffset 0.5

# Band: what each side actually talks to
Add-BandLabel -X 60 -Y 478 -Text 'TALKS TO'
$theirService = Add-Box -Id (New-Id) -X 60 -Y 504 -W 580 -H 55 -Fill $C.sync -FontSize 14 `
  -Text "trakt.tv / simkl.com -- their history, their calendar, their site"
$envelope = Add-Box -Id (New-Id) -X 700 -Y 504 -W 580 -H 55 -Fill $C.backup -FontSize 14 `
  -Text "BackupService: buildEnvelopeJson / applyEnvelopeJson -- one shared format"

Add-ArrowBetween -From $simkl -To $theirService -FromOffset 0.25 -ToOffset 0.3
Add-ArrowBetween -From $trakt -To $theirService -FromOffset 0.75 -ToOffset 0.7 -Dashed $true
Add-ArrowBetween -From $local -To $envelope -FromOffset 0.5 -ToOffset 0.15
Add-ArrowBetween -From $webdav -To $envelope -FromOffset 0.5 -ToOffset 0.5
Add-ArrowBetween -From $dropbox -To $envelope -FromOffset 0.5 -ToOffset 0.85

# Band: storage -- the one thing both sides actually touch, which is the
# other half of "these are separate": not different data, different *paths*
# to and from the same local state.
Add-BandLabel -X 60 -Y 605 -Text 'STORAGE -- the one thing both sides touch'
$storage = Add-Box -Id (New-Id) -X 460 -Y 632 -W 420 -H 60 -Fill $C.entry -FontSize 14 `
  -Text "SharedPreferences + sqflite`nsettings · library · history · progress"

Add-ArrowBetween -From $theirService -To $storage -FromOffset 0.75 -ToOffset 0.2 -Dashed $true
Add-ArrowBetween -From $envelope -To $storage -FromOffset 0.25 -ToOffset 0.8 -Dashed $true

# ── Write ──────────────────────────────────────────────────────────────────
Write-ExcalidrawFile -Path 'docs/SYNC_AND_BACKUP.excalidraw'
