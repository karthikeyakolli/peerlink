#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Running PeerLink Monorepo Test Suite (Linux/macOS) ==="

echo "1. Testing dependency boundaries..."
./scripts/check-deps.sh

echo "2. Running Java Core & Desktop Node tests (JUnit 5)..."
mvn clean test -B

echo "3. Running Flutter tests..."
if [ -d "apps/peerlink-app" ]; then
    (cd apps/peerlink-app && flutter test)
fi

echo "=== All PeerLink Tests Succeeded ==="
