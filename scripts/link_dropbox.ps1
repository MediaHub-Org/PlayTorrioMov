# Links this person's Dropbox to the local builds, once.
#
# Dropbox opens in your browser and shows a code after you approve the app.
# Paste that code here; the script exchanges it for a refresh token and writes
# it to .env as DROPBOX_REFRESH_TOKEN. The profile sync uses that token on every
# local build, so a new install needs no Dropbox sign-in. The token is never
# printed.
#
# Usage: scripts\link_dropbox.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env_file.ps1"

$appKey = Get-EnvValue 'DROPBOX_APP_KEY'
if (-not $appKey) { throw 'DROPBOX_APP_KEY is not set in .env. Add it first.' }

# PKCE: a random verifier, and its SHA-256 as the challenge (RFC 7636).
$bytes = New-Object byte[] 64
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$verifier = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
$sha = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::ASCII.GetBytes($verifier))
$challenge = [Convert]::ToBase64String($sha).TrimEnd('=').Replace('+', '-').Replace('/', '_')

$authorize = 'https://www.dropbox.com/oauth2/authorize?' + (@(
    "client_id=$appKey"
    'response_type=code'
    "code_challenge=$challenge"
    'code_challenge_method=S256'
    'token_access_type=offline'
) -join '&')

Write-Host ''
Write-Host 'Approve PlayTorrio in the browser window that opens, then paste the code it shows.'
Start-Process $authorize
$code = (Read-Host 'Code').Trim()
if (-not $code) { throw 'No code was pasted.' }

$token = Invoke-RestMethod -Method Post -Uri 'https://api.dropboxapi.com/oauth2/token' `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{
        code          = $code
        grant_type    = 'authorization_code'
        client_id     = $appKey
        code_verifier = $verifier
    }

if (-not $token.refresh_token) {
    throw 'Dropbox did not return a refresh token. Run this script again and approve the app.'
}
Set-EnvValue 'DROPBOX_REFRESH_TOKEN' $token.refresh_token
Write-Host 'Dropbox linked. DROPBOX_REFRESH_TOKEN is now in .env.' -ForegroundColor Green
