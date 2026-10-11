# PeerLink Windows Project Opener
# Opens the self-contained Windows project in the user's IDE.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Project IDE Entry Point" -ForegroundColor Cyan
Write-Host " Project Location: $windowsDir" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check for VS Code or Antigravity IDE
$ideCommand = $null
if (Get-Command code -ErrorAction SilentlyContinue) {
    $ideCommand = "code"
} elseif (Get-Command agy -ErrorAction SilentlyContinue) {
    $ideCommand = "agy"
}

if ($ideCommand) {
    Write-Host "Opening project in $ideCommand..." -ForegroundColor Green
    & $ideCommand $windowsDir
} else {
    Write-Host "No registered CLI IDE found (code/agy). Opening File Explorer..." -ForegroundColor Yellow
    Start-Process explorer.exe $windowsDir
}

Write-Host "`nWorkflow Entry Points:" -ForegroundColor Cyan
Write-Host "  Check Prerequisites:    powershell -File scripts\check-prerequisites.ps1" -ForegroundColor Gray
Write-Host "  Resolve Dependencies:   powershell -File scripts\resolve-dependencies.ps1" -ForegroundColor Gray
Write-Host "  Build Application:      powershell -File scripts\build-windows.ps1" -ForegroundColor Gray
Write-Host "  Run Application:        powershell -File scripts\run-windows.ps1" -ForegroundColor Gray
Write-Host "  Run Tests:              powershell -File scripts\run-tests.ps1" -ForegroundColor Gray
Write-Host "  Open Visual Studio:     powershell -File scripts\open-visual-studio.ps1 (Native C++ Runner only)" -ForegroundColor Gray
Write-Host "  Collect Diagnostics:    powershell -File scripts\collect-diagnostics.ps1" -ForegroundColor Gray

exit 0
