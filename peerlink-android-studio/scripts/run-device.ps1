<#
.SYNOPSIS
    Lists connected devices and launches PeerLink on an Android device or emulator.
#>
[CmdletBinding()]
param(
    [string]$DeviceId
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Device Launcher          " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

Write-Host "`nDetecting available Android devices and emulators..." -ForegroundColor Yellow
$devicesOutput = flutter devices 2>&1
Write-Host ($devicesOutput -join "`n")

if ($DeviceId) {
    Write-Host "`nLaunching on specified device: $DeviceId..." -ForegroundColor Yellow
    flutter run -d $DeviceId
} else {
    Write-Host "`nLaunching on default available device/emulator..." -ForegroundColor Yellow
    flutter run
}
