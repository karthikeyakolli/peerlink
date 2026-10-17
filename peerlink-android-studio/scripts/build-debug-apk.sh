#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Building debug APK..."
flutter build apk --debug

APK="$DIR/build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK" ]; then
    echo "[OK] Built APK at $APK"
    ls -lh "$APK"
fi
