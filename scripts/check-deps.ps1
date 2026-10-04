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

# Check Core module source for OS-specific or forbidden imports
$coreSources = Get-ChildItem -Path "core/src/main/java" -Filter "*.java" -Recurse -ErrorAction SilentlyContinue
foreach ($src in $coreSources) {
    $content = Get-Content $src.FullName -Raw
    if ($content -match "import android\." -or $content -match "import com\.sun\." -or $content -match "import javafx\.") {
        Write-Host "VIOLATION: Portable core imports OS-specific or banned package in $($src.FullName)" -ForegroundColor Red
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
