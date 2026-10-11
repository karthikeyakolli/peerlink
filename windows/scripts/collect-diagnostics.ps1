# PeerLink Windows Diagnostics Collection Script
# Gathers system environment, network ports, firewall status, and Local Node logs.

param (
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$diagOutput = [System.Text.StringBuilder]::new()

function Write-Diag([string]$text, [string]$color = "White") {
    Write-Host $text -ForegroundColor $color
    [void]$diagOutput.AppendLine($text)
}

Write-Diag "==========================================================" "Cyan"
Write-Diag " PeerLink Windows System & Runtime Diagnostics" "Cyan"
Write-Diag " Timestamp: $([DateTime]::UtcNow.ToString('o'))" "Cyan"
Write-Diag "==========================================================" "Cyan"

# 1. Operating System Details
Write-Diag "`n--- 1. Operating System ---" "Yellow"
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    Write-Diag "OS Caption:      $($os.Caption)" "Gray"
    Write-Diag "OS Version:      $($os.Version) (Build $($os.BuildNumber))" "Gray"
    Write-Diag "Architecture:    $($os.OSArchitecture)" "Gray"
} else {
    Write-Diag "OS Version:      $([System.Environment]::OSVersion)" "Gray"
}

# 2. Java Environment
Write-Diag "`n--- 2. Java Environment ---" "Yellow"
Write-Diag "JAVA_HOME:       $($env:JAVA_HOME)" "Gray"
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if ($javaCmd) {
    Write-Diag "Java Path:       $($javaCmd.Source)" "Gray"
    $javaVer = cmd.exe /c "java -version 2>&1"
    Write-Diag "Java Version Output:`n$($javaVer.Trim())" "Gray"
} else {
    Write-Diag "Java Executable: NOT FOUND" "Red"
}

# 3. Toolchain Status
Write-Diag "`n--- 3. Toolchain Inspection ---" "Yellow"
$tools = @("javac", "mvn", "flutter", "dart", "cmake", "git")
foreach ($t in $tools) {
    $cmd = Get-Command $t -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Diag "  $($t.PadRight(10)): FOUND ($($cmd.Source))" "Green"
    } else {
        Write-Diag "  $($t.PadRight(10)): NOT FOUND" "Yellow"
    }
}

# Visual Studio C++
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsPath) {
        $vsName = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName
        Write-Diag "  vswhere (VC++): FOUND ($vsName - $vsPath)" "Green"
    } else {
        Write-Diag "  vswhere (VC++): VC++ Desktop workload NOT installed" "Yellow"
    }
} else {
    Write-Diag "  vswhere (VC++): Visual Studio Installer not present" "Yellow"
}

# 4. Port Availability (50051 IPC, 53317 P2P)
Write-Diag "`n--- 4. Network Port Status ---" "Yellow"
$portsToCheck = @(50051, 53317)
foreach ($port in $portsToCheck) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Diag "  Port $port : IN USE by Process ID $($conn.OwningProcess[0]) (State: $($conn.State[0]))" "Yellow"
    } else {
        Write-Diag "  Port $port : AVAILABLE" "Green"
    }
}

# 5. Windows Defender Firewall Rule Status
Write-Diag "`n--- 5. Windows Firewall Status ---" "Yellow"
try {
    $fwOutput = & netsh.exe advfirewall firewall show rule name="PeerLink P2P Transport" 2>&1 | Out-String
    if ($fwOutput -match "No rules match") {
        Write-Diag "  PeerLink Inbound Rule: Not configured (Default Windows prompts will apply)" "Yellow"
    } else {
        Write-Diag "  PeerLink Inbound Rule: Configured`n$($fwOutput.Trim())" "Green"
    }
} catch {
    Write-Diag "  Firewall check error: $_" "Yellow"
}

# 6. Credential Store Status
Write-Diag "`n--- 6. Windows DPAPI Credential Store ---" "Yellow"
$credDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "PeerLink\credentials" } else { "$env:USERPROFILE\.peerlink\credentials" }
if (Test-Path $credDir) {
    $credCount = (Get-ChildItem $credDir -Filter "*.cred" -ErrorAction SilentlyContinue).Count
    Write-Diag "  Credential Directory: $credDir (Found $credCount stored encrypted credentials)" "Green"
} else {
    Write-Diag "  Credential Directory: $credDir (Not yet initialized)" "Gray"
}

# 7. Local Node Logs
Write-Diag "`n--- 7. Local Node Recent Logs ---" "Yellow"
$logLocations = @(
    (Join-Path $windowsDir "data\node1\logs"),
    (Join-Path $windowsDir "data\node1"),
    (Join-Path $windowsDir "logs")
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
