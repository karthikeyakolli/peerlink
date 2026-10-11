# PeerLink Windows Prerequisites Checker
# Inspects the host machine for required tools, compilers, and runtimes.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Windows Environment & Prerequisites Check" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$report = @()
$hasFatal = $false

# 1. Java Runtime (Target: Java 21+ LTS)
$javaFound = $false
$javaVersion = "Missing"
try {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $output = (& java -version 2>&1) | Out-String
        if ($output -match 'version "([^"]+)"') {
            $javaVersion = $matches[1]
            $javaFound = $true
        } else {
            $javaVersion = "Detected (" + $javaCmd.Source + ")"
            $javaFound = $true
        }
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Java Runtime (JRE)"
    Required  = "Java 21 LTS or 25"
    Found     = if ($javaFound) { "INSTALLED" } else { "MISSING" }
    Details   = $javaVersion
}
if (-not $javaFound) { $hasFatal = $true }

# 2. Java Compiler (javac)
$javacFound = $false
$javacVersion = "Missing"
try {
    $javacCmd = Get-Command javac -ErrorAction SilentlyContinue
    if ($javacCmd) {
        $output = (& javac -version 2>&1) | Out-String
        $javacVersion = $output.Trim()
        $javacFound = $true
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Java Compiler (javac)"
    Required  = "JDK 21 or 25"
    Found     = if ($javacFound) { "INSTALLED" } else { "MISSING" }
    Details   = $javacVersion
}

# 3. Apache Maven (mvn)
$mvnFound = $false
$mvnVersion = "Missing"
try {
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        $output = (& mvn -version 2>&1) | Out-String
        if ($output -match 'Apache Maven ([^\s]+)') {
            $mvnVersion = "v" + $matches[1]
            $mvnFound = $true
        }
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Apache Maven (mvn)"
    Required  = "3.9.0+"
    Found     = if ($mvnFound) { "INSTALLED" } else { "MISSING" }
    Details   = $mvnVersion
}

# 4. Flutter SDK (flutter)
$flutterFound = $false
$flutterVersion = "Missing"
try {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        $output = (& flutter --version 2>&1) | Out-String
        if ($output -match 'Flutter ([^\s]+)') {
            $flutterVersion = "v" + $matches[1]
            $flutterFound = $true
        }
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Flutter SDK"
    Required  = "3.24.0+ (stable)"
    Found     = if ($flutterFound) { "INSTALLED" } else { "MISSING" }
    Details   = $flutterVersion
}

# 5. Visual Studio C++ Workload (vswhere)
$vsFound = $false
$vsDetails = "Missing"
$vsInstallPath = $null
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    try {
        $installPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($installPath) {
            $displayName = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName
            $vsFound = $true
            $vsDetails = "$displayName ($installPath)"
            $vsInstallPath = $installPath
        } else {
            $vsDetails = "vswhere found, but Desktop C++ workload is not installed"
        }
    } catch {
        $vsDetails = "Error querying vswhere"
    }
} else {
    $vsDetails = "Visual Studio Installer not found"
}

$report += [PSCustomObject]@{
    Component = "Visual Studio (C++)"
    Required  = "Desktop development with C++"
    Found     = if ($vsFound) { "INSTALLED" } else { "MISSING" }
    Details   = $vsDetails
}

# 6. Git CLI
$gitFound = $false
$gitVersion = "Missing"
try {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $output = (& git --version 2>&1) | Out-String
        $gitVersion = $output.Trim()
        $gitFound = $true
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Git Version Control"
    Required  = "2.30+"
    Found     = if ($gitFound) { "INSTALLED" } else { "MISSING" }
    Details   = $gitVersion
}

# 7. CMake
$cmakeFound = $false
$cmakeVersion = "Missing"
try {
    $cmakeCmd = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmakeCmd) {
        $output = (& cmake --version 2>&1) | Out-String
        if ($output -match 'cmake version ([^\s]+)') {
            $cmakeVersion = "v" + $matches[1]
            $cmakeFound = $true
        }
    } elseif ($vsInstallPath) {
        $vsCMake = Join-Path $vsInstallPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
        if (Test-Path $vsCMake) {
            $output = (& $vsCMake --version 2>&1) | Out-String
            if ($output -match 'cmake version ([^\s]+)') {
                $cmakeVersion = "v" + $matches[1] + " (Visual Studio bundled)"
                $cmakeFound = $true
            }
        }
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "CMake"
    Required  = "3.20+"
    Found     = if ($cmakeFound) { "INSTALLED" } else { "MISSING" }
    Details   = $cmakeVersion
}

# Format Output Table
Write-Host ""
$report | Format-Table -AutoSize -Property Component, Required, Found, Details

Write-Host "==========================================================" -ForegroundColor Cyan
if ($hasFatal) {
    Write-Host "FATAL: Minimum Java 21+ runtime is NOT available." -ForegroundColor Red
    Write-Host "Install Microsoft OpenJDK 21 or 25: winget install Microsoft.OpenJDK.21" -ForegroundColor Yellow
    exit 1
} elseif (-not $flutterFound -or -not $vsFound) {
    Write-Host "STATUS: Java Local Node can run, but UI compilation is BLOCKED." -ForegroundColor Yellow
    if (-not $flutterFound) {
        Write-Host "  -> Flutter SDK is missing: Download from https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    }
    if (-not $vsFound) {
        Write-Host "  -> Visual Studio C++ is missing: Install 'Desktop development with C++' via Visual Studio Installer" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "STATUS: All prerequisites are met! Full compilation enabled." -ForegroundColor Green
    exit 0
}
