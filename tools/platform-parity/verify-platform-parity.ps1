# PeerLink Read-Only Platform Parity Verifier (PowerShell)
# Verifies bit-for-bit parity among the four retained platform projects (windows, linux, macos, android)
# without requiring an authoritative canonical source tree or selecting one platform as truth.

param(
    [string[]]$Platforms = @("windows", "linux", "macos", "android"),
    [string]$ManifestPath = "tools/platform-parity/PARITY-MANIFEST.json",
    [switch]$FailFast = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Read-Only Platform Parity Verification Tool" -ForegroundColor Cyan
Write-Host " Manifest:          $ManifestPath" -ForegroundColor Cyan
Write-Host " Target Platforms:  $($Platforms -join ', ')" -ForegroundColor Cyan
Write-Host " Mode:              Peer-to-Peer Invariant Hash Parity" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

$InvariantModules = $Manifest.invariantModules | ForEach-Object { $_.module }
$InvariantFlutterPaths = $Manifest.invariantFlutterPaths
$AndroidOnlyFlutter = $Manifest.intentionalPlatformDivergence.platformSpecificFlutterCode.androidOnly

$DiscrepancyCount = 0
$TotalChecked = 0

# Helper: Compute SHA-256
function Get-Sha256Hex([string]$filePath) {
    return (Get-FileHash $filePath -Algorithm SHA256).Hash.ToLower()
}

# ──────────────────────────────────────────────────────────────────────────
# 1. Audit Invariant Java Modules (Equal across all 4 platforms)
# ──────────────────────────────────────────────────────────────────────────
Write-Host "`n[1/4] Auditing Invariant Backend Modules across platforms..." -ForegroundColor Yellow

foreach ($Module in $InvariantModules) {
    # Collect all relative file paths across all platforms for this module
    $AllRelPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Platform in $Platforms) {
        $ModDir = Join-Path $Platform $Module
        if (Test-Path $ModDir) {
            $files = Get-ChildItem -Recurse -File $ModDir
            $basePath = (Resolve-Path $ModDir).Path
            foreach ($f in $files) {
                $rel = $f.FullName.Substring($basePath.Length).TrimStart('\', '/')
                $AllRelPaths.Add($rel) | Out-Null
            }
        }
    }

    foreach ($RelPath in $AllRelPaths) {
        $TotalChecked++
        $HashesByPlatform = @{}
        $MissingPlatforms = @()

        foreach ($Platform in $Platforms) {
            $Candidate = Join-Path (Join-Path $Platform $Module) $RelPath
            if (Test-Path $Candidate) {
                $HashesByPlatform[$Platform] = Get-Sha256Hex $Candidate
            } else {
                $MissingPlatforms += $Platform
            }
        }

        # Check for missing files on any platform
        if ($MissingPlatforms.Count -gt 0) {
            Write-Host "  [MISSING INVARIANT FILE] Module: $Module | Path: $RelPath" -ForegroundColor Red
            Write-Host "    Missing on: $($MissingPlatforms -join ', ')" -ForegroundColor Red
            $DiscrepancyCount++
            if ($FailFast) { exit 1 }
            continue
        }

        # Check for hash discrepancies across platforms
        $DistinctHashes = $HashesByPlatform.Values | Select-Object -Unique
        if ($DistinctHashes.Count -gt 1) {
            Write-Host "  [INVARIANT HASH MISMATCH] Module: $Module | Path: $RelPath" -ForegroundColor Red
            foreach ($Platform in $Platforms) {
                Write-Host "    $Platform : $($HashesByPlatform[$Platform])" -ForegroundColor Gray
            }
            $DiscrepancyCount++
            if ($FailFast) { exit 1 }
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────
# 2. Audit Invariant Flutter Paths
# ──────────────────────────────────────────────────────────────────────────
Write-Host "`n[2/4] Auditing Invariant Flutter UI Paths across platforms..." -ForegroundColor Yellow

foreach ($RelFlutterPath in $InvariantFlutterPaths) {
    # Check if this is a directory or single file
    $IsDirectory = -not ($RelFlutterPath -match '\.[a-zA-Z0-9]+$')

    $AllFlutterFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($Platform in $Platforms) {
        $FullPath = Join-Path "$Platform/app/flutter" $RelFlutterPath
        if (Test-Path $FullPath) {
            if ($IsDirectory) {
                $files = Get-ChildItem -Recurse -File $FullPath
                $base = (Resolve-Path "$Platform/app/flutter").Path
                foreach ($f in $files) {
                    $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
                    $AllFlutterFiles.Add($rel) | Out-Null
                }
            } else {
                $AllFlutterFiles.Add($RelFlutterPath) | Out-Null
            }
        }
    }

    foreach ($FileRel in $AllFlutterFiles) {
        $TotalChecked++
        $HashesByPlatform = @{}
        $MissingPlatforms = @()

        foreach ($Platform in $Platforms) {
            $Target = Join-Path "$Platform/app/flutter" $FileRel
            if (Test-Path $Target) {
                $HashesByPlatform[$Platform] = Get-Sha256Hex $Target
            } else {
                $MissingPlatforms += $Platform
            }
        }

        if ($MissingPlatforms.Count -gt 0) {
            Write-Host "  [MISSING FLUTTER FILE] Path: $FileRel" -ForegroundColor Red
            Write-Host "    Missing on: $($MissingPlatforms -join ', ')" -ForegroundColor Red
            $DiscrepancyCount++
            if ($FailFast) { exit 1 }
            continue
        }

        $DistinctHashes = $HashesByPlatform.Values | Select-Object -Unique
        if ($DistinctHashes.Count -gt 1) {
            Write-Host "  [FLUTTER HASH MISMATCH] Path: $FileRel" -ForegroundColor Red
            foreach ($Platform in $Platforms) {
                Write-Host "    $Platform : $($HashesByPlatform[$Platform])" -ForegroundColor Gray
            }
            $DiscrepancyCount++
            if ($FailFast) { exit 1 }
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────
# 3. Verify Build Graphs Have Zero Retired Common-Source Dependencies
# ──────────────────────────────────────────────────────────────────────────
Write-Host "`n[3/4] Auditing Platform Build Graphs & Configurations for Retired References..." -ForegroundColor Yellow

$ForbiddenKeywords = @(
    "apps/peerlink-app",
    "apps\\peerlink-app",
    "shared-source/canonical",
    "shared-source\\canonical"
)

$BuildFiles = @()
foreach ($Platform in $Platforms) {
    $BuildFiles += Get-ChildItem -Path $Platform -Include "pom.xml", "pubspec.yaml", "build.gradle*", "CMakeLists.txt", "*.podspec" -Recurse -File
}

foreach ($bf in $BuildFiles) {
    $content = Get-Content $bf.FullName -Raw
    foreach ($kw in $ForbiddenKeywords) {
        if ($content -match [regex]::Escape($kw)) {
            Write-Host "  [FORBIDDEN REFERENCE] Build file '$($bf.FullName)' contains reference to retired path: $kw" -ForegroundColor Red
            $DiscrepancyCount++
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────
# 4. Verify Platform Scripts Do Not Reference Retired Paths
# ──────────────────────────────────────────────────────────────────────────
Write-Host "`n[4/4] Auditing Platform Scripts for Retired Source References..." -ForegroundColor Yellow

$ScriptDirs = @("scripts", "windows/scripts", "linux/scripts", "macos/scripts", "android/scripts")
foreach ($sd in $ScriptDirs) {
    if (Test-Path $sd) {
        $scripts = Get-ChildItem -Path $sd -Include "*.ps1", "*.sh", "*.bat", "*.cmd" -Recurse -File
        foreach ($sc in $scripts) {
            # Skip historical setup-platform-trees / populate-canonical migration scripts
            if ($sc.Name -match "setup-platform-trees|populate-canonical") { continue }
            $content = Get-Content $sc.FullName -Raw
            foreach ($kw in $ForbiddenKeywords) {
                if ($content -match [regex]::Escape($kw)) {
                    Write-Host "  [FORBIDDEN SCRIPT REFERENCE] Script '$($sc.FullName)' references retired path: $kw" -ForegroundColor Red
                    $DiscrepancyCount++
                }
            }
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────
# Parity Summary
# ──────────────────────────────────────────────────────────────────────────
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Parity Verification Summary:" -ForegroundColor Cyan
Write-Host " Total Invariant Relative Files Checked: $TotalChecked" -ForegroundColor Gray
Write-Host " Total Discrepancies Detected:          $DiscrepancyCount" -ForegroundColor $(if ($DiscrepancyCount -eq 0) { "Green" } else { "Red" })

if ($DiscrepancyCount -eq 0) {
    Write-Host " Status: PASS (Zero Accidental Drift; Perfect Peer-to-Peer Parity)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host " Status: FAIL ($DiscrepancyCount discrepancies detected)" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Cyan
    exit 1
}
