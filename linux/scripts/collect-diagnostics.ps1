# PeerLink Linux Diagnostics Collection Script (Cross-Platform / Windows Host)
# Gathers system environment, WSL status, network ports, and Local Node logs.

param (
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$linuxDir = Split-Path -Parent $scriptDir
$diagOutput = [System.Text.StringBuilder]::new()

function Write-Diag([string]$text, [string]$color = "White") {
    Write-Host $text -ForegroundColor $color
    [void]$diagOutput.AppendLine($text)
}

Write-Diag "==========================================================" "Cyan"
Write-Diag " PeerLink Linux System & Runtime Diagnostics" "Cyan"
Write-Diag " Timestamp: $([DateTime]::UtcNow.ToString('o'))" "Cyan"
Write-Diag " Base Directory: $linuxDir" "Cyan"
Write-Diag "==========================================================" "Cyan"

# 1. Operating System Details
Write-Diag "`n--- 1. Operating System & Host Environment ---" "Yellow"
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    Write-Diag "Host OS Caption: $($os.Caption)" "Gray"
    Write-Diag "Host OS Version: $($os.Version) (Build $($os.BuildNumber))" "Gray"
    Write-Diag "Architecture:    $($os.OSArchitecture)" "Gray"
} else {
    Write-Diag "Host OS Version: $([System.Environment]::OSVersion)" "Gray"
}

# 2. WSL Environment Status
Write-Diag "`n--- 2. WSL Subsystem Status ---" "Yellow"
$wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wslCmd) {
    try {
        $rawOut = (& wsl.exe -l -v 2>&1) | Out-String
        $cleanOut = $rawOut -replace "`0", ""
        if ($LASTEXITCODE -ne 0 -or $cleanOut -match "not installed") {
            Write-Diag "WSL Subsystem:   NOT INSTALLED on host" "Yellow"
        } else {
            Write-Diag "WSL CLI:         FOUND ($($wslCmd.Source))" "Green"
            Write-Diag "WSL Distributions:`n$($cleanOut.Trim())" "Gray"
        }
    } catch {
        Write-Diag "WSL Query Error: $_" "Yellow"
    }
} else {
    Write-Diag "WSL CLI:         NOT INSTALLED" "Yellow"
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
$tools = @("javac", "mvn", "flutter", "dart", "cmake", "ninja", "git")
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
Write-Diag "`n--- 6. Linux Credential Store Location ---" "Yellow"
$credDir = Join-Path $linuxDir "data\node1\credentials"
if (Test-Path $credDir) {
    $credCount = (Get-ChildItem $credDir -Filter "*.cred" -ErrorAction SilentlyContinue).Count
    Write-Diag "  Credential Directory: $credDir (Found $credCount stored encrypted credentials)" "Green"
} else {
    Write-Diag "  Credential Directory: $credDir (Not yet initialized)" "Gray"
}

# 7. Local Node Logs
Write-Diag "`n--- 7. Local Node Recent Logs ---" "Yellow"
$logLocations = @(
    (Join-Path $linuxDir "data\node1\logs"),
    (Join-Path $linuxDir "data\node1"),
    (Join-Path $linuxDir "logs")
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
