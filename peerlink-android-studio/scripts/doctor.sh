#!/usr/bin/env bash
set -e

echo "============================================================"
echo " PeerLink Android Studio Edition — Environment Doctor       "
echo "============================================================"

echo "[1/4] Checking Flutter..."
flutter --version || echo "[WARN] Flutter not in PATH"

echo "[2/4] Checking Java..."
java -version || echo "[WARN] Java not in PATH"

echo "[3/4] Checking Android SDK..."
SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
if [ -d "$SDK" ]; then
    echo "[OK] Android SDK at $SDK"
else
    echo "[WARN] ANDROID_HOME not set or directory missing"
fi

echo "[4/4] Checking Devices..."
flutter devices || true

echo "Doctor check complete."
