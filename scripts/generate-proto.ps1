# PeerLink Protobuf Code Generation Script for Java and Dart
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$protoDir = Join-Path $repoRoot "protocol\proto"
$javaOut = Join-Path $repoRoot "protocol\generated-java"
$dartOut = Join-Path $repoRoot "protocol\generated-dart"
$appProtoDir = Join-Path $repoRoot "apps\peerlink-app\lib\core\protocol"

$env:PATH = "D:\tools\bin;D:\tools\flutter\bin\cache\dart-sdk\bin;D:\tools\flutter\bin;$env:PATH"

New-Item -ItemType Directory -Force -Path $javaOut | Out-Null
New-Item -ItemType Directory -Force -Path $dartOut | Out-Null
New-Item -ItemType Directory -Force -Path $appProtoDir | Out-Null

$protoFiles = Get-ChildItem -Path (Join-Path $protoDir "peerlink\v1") -Filter "*.proto" | Select-Object -ExpandProperty FullName

$protoc = if (Get-Command protoc -ErrorAction SilentlyContinue) { "protoc" } elseif (Test-Path "D:\tools\bin\protoc.exe") { "D:\tools\bin\protoc.exe" } else { "protoc" }

Write-Host "1. Compiling Java Protobuf & gRPC stubs..." -ForegroundColor Cyan
& $protoc -I "$protoDir" "--java_out=$javaOut" "--plugin=protoc-gen-grpc-java=D:\tools\bin\protoc-gen-grpc-java.exe" "--grpc-java_out=$javaOut" $protoFiles

Write-Host "2. Compiling Dart Protobuf & gRPC stubs..." -ForegroundColor Cyan
& $protoc -I "$protoDir" "--plugin=protoc-gen-dart=C:\Users\WIN_10\AppData\Local\Pub\Cache\bin\protoc-gen-dart.bat" "--dart_out=grpc:$dartOut" $protoFiles

Write-Host "3. Synchronizing Dart stubs to Flutter application..." -ForegroundColor Cyan
Copy-Item -Recurse -Force "$dartOut\*" $appProtoDir

Write-Host "Protobuf code generation completed successfully." -ForegroundColor Green
