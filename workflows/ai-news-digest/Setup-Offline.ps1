# ============================================================
#  Setup-Offline for Everyday-AI News Agent
#  Run ONCE as Administrator (right-click PowerShell -> Run as admin,
#  or start an elevated terminal and execute this file) to make the
#  daily AI-news task run EVEN WHEN YOU ARE NOT LOGGED IN.
#  Requires no password (uses S4U logon).
# ============================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'This script must be run as Administrator.' -ForegroundColor Yellow
    Write-Host 'Right-click PowerShell and choose "Run as administrator", then run:' -ForegroundColor Yellow
    Write-Host ("  " + $PSCommandPath)
    exit 1
}

$scriptPath = Join-Path $PSScriptRoot 'AI-News-Agent.ps1'
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) { $pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe' }
if (-not (Test-Path -LiteralPath $pwshPath)) {
    Write-Host 'PowerShell 7 (pwsh) not found. Install it and re-run.' -ForegroundColor Red
    exit 1
}

$user = "$env:USERDOMAIN\$env:USERNAME"

$action   = New-ScheduledTaskAction -Execute $pwshPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -Daily -At 9:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Limited

Register-ScheduledTask -TaskName 'Everyday-AI News Agent' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host 'Done. Task now runs daily at 9:00 AM whether you are logged in or not.' -ForegroundColor Green
$t = Get-ScheduledTask -TaskName 'Everyday-AI News Agent'
Write-Host ("LogonType : " + $t.Principal.LogonType)
Write-Host ("State     : " + $t.State)