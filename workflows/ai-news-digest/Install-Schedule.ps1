# ============================================================
#  Install-Schedule for Everyday-AI News Agent
#  Registers the daily run for the current user. No admin needed.
#  The task runs while you are logged in.
#
#  For "run whether I am logged in or not", run Setup-Offline.ps1
#  once from an elevated PowerShell instead.
# ============================================================

param(
    [string]$Time = '09:00'
)

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'AI-News-Agent.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "AI-News-Agent.ps1 was not found next to this script."
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    throw 'PowerShell 7 (pwsh) was not found. Install it from https://aka.ms/powershell and run this again.'
}

$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'Everyday-AI News Agent' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Done. The agent will run daily at $Time while you are logged in." -ForegroundColor Green
Write-Host 'Run it now with:  Start-ScheduledTask -TaskName "Everyday-AI News Agent"'
Write-Host 'For runs while logged out, run Setup-Offline.ps1 as Administrator.' -ForegroundColor Yellow
