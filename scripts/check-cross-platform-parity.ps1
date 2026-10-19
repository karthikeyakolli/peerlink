# check-cross-platform-parity.ps1
# Non-destructive cross-platform parity auditor

param(
    [string]$JsonReport = ""
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PythonScript = Join-Path $PSScriptRoot "check_cross_platform_parity.py"

$ArgsList = @()
if ($JsonReport) {
    $ArgsList += "--json"
    $ArgsList += $JsonReport
}

& python $PythonScript $ArgsList

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
