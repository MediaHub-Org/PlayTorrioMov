# Helpers for the local .env, shared by the scripts in this folder. Dot-source it:
#   . "$PSScriptRoot\env_file.ps1"
#
# The .env at the repository root is read by flutter (--dart-define-from-file)
# and is git-ignored. Values are never printed by these helpers.

$script:EnvPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'

function Get-EnvValue([string]$Key) {
    if (-not (Test-Path -LiteralPath $script:EnvPath)) { return '' }
    foreach ($line in Get-Content -LiteralPath $script:EnvPath) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*?)\s*$") {
            return $Matches[1].Trim('"', "'")
        }
    }
    return ''
}

function Set-EnvValue([string]$Key, [string]$Value) {
    $lines = @()
    if (Test-Path -LiteralPath $script:EnvPath) {
        $lines = @(Get-Content -LiteralPath $script:EnvPath)
    }
    $pattern = "^\s*$([regex]::Escape($Key))\s*="
    $replaced = $false
    $out = foreach ($line in $lines) {
        if (-not $replaced -and $line -match $pattern) {
            $replaced = $true
            "$Key=$Value"
        } else {
            $line
        }
    }
    if (-not $replaced) { $out = @($out) + "$Key=$Value" }
    # No byte-order mark: a BOM would make the first key unreadable to flutter.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($script:EnvPath, [string[]]@($out), $utf8)
}
