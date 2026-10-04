# PeerLink Developer Environment Check Script (Windows PowerShell)
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         PeerLink Windows Environment Diagnostics         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Git
Write-Host "`n[1/6] Checking Git..." -ForegroundColor Yellow
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVer = git --version
    Write-Host "  [OK] $gitVer" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Git is not found in PATH." -ForegroundColor Red
}

# 2. Check Java 25
Write-Host "`n[2/6] Checking Java 25 Runtime..." -ForegroundColor Yellow
$java25Path = "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot\bin\java.exe"
if (Test-Path $java25Path) {
    $verOut = & $java25Path -version 2>&1 | Out-String
    Write-Host "  [OK] Java 25 detected at: $java25Path" -ForegroundColor Green
    $verLine = ($verOut -split "`n")[0].Trim()
    Write-Host "       $verLine" -ForegroundColor Gray
} elseif (Get-Command java -ErrorAction SilentlyContinue) {
    $sysJava = java -version 2>&1 | Out-String
    Write-Host "  [WARN] Default system Java: $sysJava" -ForegroundColor Yellow
} else {
    Write-Host "  [FAIL] Java 25 not detected at standard location or in PATH." -ForegroundColor Red
}

# 3. Check Maven
Write-Host "`n[3/6] Checking Apache Maven..." -ForegroundColor Yellow
$mavenBin = "D:\tools\apache-maven-3.9.9\bin\mvn.cmd"
if (Test-Path $mavenBin) {
    Write-Host "  [OK] Maven 3.9.9 detected at: $mavenBin" -ForegroundColor Green
} elseif (Get-Command mvn -ErrorAction SilentlyContinue) {
    $mvnVer = mvn -v | Select-Object -First 1
    Write-Host "  [OK] $mvnVer" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Maven is not found." -ForegroundColor Red
}

# 4. Check Protoc
Write-Host "`n[4/6] Checking Protobuf Compiler (protoc)..." -ForegroundColor Yellow
$protocBin = "D:\tools\bin\protoc.exe"
if (Test-Path $protocBin) {
    $protocVer = & $protocBin --version
    Write-Host "  [OK] protoc detected: $protocVer at $protocBin" -ForegroundColor Green
} elseif (Get-Command protoc -ErrorAction SilentlyContinue) {
    $protocVer = protoc --version
    Write-Host "  [OK] $protocVer" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] protoc is not found." -ForegroundColor Red
}

# 5. Check Flutter
Write-Host "`n[5/6] Checking Flutter SDK..." -ForegroundColor Yellow
$flutterBin = "D:\tools\flutter\bin\flutter.bat"
if (Test-Path $flutterBin) {
    Write-Host "  [OK] Flutter SDK detected at: D:\tools\flutter" -ForegroundColor Green
} elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
    $flutterVer = flutter --version | Select-Object -First 1
    Write-Host "  [OK] $flutterVer" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Flutter is not found." -ForegroundColor Red
}

# 6. Check Visual Studio C++ Workload (Required for Windows native desktop builds)
Write-Host "`n[6/6] Checking Visual Studio C++ Compiler for Windows Desktop..." -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasVCC = $false
if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsInstalls) {
        $hasVCC = $true
        Write-Host "  [OK] Visual Studio C++ Workload found at: $vsInstalls" -ForegroundColor Green
    }
}
if (-not $hasVCC) {
    Write-Host "  [NOTE] Visual Studio Desktop development with C++ is not yet installed." -ForegroundColor Yellow
    Write-Host "         Required only for compiling native Windows runner (`'flutter run -d windows`')." -ForegroundColor Gray
    Write-Host "         The Dart protocol client and Java Local Node run 100% locally today." -ForegroundColor Gray
    Write-Host "         To install: run Visual Studio Installer and add 'Desktop development with C++'." -ForegroundColor Cyan
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Diagnostics complete." -ForegroundColor Cyan
