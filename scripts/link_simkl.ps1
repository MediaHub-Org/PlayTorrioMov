# Links this person's Simkl account to the local builds, once.
#
# Simkl shows a short code and asks you to approve it in your own browser at
# simkl.com/pin. This script waits for that approval and writes the resulting
# token to .env as SIMKL_ACCESS_TOKEN. Every local build after that carries the
# link, so an install needs no sign-in. The token is never printed.
#
# Usage: scripts\link_simkl.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env_file.ps1"

$clientId = Get-EnvValue 'SIMKL_CLIENT_ID'
if (-not $clientId) { throw 'SIMKL_CLIENT_ID is not set in .env. Add it first.' }

$device = Invoke-RestMethod -Method Post -Uri 'https://api.simkl.com/oauth2/device' `
    -ContentType 'application/json' `
    -Body (@{ client_id = $clientId; scope = 'media:read media:write' } | ConvertTo-Json)

Write-Host ''
Write-Host "Open https://simkl.com/pin and enter this code: $($device.user_code)" -ForegroundColor Yellow
Write-Host "The code expires in $([int]($device.expires_in / 60)) minutes. Waiting for your approval..."

$deadline = (Get-Date).AddSeconds([int]$device.expires_in)
$interval = [Math]::Max(1, [int]$device.interval)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $interval
    try {
        $token = Invoke-RestMethod -Method Post -Uri 'https://api.simkl.com/oauth2/token' `
            -ContentType 'application/json' `
            -Body (@{
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
                device_code = $device.device_code
                client_id   = $clientId
            } | ConvertTo-Json)
        if ($token.access_token) {
            Set-EnvValue 'SIMKL_ACCESS_TOKEN' $token.access_token
            Write-Host 'Simkl linked. SIMKL_ACCESS_TOKEN is now in .env.' -ForegroundColor Green
            return
        }
    } catch {
        # Still pending (Simkl answers 400 until the code is approved). Anything
        # else keeps polling until the deadline, then fails below.
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -ne 400 -and $status -ne 428) { throw }
    }
}
throw 'The Simkl code expired before it was approved. Run this script again.'
