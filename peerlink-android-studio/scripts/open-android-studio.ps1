<#
.SYNOPSIS
    Opens the standalone PeerLink Android Studio workspace.
#>
[CmdletBinding()]
param(
    [switch]$NativeOnly
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

$targetDir = if ($NativeOnly) { Join-Path $projectRoot "android" } else { $projectRoot }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Launcher                           " -ForegroundColor Cyan
Write-Host " Opening: $targetDir" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$studioPaths = @(
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "$env:LOCALAPPDATA\Programs\Android Studio\bin\studio64.exe"
)

$launched = $false
foreach ($p in $studioPaths) {
    if (Test-Path $p) {
        Write-Host "Launching Android Studio via $p..." -ForegroundColor Green
        Start-Process $p -ArgumentList "`"$targetDir`""
        $launched = $true
        break
    }
}

if (-not $launched) {
    try {
        Start-Process "studio64.exe" -ArgumentList "`"$targetDir`"" -ErrorAction Stop
        $launched = $true
    } catch {}
}

if ($launched) {
    Write-Host "[OK] Android Studio workspace launch signal sent!" -ForegroundColor Green
} else {
    Write-Host "[INFO] Could not automatically launch Android Studio." -ForegroundColor Yellow
    Write-Host "Please open Android Studio manually and select:" -ForegroundColor Yellow
    Write-Host "  -> $targetDir" -ForegroundColor Cyan
}
