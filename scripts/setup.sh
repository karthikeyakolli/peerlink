#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Setting up PeerLink Developer Environment (Linux/macOS) ==="

echo "Checking Java version..."
java -version || echo "Warning: Java not found."

echo "Checking Maven..."
mvn -v || echo "Warning: Maven not found."

echo "Checking Protoc..."
protoc --version || echo "Warning: Protoc not found."

echo "Checking Flutter..."
flutter --version || echo "Warning: Flutter not found."

echo "Generating Protobuf bindings..."
./scripts/generate-proto.sh || echo "Warning: Proto generation failed or skipped."

echo "Installing Flutter dependencies..."
if [ -d "linux/app/flutter" ]; then
    (cd linux/app/flutter && flutter pub get)
fi

echo "Verifying architectural boundaries..."
./scripts/check-deps.sh

echo "=== PeerLink Environment Setup Completed ==="
