#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Checking physical isolation..."
if grep -rn "path:\s*\.\./" "$DIR/pubspec.yaml"; then
    echo "[FAIL] Escaping path dependency in pubspec.yaml"
    exit 1
fi

echo "Checking for symlinks..."
if find "$DIR" -type l | grep -q .; then
    echo "[FAIL] Symlinks detected"
    exit 1
fi

echo "[PASS] 100% physically isolated."
