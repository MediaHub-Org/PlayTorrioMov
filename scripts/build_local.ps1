# Builds this person's own copies of PlayTorrio, with every key and link in .env
# compiled in: a Windows installer, and one APK each for phones (arm64) and TVs
# (arm32). Nothing here is published; the output goes to the Desktop.
#
# Usage: scripts\build_local.ps1
#
# Keys are read from .env at the repository root (see .env.example). They are
# not printed. Releases are built by GitHub Actions with no keys (see
# docs/RELEASES.md); this script is only for builds that stay on your own devices.

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env_file.ps1"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Required: the build will not run without these.
$required = 'TMDB_API_KEY', 'WYZIE_API_KEY', 'SIMKL_CLIENT_ID', 'GITHUB_SYNC_TOKEN', 'BACKUP_PASSPHRASE'
$missing = @($required | Where-Object { -not (Get-EnvValue $_) })
if ($missing) {
    throw "Missing in .env: $($missing -join ', '). See .env.example."
}

# Optional links: without them the build still works, but the device needs one
# sign-in for Simkl. Run scripts\link_simkl.ps1 once.
$links = @{
    'SIMKL_ACCESS_TOKEN' = 'Simkl is not linked: run scripts\link_simkl.ps1 once.'
}
foreach ($key in $links.Keys) {
    if (-not (Get-EnvValue $key)) { Write-Warning $links[$key] }
}

# TorrServer for the Windows build: the plugin's own download is gone, so the
# pinned binary comes from our release. The checksum must match before use.
$tsTag = 'torrserver-MatriX.148'
$tsSha = '92624fffc72c79d87041f6624850070e466972323ed28f14881a4c0a0c943ee6'
$tsDir = Join-Path $env:TEMP 'torrserver-stage'
$tsBin = Join-Path $tsDir 'torrserver-windows-amd64.exe'
New-Item -ItemType Directory -Force -Path $tsDir | Out-Null
function Get-FileSha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}
# An older TorrServer may sit here from a previous build: replace it unless it
# is the pinned file already.
if ((Get-FileSha $tsBin) -ne $tsSha) {
    gh release download $tsTag -R MediaHub-Org/PlayTorrioMov -p 'torrserver-windows-amd64.exe' -D $tsDir --clobber
}
$got = Get-FileSha $tsBin
if ($got -ne $tsSha) {
    throw "TorrServer checksum mismatch ($got). Expected $tsSha from $tsTag."
}
$env:TORRSERVER_FLUTTER_LOCAL_BINARIES = $tsDir

$version = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value.Split('+')[0]
$out = Join-Path ([Environment]::GetFolderPath('Desktop')) "PlayTorrioMov-$version-local"
New-Item -ItemType Directory -Force -Path $out | Out-Null

Write-Host "== Windows app ($version)"
flutter build windows --release --dart-define-from-file=.env
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed ($LASTEXITCODE)" }

Write-Host '== Windows installer'
$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 is not installed: winget install JRSoftware.InnoSetup' }
$installerOut = Join-Path $env:TEMP 'playtorrio-installer'
& $iscc "/DMyAppVersion=$version" "/O$installerOut" 'installer\windows\setup.iss'
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $installerOut 'PlayTorrioMov-Windows-Setup.exe') `
    -Destination (Join-Path $out "PlayTorrioMov-$version-Windows-Setup.exe") -Force

Write-Host '== Android APKs (arm64 for phones, arm32 for TV)'
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --dart-define-from-file=.env
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed ($LASTEXITCODE)" }
$apk = Join-Path $root 'build\app\outputs\flutter-apk'
Copy-Item -LiteralPath (Join-Path $apk 'app-arm64-v8a-release.apk') `
    -Destination (Join-Path $out "PlayTorrioMov-$version-arm64-v8a.apk") -Force
Copy-Item -LiteralPath (Join-Path $apk 'app-armeabi-v7a-release.apk') `
    -Destination (Join-Path $out "PlayTorrioMov-$version-armeabi-v7a.apk") -Force

Write-Host "== Done: $out"
Get-ChildItem -LiteralPath $out | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
