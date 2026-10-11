# PeerLink macOS Prerequisites Checker (Cross-Platform / Windows Host)
# Inspects host machine for Apple developer tools, Xcode, Java, and Flutter SDK.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink macOS Environment & Prerequisites Check" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$report = @()
$hasFatal = $false

# 1. Host Operating System (macOS Darwin vs other)
$isMac = $IsMacOS -or ($env:OS -match "Darwin")
$report += [PSCustomObject]@{
    Component = "Host Operating System"
    Required  = "macOS 13+ (Ventura / Sonoma / Sequoia)"
    Found     = if ($isMac) { "DARWIN" } else { "NON-DARWIN" }
    Details   = [System.Environment]::OSVersion.ToString()
}
if (-not $isMac) {
    $hasFatal = $true
}

# 2. Xcode & Developer Command Line Tools
$xcodeFound = $false
$xcodeVersion = "Missing (Requires macOS)"
try {
    $xcodeCmd = Get-Command xcodebuild -ErrorAction SilentlyContinue
    if ($xcodeCmd) {
        $out = (& xcodebuild -version 2>&1) | Out-String
        $xcodeVersion = $out.Trim().Replace("`n", " ")
        $xcodeFound = $true
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Apple Xcode IDE"
    Required  = "Xcode 14+"
    Found     = if ($xcodeFound) { "INSTALLED" } else { "MISSING" }
    Details   = $xcodeVersion
}

# 3. CocoaPods (pod)
$podFound = $false
$podVersion = "Missing"
try {
    $podCmd = Get-Command pod -ErrorAction SilentlyContinue
    if ($podCmd) {
        $out = (& pod --version 2>&1) | Out-String
        $podVersion = "v" + $out.Trim()
        $podFound = $true
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "CocoaPods (pod)"
    Required  = "1.12+"
    Found     = if ($podFound) { "INSTALLED" } else { "MISSING" }
    Details   = $podVersion
}

# 4. Java Runtime (Target: Java 21+ LTS)
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

# 5. Java Compiler (javac)
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

# 6. Apache Maven (mvn)
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

# 7. Flutter SDK (flutter)
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

# 8. Git
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
    Component = "Git"
    Required  = "2.30.0+"
    Found     = if ($gitFound) { "INSTALLED" } else { "MISSING" }
    Details   = $gitVersion
}

Write-Host "`n--- Verification Summary Table ---" -ForegroundColor Yellow
$report | Format-Table -AutoSize -Property Component, Required, Found, Details

Write-Host "==========================================================" -ForegroundColor Cyan
if (-not $isMac) {
    Write-Host "STATUS: BLOCKED for native macOS / Xcode build and execution." -ForegroundColor Yellow
    Write-Host "        The current host is not Apple macOS (Darwin)." -ForegroundColor Yellow
    Write-Host "        Compiling native macOS .app bundles requires an Apple Mac with Xcode." -ForegroundColor Yellow
} elseif ($hasFatal) {
    Write-Host "STATUS: FATAL - Required toolchain dependencies are missing." -ForegroundColor Red
    exit 1
} else {
    Write-Host "STATUS: Prerequisite inspection complete." -ForegroundColor Green
}
exit 0
