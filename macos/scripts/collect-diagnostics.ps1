# PeerLink macOS Diagnostics Collection Script (Cross-Platform)
# Gathers host system environment, developer toolchains, network ports, and Local Node logs.

param (
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$macosDir = Split-Path -Parent $scriptDir
$diagOutput = [System.Text.StringBuilder]::new()

function Write-Diag([string]$text, [string]$color = "White") {
    Write-Host $text -ForegroundColor $color
    [void]$diagOutput.AppendLine($text)
}

Write-Diag "==========================================================" "Cyan"
Write-Diag " PeerLink macOS System & Runtime Diagnostics" "Cyan"
Write-Diag " Timestamp: $([DateTime]::UtcNow.ToString('o'))" "Cyan"
Write-Diag " Base Directory: $macosDir" "Cyan"
Write-Diag "==========================================================" "Cyan"

# 1. Operating System Details
Write-Diag "`n--- 1. Operating System & Host Environment ---" "Yellow"
$isMac = $IsMacOS -or ($env:OS -match "Darwin")
if ($isMac) {
    Write-Diag "Host OS:         Apple macOS (Darwin)" "Green"
} else {
    Write-Diag "Host OS:         Non-macOS Host ($([System.Environment]::OSVersion))" "Yellow"
}

# 2. Apple Developer Tools & Xcode
Write-Diag "`n--- 2. Apple Developer Tools ---" "Yellow"
$xcodeCmd = Get-Command xcodebuild -ErrorAction SilentlyContinue
if ($xcodeCmd) {
    $xcodeVer = (& xcodebuild -version 2>&1) | Out-String
    Write-Diag "Xcode CLI:       FOUND ($($xcodeVer.Trim().Replace("`n", " ")))" "Green"
} else {
    Write-Diag "Xcode CLI:       NOT INSTALLED (Requires Apple macOS)" "Yellow"
}

# 3. Java Environment
Write-Diag "`n--- 3. Java Environment ---" "Yellow"
Write-Diag "JAVA_HOME:       $($env:JAVA_HOME)" "Gray"
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if ($javaCmd) {
    Write-Diag "Java Path:       $($javaCmd.Source)" "Gray"
    $javaVer = cmd.exe /c "java -version 2>&1"
    Write-Diag "Java Version Output:`n$($javaVer.Trim())" "Gray"
} else {
    Write-Diag "Java Executable: NOT FOUND" "Red"
}

# 4. Toolchain Status
Write-Diag "`n--- 4. Toolchain Inspection ---" "Yellow"
$tools = @("javac", "mvn", "flutter", "dart", "pod", "git")
foreach ($t in $tools) {
    $cmd = Get-Command $t -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Diag "  $($t.PadRight(10)): FOUND ($($cmd.Source))" "Green"
    } else {
        Write-Diag "  $($t.PadRight(10)): NOT FOUND" "Yellow"
    }
}

# 5. Network Port Availability (50051 IPC, 53317 P2P)
Write-Diag "`n--- 5. Network Port Status ---" "Yellow"
$portsToCheck = @(50051, 53317)
foreach ($port in $portsToCheck) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Diag "  Port $port : IN USE by Process ID $($conn.OwningProcess[0]) (State: $($conn.State[0]))" "Yellow"
    } else {
        Write-Diag "  Port $port : AVAILABLE" "Green"
    }
}

# 6. Credential Store Status
Write-Diag "`n--- 6. macOS Credential Store Location ---" "Yellow"
$credDir = Join-Path $macosDir "data\node1\credentials"
if (Test-Path $credDir) {
    $credCount = (Get-ChildItem $credDir -Filter "*.cred" -ErrorAction SilentlyContinue).Count
    Write-Diag "  Credential Directory: $credDir (Found $credCount stored encrypted credentials)" "Green"
} else {
    Write-Diag "  Credential Directory: $credDir (Not yet initialized)" "Gray"
}

# 7. Local Node Logs
Write-Diag "`n--- 7. Local Node Recent Logs ---" "Yellow"
$logLocations = @(
    (Join-Path $macosDir "data\node1\logs"),
    (Join-Path $macosDir "data\node1"),
    (Join-Path $macosDir "logs")
)
$foundLogs = $false
foreach ($loc in $logLocations) {
    if (Test-Path $loc) {
        $recentLogFiles = Get-ChildItem -Path $loc -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($recentLogFiles) {
            $latest = $recentLogFiles[0]
            Write-Diag "  Latest log file: $($latest.FullName)" "Gray"
            $tail = Get-Content $latest.FullName -Tail 15 -ErrorAction SilentlyContinue
            if ($tail) {
                Write-Diag "  --- Tail: ---" "Gray"
                foreach ($l in $tail) { Write-Diag "    $l" "Gray" }
            }
            $foundLogs = $true
            break
        }
    }
}
if (-not $foundLogs) {
    Write-Diag "  No log files recorded yet." "Gray"
}

Write-Diag "`n==========================================================" "Cyan"
Write-Diag " Diagnostics Collection Complete." "Cyan"
Write-Diag "==========================================================" "Cyan"

if ($OutputFile) {
    $diagOutput.ToString() | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "Diagnostics saved to: $OutputFile" -ForegroundColor Green
}

exit 0
