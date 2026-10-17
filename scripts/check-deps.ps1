# PeerLink Dependency Boundary Verification Script
# Enforces architectural constraints:
# 1. No Spring Boot
# 2. No Redis
# 3. No JavaFX
# 4. No OS-specific APIs in portable core

$ErrorActionPreference = "Stop"

Write-Host "Verifying PeerLink architectural boundaries and forbidden dependencies..." -ForegroundColor Cyan

$forbiddenPatterns = @(
    "org.springframework",
    "spring-boot",
    "redis.clients",
    "io.lettuce",
    "javafx",
    "org.openjfx"
)

$violations = 0

# Check pom.xml files
$poms = Get-ChildItem -Path . -Filter "pom.xml" -Recurse
foreach ($pom in $poms) {
    $content = Get-Content $pom.FullName -Raw
    foreach ($pattern in $forbiddenPatterns) {
        # Allow only the enforcer rule definition in parent pom
        if ($content -match $pattern -and -not ($pom.FullName -match "pom.xml" -and $content -match "bannedDependencies")) {
            Write-Host "VIOLATION: Found forbidden dependency pattern '$pattern' in $($pom.FullName)" -ForegroundColor Red
            $violations++
        }
    }
}

# Check platform source directories for OS-specific or forbidden imports
$platforms = @("windows", "linux", "macos", "android", "core")
foreach ($plat in $platforms) {
    $srcPath = Join-Path $plat "src\main\java"
    if (Test-Path $srcPath) {
        $sources = Get-ChildItem -Path $srcPath -Filter "*.java" -Recurse -ErrorAction SilentlyContinue
        foreach ($src in $sources) {
            $content = Get-Content $src.FullName -Raw
            if ($content -match "import android\." -or $content -match "import com\.sun\." -or $content -match "import javafx\.") {
                Write-Host "VIOLATION: $plat source imports OS-specific or banned package in $($src.FullName)" -ForegroundColor Red
                $violations++
            }
        }
    }
}

# Verify no platform references another platform's source or retired apps directory
$retiredAppSlash = "apps/" + "peerlink-app"
$retiredAppBackslash = "apps\" + "peerlink-app"
$buildFiles = Get-ChildItem -Path . -Include "pom.xml","pubspec.yaml","build.gradle.kts","build.gradle" -Recurse | Where-Object {
    $_.FullName -notmatch "node_modules|\.git|target|\.dart_tool"
}
foreach ($bf in $buildFiles) {
    $content = Get-Content $bf.FullName -Raw
    if ($content -match [regex]::Escape($retiredAppSlash) -or $content -match [regex]::Escape($retiredAppBackslash)) {
        Write-Host "VIOLATION: Build file references retired apps path in $($bf.FullName)" -ForegroundColor Red
        $violations++
    }
}

if ($violations -eq 0) {
    Write-Host "PASS: No forbidden dependencies or boundary violations detected." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL: Detected $violations boundary violation(s)." -ForegroundColor Red
    exit 1
}
