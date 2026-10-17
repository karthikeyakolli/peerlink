# PeerLink Run Flutter Desktop Application (Windows PowerShell)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$flutterBin = "D:\tools\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterBin)) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        $flutterBin = "flutter"
    } else {
        Write-Error "Flutter SDK not found."
    }
}

$appDir = Join-Path $repoRoot "windows\app\flutter"
Push-Location $appDir

# Check Visual Studio C++ Workload
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasVCC = $false
if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsInstalls) {
        $hasVCC = $true
    }
}

if ($hasVCC) {
    Write-Host "Starting PeerLink Flutter Windows Desktop application..." -ForegroundColor Cyan
    & $flutterBin run -d windows
} else {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "Visual Studio Desktop development with C++ is required" -ForegroundColor Yellow
    Write-Host "to compile the native Windows C++ runner executable." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "Running Flutter test suite and live IPC verification instead..." -ForegroundColor Cyan
    & $flutterBin test
}

Pop-Location
