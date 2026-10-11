# PeerLink Linux Prerequisites Checker (Cross-Platform / Windows Host)
# Inspects the host machine for required tools, compilers, runtimes, and WSL status.

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Linux Environment & Prerequisites Check" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$report = @()
$hasFatal = $false

# 1. WSL Environment Check (for running Linux toolchains on Windows host)
$wslFound = $false
$wslDetails = "Not installed"
try {
    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wslCmd) {
        $rawOut = (& wsl.exe -l -v 2>&1) | Out-String
        $exitCode = $LASTEXITCODE
        $cleanOut = $rawOut -replace "`0", ""
        if ($exitCode -ne 0 -or $cleanOut -match "not installed") {
            $wslDetails = "WSL is not installed on this host"
        } elseif ($cleanOut -match "no distributions installed") {
            $wslDetails = "WSL installed, but no distributions registered"
        } else {
            $wslFound = $true
            $wslDetails = "WSL distribution(s) available"
        }
    }
} catch {
    $wslDetails = "Error querying WSL: $_"
}

$report += [PSCustomObject]@{
    Component = "WSL (Windows Host)"
    Required  = "WSL2 Ubuntu/Debian (Optional on native Linux)"
    Found     = if ($wslFound) { "INSTALLED" } else { "MISSING" }
    Details   = $wslDetails
}

# 2. Java Runtime (Target: Java 21+ LTS)
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

# 3. Java Compiler (javac)
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

# 4. Apache Maven (mvn)
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

# 5. Flutter SDK (flutter)
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

# 6. CMake
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
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "CMake"
    Required  = "3.20.0+"
    Found     = if ($cmakeFound) { "INSTALLED" } else { "MISSING" }
    Details   = $cmakeVersion
}

# 7. Ninja
$ninjaFound = $false
$ninjaVersion = "Missing"
try {
    $ninjaCmd = Get-Command ninja -ErrorAction SilentlyContinue
    if ($ninjaCmd) {
        $output = (& ninja --version 2>&1) | Out-String
        $ninjaVersion = "v" + $output.Trim()
        $ninjaFound = $true
    }
} catch {}

$report += [PSCustomObject]@{
    Component = "Ninja Build"
    Required  = "Ninja 1.10+"
    Found     = if ($ninjaFound) { "INSTALLED" } else { "MISSING" }
    Details   = $ninjaVersion
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
if (-not $wslFound -and $IsWindows) {
    Write-Host "STATUS: BLOCKED for native Linux GTK/ELF execution on Windows host." -ForegroundColor Yellow
    Write-Host "        WSL is not installed. To build or execute Linux native binaries," -ForegroundColor Yellow
    Write-Host "        either run on a native Linux machine or install WSL (wsl --install)." -ForegroundColor Yellow
} elseif ($hasFatal) {
    Write-Host "STATUS: FATAL - Minimum Java 21+ runtime is required." -ForegroundColor Red
    exit 1
} else {
    Write-Host "STATUS: Prerequisite inspection complete." -ForegroundColor Green
}
exit 0
