<#
.SYNOPSIS
    Resolves local dependencies, generates local.properties, and verifies build setup.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PeerLink Android Studio Edition - Workspace Setup          " -ForegroundColor Cyan
Write-Host " Root: $projectRoot" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

# 1. Run flutter pub get
Write-Host "`n[1/3] Resolving Flutter/Dart packages..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] flutter pub get failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[OK] Dependencies resolved successfully." -ForegroundColor Green

# 2. Configure android/local.properties
Write-Host "`n[2/3] Validating android/local.properties..." -ForegroundColor Yellow
$localProps = Join-Path $projectRoot "android\local.properties"
$flutterSdk = "c:\flutter"
if ($env:FLUTTER_ROOT) { $flutterSdk = $env:FLUTTER_ROOT }

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
if ($env:ANDROID_HOME) { $sdkPath = $env:ANDROID_HOME }

$propsContent = @"
sdk.dir=$($sdkPath.Replace('\', '\\'))
flutter.sdk=$($flutterSdk.Replace('\', '\\'))
flutter.buildMode=debug
flutter.versionName=0.1.0
flutter.versionCode=1
"@

Set-Content -Path $localProps -Value $propsContent -Encoding Ascii
Write-Host "[OK] Wrote android/local.properties" -ForegroundColor Green

# 3. Check Gradle Wrapper
Write-Host "`n[3/3] Checking Gradle wrapper..." -ForegroundColor Yellow
$gradlew = Join-Path $projectRoot "android\gradlew.bat"
if (Test-Path $gradlew) {
    Write-Host "[OK] Gradle wrapper is present at $gradlew" -ForegroundColor Green
} else {
    Write-Host "[FAIL] gradlew.bat missing!" -ForegroundColor Red
    exit 1
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Setup complete! Ready for Android Studio or command-line build." -ForegroundColor Green
exit 0
