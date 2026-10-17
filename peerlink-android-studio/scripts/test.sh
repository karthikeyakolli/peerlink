#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Running flutter tests..."
flutter test --reporter expanded

echo "Running native tests..."
cd "$DIR/android"
./gradlew testDebugUnitTest --no-daemon
