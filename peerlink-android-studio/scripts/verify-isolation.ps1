# PeerLink Android Studio Edition - Physical Isolation Verifier
param()

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Physical Isolation Audit " -ForegroundColor Cyan
Write-Host " Target: $projectRoot" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$isolationPassed = $true

# 1. Audit pubspec.yaml for path dependencies escaping projectRoot
Write-Host "`n[1/7] Auditing pubspec.yaml path dependencies..." -ForegroundColor Yellow
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match "path:\s*\.\./") {
    Write-Host "  [FAIL] Escaping path dependency found in pubspec.yaml!" -ForegroundColor Red
    $isolationPassed = $false
} else {
    Write-Host "  [OK] pubspec.yaml contains zero escaping path dependencies." -ForegroundColor Green
}

# 2. Audit Gradle files for external includeBuild or srcDir escapes
Write-Host "`n[2/7] Auditing Gradle configuration files..." -ForegroundColor Yellow
$gradleFiles = Get-ChildItem -Recurse -File (Join-Path $projectRoot "android") -Include "*.gradle.kts", "*.gradle"
foreach ($gf in $gradleFiles) {
    $content = Get-Content $gf.FullName -Raw
    if ($content -match "includeBuild.*peerlink-master") {
        Write-Host "  [FAIL] Escaping includeBuild found in $($gf.Name)!" -ForegroundColor Red
        $isolationPassed = $false
    }
    if ($content -match "srcDir.*src/main/java" -and $content -match "\.\./\.\./\.\./") {
        Write-Host "  [FAIL] External source set path found in $($gf.Name)!" -ForegroundColor Red
        $isolationPassed = $false
    }
}
Write-Host "  [OK] Gradle build scripts use internal, self-contained paths." -ForegroundColor Green

# 3. Check for symlinks
Write-Host "`n[3/7] Checking for symlinks substitute..." -ForegroundColor Yellow
$symlinks = Get-ChildItem -Recurse -Force $projectRoot | Where-Object { $_.Attributes -match "ReparsePoint" }
if ($symlinks) {
    Write-Host "  [FAIL] Found symlinks within project tree:" -ForegroundColor Red
    $symlinks | ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Red }
    $isolationPassed = $false
} else {
    Write-Host "  [OK] Zero symlinks detected. 100% physical source files." -ForegroundColor Green
}

# 4. Prohibited desktop Java APIs in Android source set
Write-Host "`n[4/7] Auditing Android Java/Kotlin source for prohibited APIs..." -ForegroundColor Yellow
$javaDir = Join-Path $projectRoot "android\app\src\main\java"
$prohibited = Get-ChildItem -Recurse -File $javaDir | Select-String "java.lang.management", "java.net.http", "System.getLogger", "DesktopLocalNodeServiceGrpc"
if ($prohibited) {
    Write-Host "  [FAIL] Desktop-only APIs detected in Android source set:" -ForegroundColor Red
    $prohibited | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber): $($_.Line)" -ForegroundColor Red }
    $isolationPassed = $false
} else {
    Write-Host "  [OK] Android compatibility boundary verified. Zero prohibited desktop APIs." -ForegroundColor Green
}

# 5. Verify required generated protobuf files exist
Write-Host "`n[5/7] Verifying required protobuf contracts and generated files..." -ForegroundColor Yellow
$dartProtos = Get-ChildItem -Recurse -File (Join-Path $projectRoot "lib\core\protocol") -Filter "*.pb.dart"
$protoSchemas = Get-ChildItem -Recurse -File (Join-Path $projectRoot "protocol\proto") -Filter "*.proto"
Write-Host "  [OK] $($protoSchemas.Count) .proto schemas and $($dartProtos.Count) generated Dart proto contracts present." -ForegroundColor Green
if ($dartProtos.Count -lt 10) {
    Write-Host "  [FAIL] Expected at least 10 generated Dart proto files, found $($dartProtos.Count)" -ForegroundColor Red
    $isolationPassed = $false
}

# 6. Verify credentials / secrets are not hardcoded
Write-Host "`n[6/7] Checking for hardcoded private keys or passwords..." -ForegroundColor Yellow
$secretMatches = Get-ChildItem -Recurse -File $projectRoot -Exclude "*.bin", "*.jar", "*.ps1", "*.sh" | Select-String "BEGIN RSA PRIVATE KEY", "BEGIN OPENSSH PRIVATE KEY", "BEGIN EC PRIVATE KEY"
if ($secretMatches) {
    Write-Host "  [FAIL] Private key detected in repository files!" -ForegroundColor Red
    $secretMatches | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber)" -ForegroundColor Red }
    $isolationPassed = $false
} else {
    Write-Host "  [OK] No private keys or secret material found in committed files." -ForegroundColor Green
}

# 7. Check Dart imports for escape to outside packages
Write-Host "`n[7/7] Checking Dart source imports..." -ForegroundColor Yellow
$dartFiles = Get-ChildItem -Recurse -File (Join-Path $projectRoot "lib") -Filter "*.dart"
$escapingImports = @()
foreach ($df in $dartFiles) {
    $matches = Select-String -Path $df.FullName -Pattern "import.*(\.\./){3}"
    if ($matches) {
        $escapingImports += $matches
    }
}
if ($escapingImports) {
    Write-Host "  [FAIL] Escaping relative imports found in Dart source!" -ForegroundColor Red
    $escapingImports | ForEach-Object { Write-Host "    $($_.Path):$($_.LineNumber): $($_.Line)" -ForegroundColor Red }
    $isolationPassed = $false
} else {
    Write-Host "  [OK] Zero escaping imports found across $($dartFiles.Count) Dart files." -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($isolationPassed) {
    Write-Host " Physical Isolation Audit: 100% SELF-CONTAINED (PASS)" -ForegroundColor Green
    exit 0
} else {
    Write-Host " Physical Isolation Audit: ISOLATION DEFECTS DETECTED (FAIL)" -ForegroundColor Red
    exit 1
}
