# PeerLink Open Visual Studio for Native Windows Runner Debugging
# Opens the native C++ Windows runner in Visual Studio.
#
# IMPORTANT NOTICE:
# Visual Studio is NOT a Flutter/Dart IDE replacement!
# Visual Studio is used exclusively for debugging the native Win32/C++ runner host
# (runner.exe, flutter_window.cpp, win32_window.cpp, and Win32 platform channels).
# For Dart/Flutter UI development, use VS Code, Android Studio, or Antigravity IDE.

param (
    [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$runnerDir = Join-Path $windowsDir 'app\flutter\windows'
$buildSln = Join-Path $windowsDir 'app\flutter\build\windows\peerlink.sln'

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ' PeerLink Native Windows Runner — Visual Studio Launcher' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host 'NOTE: Visual Studio is strictly for native C++ runner and Win32' -ForegroundColor Yellow
Write-Host '      platform debugging. Use VS Code or Antigravity for Dart/UI.' -ForegroundColor Yellow
Write-Host '----------------------------------------------------------' -ForegroundColor Gray

# 1. Query Visual Studio Installation via vswhere.exe
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$devenvPath = $null

if (Test-Path $vsWhere) {
    try {
        $installPath = & $vsWhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($installPath) {
            $candidateDevenv = Join-Path $installPath 'Common7\IDE\devenv.exe'
            if (Test-Path $candidateDevenv) {
                $devenvPath = $candidateDevenv
            }
        }
    } catch {
        Write-Host 'Warning: Error executing vswhere.' -ForegroundColor Yellow
    }
}

if (-not $devenvPath) {
    # Check if devenv is directly in PATH
    $cmdDevenv = Get-Command devenv -ErrorAction SilentlyContinue
    if ($cmdDevenv) {
        $devenvPath = $cmdDevenv.Source
    }
}

if (-not $devenvPath) {
    Write-Host ''
    Write-Host 'BLOCKED: Visual Studio with C++ Desktop workload is not installed.' -ForegroundColor Red
    Write-Host 'To debug the native Windows C++ runner:' -ForegroundColor Yellow
    Write-Host '  1. Download and install Visual Studio Community 2022:' -ForegroundColor Yellow
    Write-Host '     https://visualstudio.microsoft.com/downloads/' -ForegroundColor Yellow
    Write-Host '  2. Ensure the "Desktop development with C++" workload is selected.' -ForegroundColor Yellow
    Write-Host '  3. Re-run this script.' -ForegroundColor Yellow
    exit 1
}

# 2. Determine Target to Open
$targetToOpen = $null
if (Test-Path $buildSln) {
    $targetToOpen = $buildSln
    Write-Host "Found generated CMake Visual Studio solution: $targetToOpen" -ForegroundColor Green
} elseif (Test-Path $runnerDir) {
    $targetToOpen = $runnerDir
    Write-Host "Generated solution not yet built; opening native runner CMake folder: $targetToOpen" -ForegroundColor Green
} else {
    Write-Error "Runner directory not found at $runnerDir."
    exit 1
}

Write-Host "Target: $targetToOpen" -ForegroundColor Cyan
Write-Host "Launcher: $devenvPath" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute: Start-Process -FilePath $devenvPath -ArgumentList ('`"' + $targetToOpen + '`"')" -ForegroundColor Yellow
    exit 0
}

Write-Host "Launching Visual Studio..." -ForegroundColor Cyan
Start-Process -FilePath $devenvPath -ArgumentList ('"' + $targetToOpen + '"')

Write-Host 'Visual Studio launched successfully.' -ForegroundColor Green
exit 0
