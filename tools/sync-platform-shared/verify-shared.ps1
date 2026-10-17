# PeerLink Platform Shared Parity Verification Tool (PowerShell)
# Redirects to the peer-to-peer read-only platform parity verifier.

param(
    [string[]]$Platforms = @("windows", "linux", "macos", "android"),
    [string]$ManifestPath = "tools/platform-parity/PARITY-MANIFEST.json",
    [switch]$FailFast = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Verifier = Join-Path $RepoRoot "tools\platform-parity\verify-platform-parity.ps1"

& $Verifier -Platforms $Platforms -ManifestPath $ManifestPath -FailFast:$FailFast
exit $LASTEXITCODE
