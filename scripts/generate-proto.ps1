# PeerLink Reproducible Protobuf Code Generation (PowerShell)
# Toolchains: Protoc 29.x, gRPC-Java 1.69.x, Dart protoc-gen-dart 21.x

param(
    [string[]]$TargetPlatforms = @("windows", "linux", "macos", "android")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$protoDir = Join-Path $repoRoot "protocol\proto"
$javaOut = Join-Path $repoRoot "protocol\generated-java"
$dartOut = Join-Path $repoRoot "protocol\generated-dart"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " PeerLink Reproducible Protobuf Code Generation" -ForegroundColor Cyan
Write-Host " Target Platforms: $($TargetPlatforms -join ', ')" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $javaOut | Out-Null
New-Item -ItemType Directory -Force -Path $dartOut | Out-Null

$protoFiles = Get-ChildItem -Path (Join-Path $protoDir "peerlink\v1") -Filter "*.proto" | Select-Object -ExpandProperty FullName

$protocCmd = Get-Command protoc -ErrorAction SilentlyContinue
if (-not $protocCmd) {
    Write-Host "BLOCKED: protoc executable is not on PATH." -ForegroundColor Red
    Write-Host "         Please install protoc 29.x to regenerate protocol contracts." -ForegroundColor Yellow
    exit 1
}

# 1. Compile Java Stubs
Write-Host "`n[1/3] Compiling Java Protobuf & gRPC stubs..." -ForegroundColor Cyan
$grpcJavaPlugin = Get-Command protoc-gen-grpc-java -ErrorAction SilentlyContinue
if ($grpcJavaPlugin) {
    & protoc -I "$protoDir" "--java_out=$javaOut" "--plugin=protoc-gen-grpc-java=$($grpcJavaPlugin.Source)" "--grpc-java_out=$javaOut" $protoFiles
} else {
    & protoc -I "$protoDir" "--java_out=$javaOut" $protoFiles
    Write-Host "  NOTE: protoc-gen-grpc-java plugin not found; base protobuf messages generated." -ForegroundColor Yellow
}

# 2. Compile Dart Stubs
Write-Host "`n[2/3] Compiling Dart Protobuf & gRPC stubs..." -ForegroundColor Cyan
$dartPlugin = Get-Command protoc-gen-dart -ErrorAction SilentlyContinue
if ($dartPlugin) {
    & protoc -I "$protoDir" "--plugin=protoc-gen-dart=$($dartPlugin.Source)" "--dart_out=grpc:$dartOut" $protoFiles
} else {
    Write-Host "  NOTE: protoc-gen-dart plugin not found; skipping Dart code generation." -ForegroundColor Yellow
}

# 3. Synchronize to Platform Projects
Write-Host "`n[3/3] Synchronizing generated stubs to platform projects..." -ForegroundColor Cyan
foreach ($platform in $TargetPlatforms) {
    # Synchronize Java stubs
    $platJava = Join-Path $repoRoot "$platform\src\main\java"
    if (Test-Path $platJava -and (Test-Path $javaOut)) {
        Copy-Item -Recurse -Force "$javaOut\*" $platJava
        Write-Host "  Updated Java stubs in $platform/src/main/java" -ForegroundColor Green
    }

    # Synchronize Dart stubs
    $platDart = Join-Path $repoRoot "$platform\app\flutter\lib\core\protocol"
    if (Test-Path (Join-Path $repoRoot "$platform\app\flutter") -and (Test-Path $dartOut)) {
        if (-not (Test-Path $platDart)) { New-Item -ItemType Directory -Force -Path $platDart | Out-Null }
        Copy-Item -Recurse -Force "$dartOut\*" $platDart
        Write-Host "  Updated Dart stubs in $platform/app/flutter/lib/core/protocol" -ForegroundColor Green
    }
}

Write-Host "`nProtobuf code generation completed successfully." -ForegroundColor Green
exit 0
