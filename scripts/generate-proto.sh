#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Generating Protobuf Contracts (Java & Dart) ==="

mkdir -p protocol/generated-java
mkdir -p protocol/generated-dart
mkdir -p apps/peerlink-app/lib/core/protocol

# Verify protoc is available
if ! command -v protoc &> /dev/null; then
    echo "Error: protoc is not installed or not in PATH."
    exit 1
fi

echo "Compiling Proto to Java..."
protoc --proto_path=protocol/proto \
       --java_out=protocol/generated-java \
       protocol/proto/peerlink/v1/*.proto

if command -v protoc-gen-grpc-java &> /dev/null; then
    protoc --proto_path=protocol/proto \
           --plugin=protoc-gen-grpc-java=$(which protoc-gen-grpc-java) \
           --grpc-java_out=protocol/generated-java \
           protocol/proto/peerlink/v1/*.proto
fi

if command -v protoc-gen-dart &> /dev/null; then
    echo "Compiling Proto to Dart..."
    protoc --proto_path=protocol/proto \
           --dart_out=grpc:protocol/generated-dart \
           protocol/proto/peerlink/v1/*.proto
    
    cp -r protocol/generated-dart/peerlink/v1/* apps/peerlink-app/lib/core/protocol/
fi

echo "Protobuf generation completed successfully."
