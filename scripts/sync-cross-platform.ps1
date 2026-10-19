# sync-cross-platform.ps1
# PowerShell wrapper for sync_cross_platform.py

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [switch]$DryRun,
    [string]$JsonReport = "",
    [string[]]$Targets
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PythonScript = Join-Path $PSScriptRoot "sync_cross_platform.py"

$ArgsList = @()

if ($DryRun) {
    $ArgsList += "--dry-run"
} elseif ($Apply -or $PSCmdlet.ShouldProcess("Synchronize maintained targets with peerlink-android-studio", "Apply")) {
    $ArgsList += "--apply"
}

if ($JsonReport) {
    $ArgsList += "--json"
    $ArgsList += $JsonReport
}

if ($Targets) {
    $ArgsList += "--targets"
    $ArgsList += $Targets
}

Write-Host "Running PeerLink cross-platform source synchronization..." -ForegroundColor Cyan
& python $PythonScript $ArgsList

if ($LASTEXITCODE -ne 0) {
    Write-Error "Synchronization failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
