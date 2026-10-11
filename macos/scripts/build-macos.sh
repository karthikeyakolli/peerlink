#!/usr/bin/env bash
# PeerLink macOS Application Build Script
# Builds the macOS Local Node daemon and Flutter macOS desktop application (.app).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$MACOS_DIR/app/flutter"

SKIP_NODE=0
SKIP_UI=0

for arg in "$@"; do
    case "$arg" in
        --skip-node) SKIP_NODE=1 ;;
        --skip-ui)   SKIP_UI=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

echo "=========================================================="
echo " PeerLink macOS Application Build"
echo " Base Directory: $MACOS_DIR"
echo "=========================================================="

BUILD_SUCCESS=1

# 1. Build Local Node (Java)
if [ "$SKIP_NODE" -eq 0 ]; then
    echo ""
    echo "[1/2] Building macOS Local Node Daemon..."
    if command -v mvn >/dev/null 2>&1; then
        echo "Executing: mvn clean package -DskipTests=true -f $MACOS_DIR/pom.xml..."
        if mvn clean package -DskipTests=true -f "$MACOS_DIR/pom.xml"; then
            echo "macOS Local Node daemon built successfully."
        else
            echo "ERROR: Maven build failed."
            BUILD_SUCCESS=0
        fi
    else
        REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
        EXISTING_JAR="$REPO_ROOT/desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
        if [ -f "$EXISTING_JAR" ]; then
            echo "NOTE: mvn CLI is missing, but verified existing artifact found at: $EXISTING_JAR"
        else
            echo "BLOCKED: Maven (mvn) CLI is missing and no pre-built Local Node jar was found."
            BUILD_SUCCESS=0
        fi
    fi
fi

# 2. Build Flutter Desktop Application (macOS Runner)
if [ "$SKIP_UI" -eq 0 ]; then
    echo ""
    echo "[2/2] Building Flutter macOS Desktop UI (.app bundle)..."
    if [ "$(uname)" != "Darwin" ]; then
        echo "BLOCKED: Building Flutter macOS application requires an Apple macOS host with Xcode."
        echo "         Cross-compiling macOS .app bundles is not supported on $(uname -s)."
        BUILD_SUCCESS=0
    elif ! command -v flutter >/dev/null 2>&1; then
        echo "BLOCKED: Flutter SDK is not installed on PATH."
        BUILD_SUCCESS=0
    elif ! command -v xcodebuild >/dev/null 2>&1; then
        echo "BLOCKED: Xcode command line tools (xcodebuild) are not installed."
        BUILD_SUCCESS=0
    else
        pushd "$FLUTTER_DIR" >/dev/null
        echo "Executing: flutter pub get in $FLUTTER_DIR..."
        flutter pub get
        echo "Executing: flutter build macos --release in $FLUTTER_DIR..."
        if flutter build macos --release; then
            echo "Flutter macOS application built successfully."
        else
            echo "ERROR: Flutter build macos failed."
            BUILD_SUCCESS=0
        fi
        popd >/dev/null
    fi
fi

echo ""
echo "=========================================================="
if [ "$BUILD_SUCCESS" -eq 1 ]; then
    echo "macOS build completed successfully!"
    exit 0
else
    echo "macOS build BLOCKED or failed. See output above for required toolchains."
    exit 1
fi
