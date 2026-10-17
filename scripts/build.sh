#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Building PeerLink Monorepo (Linux/macOS) ==="

echo "1. Validating dependency boundaries..."
./scripts/check-deps.sh

echo "2. Generating Protocol Buffers..."
./scripts/generate-proto.sh

echo "3. Compiling Java Core & Desktop Node..."
mvn clean compile -B

echo "4. Analyzing Flutter application..."
if [ -d "linux/app/flutter" ]; then
    (cd linux/app/flutter && flutter pub get && flutter analyze --fatal-infos)
fi

echo "=== PeerLink Monorepo Build Succeeded ==="
