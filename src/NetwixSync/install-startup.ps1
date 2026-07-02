<#
    install-startup.ps1 — make NetwixSync coordinate with the NetWix server automatically.

    Publishes NetwixSync, saves your ingest token, and registers a Windows Scheduled
    Task that runs it in --loop mode at every logon (auto-restarts if it stops). After
    this, a customer clicking an un-mirrored rongyok episode gets it downloaded from
    this (residential) PC within one poll cycle — no manual step.

    Usage (PowerShell, in this folder):
        ./install-startup.ps1 -Token <NETWIX_INGEST_TOKEN>
        ./install-startup.ps1 -Token <t> -Interval 30      # poll every 30s

    The token is on the server at /home/admin/.netwix_ingest_token
    Remove later with:  Unregister-ScheduledTask -TaskName NetwixSync -Confirm:$false
#>
param(
    [Parameter(Mandatory = $true)][string]$Token,
    [int]$Interval = 60
)
$ErrorActionPreference = 'Stop'

$proj = Join-Path $PSScriptRoot 'NetwixSync.csproj'
$appDir = Join-Path $env:LOCALAPPDATA 'NetwixSync\app'
$cfgDir = Join-Path $env:APPDATA 'NetwixSync'
New-Item -ItemType Directory -Force -Path $appDir, $cfgDir | Out-Null

# Save the token (read by NetwixSync when --token/env are absent).
Set-Content -Path (Join-Path $cfgDir 'token.txt') -Value $Token -NoNewline -Encoding ascii

Write-Host 'Publishing NetwixSync…'
dotnet publish $proj -c Release -o $appDir --nologo | Out-Null
$exe = Join-Path $appDir 'NetwixSync.exe'
if (-not (Test-Path $exe)) { throw "publish failed: $exe not found" }

Write-Host 'Registering scheduled task (runs at logon, loop mode)…'
$action   = New-ScheduledTaskAction -Execute $exe -Argument "--loop $Interval" -WorkingDirectory $appDir
$trigger  = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
Register-ScheduledTask -TaskName 'NetwixSync' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName 'NetwixSync'
Write-Host "`n✅ Done. NetwixSync is now running in the background and will start on every logon." -ForegroundColor Green
Write-Host "   Poll interval: $Interval s.  Logs: run '$exe --loop $Interval' in a console to watch live."
