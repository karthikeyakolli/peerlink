#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Running dart format check..."
dart format --output=none --set-exit-if-changed .

echo "Running flutter analyze..."
flutter analyze
