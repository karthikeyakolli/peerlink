#!/usr/bin/env bash
# PeerLink Reproducible Protobuf Code Generation (Bash)
# Toolchains: Protoc 29.x, gRPC-Java 1.69.x, Dart protoc-gen-dart 21.x

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=========================================================="
echo " PeerLink Reproducible Protobuf Code Generation"
echo " Toolchains: Protoc 29.x, gRPC-Java 1.69.x, Dart 21.x"
echo "=========================================================="

mkdir -p protocol/generated-java
mkdir -p protocol/generated-dart

if ! command -v protoc &> /dev/null; then
    echo "BLOCKED: protoc is not installed or not in PATH."
    exit 1
fi

echo "[1/3] Compiling Java Protobuf & gRPC stubs..."
protoc --proto_path=protocol/proto \
       --java_out=protocol/generated-java \
       protocol/proto/peerlink/v1/*.proto

if command -v protoc-gen-grpc-java &> /dev/null; then
    protoc --proto_path=protocol/proto \
           --plugin=protoc-gen-grpc-java="$(command -v protoc-gen-grpc-java)" \
           --grpc-java_out=protocol/generated-java \
           protocol/proto/peerlink/v1/*.proto
fi

echo "[2/3] Compiling Dart Protobuf & gRPC stubs..."
if command -v protoc-gen-dart &> /dev/null; then
    protoc --proto_path=protocol/proto \
           --dart_out=grpc:protocol/generated-dart \
           protocol/proto/peerlink/v1/*.proto
fi

echo "[3/3] Synchronizing generated stubs to platform projects..."
for platform in windows linux macos android; do
    if [ -d "$platform/src/main/java" ] && [ -d "protocol/generated-java" ]; then
        cp -R protocol/generated-java/* "$platform/src/main/java/" 2>/dev/null || true
    fi

    if [ -d "$platform/app/flutter" ] && [ -d "protocol/generated-dart" ]; then
        mkdir -p "$platform/app/flutter/lib/core/protocol"
        cp -R protocol/generated-dart/* "$platform/app/flutter/lib/core/protocol/" 2>/dev/null || true
    fi
done

echo "Protobuf code generation completed successfully."
