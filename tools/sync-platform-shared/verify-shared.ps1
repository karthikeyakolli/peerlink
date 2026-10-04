# PeerLink Platform Shared-Source Verification Tool (PowerShell)
param(
    [string[]]$Platforms = @("windows", "linux", "macos", "android"),
    [string]$CanonicalDir = "shared-source/canonical",
    [switch]$FailFast = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

$CanonicalRoot = Join-Path $RepoRoot $CanonicalDir
if (-not (Test-Path $CanonicalRoot)) {
    throw "Canonical directory not found: $CanonicalRoot"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Shared-Source Verification Tool" -ForegroundColor Cyan
Write-Host " Canonical Baseline: $CanonicalDir" -ForegroundColor Cyan
Write-Host " Target Platforms:   $($Platforms -join ', ')" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$SharedModules = @(
    "core",
    "protocol",
    "operations",
    "transfer",
    "sync",
    "backup",
    "access",
    "sharing",
    "workspace",
    "clipboard",
    "compatibility",
    "security",
    "recovery",
    "diagnostics"
)

$DiscrepancyCount = 0
$TotalChecked = 0

foreach ($Platform in $Platforms) {
    $PlatformRoot = Join-Path $RepoRoot $Platform
    Write-Host "`nAuditing platform: $Platform..." -ForegroundColor Yellow

    if (-not (Test-Path $PlatformRoot)) {
        Write-Host "  [MISSING PLATFORM] Platform directory does not exist: $Platform" -ForegroundColor Red
        $DiscrepancyCount++
        continue
    }

    # 1. Audit standard common modules
    foreach ($Module in $SharedModules) {
        $CanonicalModulePath = Join-Path $CanonicalRoot $Module
        $PlatformModulePath = Join-Path $PlatformRoot $Module

        if (Test-Path $CanonicalModulePath) {
            $CanonicalFiles = Get-ChildItem -Recurse -File $CanonicalModulePath

            foreach ($File in $CanonicalFiles) {
                $TotalChecked++
                $RelativePath = $File.FullName.Substring($CanonicalModulePath.Length).TrimStart('\', '/')
                $DestFile = Join-Path $PlatformModulePath $RelativePath

                if (-not (Test-Path $DestFile)) {
                    Write-Host "  [MISSING FILE] $Platform/$Module/$RelativePath" -ForegroundColor Red
                    $DiscrepancyCount++
                    if ($FailFast) { exit 1 }
                    continue
                }

                $CanonicalHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()
                $DestHash = (Get-FileHash $DestFile -Algorithm SHA256).Hash.ToLower()

                if ($CanonicalHash -ne $DestHash) {
                    Write-Host "  [HASH MISMATCH] $Platform/$Module/$RelativePath" -ForegroundColor Red
                    Write-Host "    Canonical: $CanonicalHash" -ForegroundColor Gray
                    Write-Host "    Platform:  $DestHash" -ForegroundColor Gray
                    $DiscrepancyCount++
                    if ($FailFast) { exit 1 }
                }
            }

            # Check for unexpected extra files in common platform directory
            if (Test-Path $PlatformModulePath) {
                $PlatformFiles = Get-ChildItem -Recurse -File $PlatformModulePath
                foreach ($PFile in $PlatformFiles) {
                    $RelativePath = $PFile.FullName.Substring($PlatformModulePath.Length).TrimStart('\', '/')
                    $CanonicalCorresponding = Join-Path $CanonicalModulePath $RelativePath
                    if (-not (Test-Path $CanonicalCorresponding)) {
                        Write-Host "  [UNEXPECTED FILE] $Platform/$Module/$RelativePath (Not in canonical source)" -ForegroundColor Magenta
                        $DiscrepancyCount++
                        if ($FailFast) { exit 1 }
                    }
                }
            }
        }
    }

    # 2. Audit Common Flutter application code
    $CanonicalFlutter = Join-Path $CanonicalRoot "flutter"
    $PlatformFlutter = Join-Path $PlatformRoot "app/flutter"

    if (Test-Path $CanonicalFlutter) {
        $FlutterFiles = Get-ChildItem -Recurse -File $CanonicalFlutter
        foreach ($File in $FlutterFiles) {
            $TotalChecked++
            $RelativePath = $File.FullName.Substring($CanonicalFlutter.Length).TrimStart('\', '/')
            $DestFile = Join-Path $PlatformFlutter $RelativePath

            if (-not (Test-Path $DestFile)) {
                Write-Host "  [MISSING FLUTTER FILE] $Platform/app/flutter/$RelativePath" -ForegroundColor Red
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
                continue
            }

            $CanonicalHash = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()
            $DestHash = (Get-FileHash $DestFile -Algorithm SHA256).Hash.ToLower()

            if ($CanonicalHash -ne $DestHash) {
                Write-Host "  [FLUTTER HASH MISMATCH] $Platform/app/flutter/$RelativePath" -ForegroundColor Red
                Write-Host "    Canonical: $CanonicalHash" -ForegroundColor Gray
                Write-Host "    Platform:  $DestHash" -ForegroundColor Gray
                $DiscrepancyCount++
                if ($FailFast) { exit 1 }
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Verification Summary:" -ForegroundColor Cyan
Write-Host " Total Files Audited: $TotalChecked" -ForegroundColor Gray
Write-Host " Total Discrepancies: $DiscrepancyCount" -ForegroundColor $(if ($DiscrepancyCount -eq 0) { "Green" } else { "Red" })
Write-Host " Status: $(if ($DiscrepancyCount -eq 0) { "PASS (All copies identical)" } else { "FAIL (Drift detected)" })" -ForegroundColor $(if ($DiscrepancyCount -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($DiscrepancyCount -gt 0) {
    exit 1
} else {
    exit 0
}
