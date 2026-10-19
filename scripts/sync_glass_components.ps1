# sync_glass_components.ps1
# Delegates to authoritative cross-platform synchronization engine
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncScript = Join-Path $ScriptDir "sync_cross_platform.py"

Write-Host "Delegating to authoritative cross-platform synchronizer (sync_cross_platform.py)..." -ForegroundColor Cyan
& python $SyncScript --apply

if ($LASTEXITCODE -ne 0) {
    Write-Error "Synchronization failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "All components synchronized successfully." -ForegroundColor Green
