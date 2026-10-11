#!/usr/bin/env bash
# PeerLink Linux Application Build Script
# Builds the Linux Local Node daemon and Flutter Linux desktop application.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$LINUX_DIR/app/flutter"

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
echo " PeerLink Linux Application Build"
echo " Base Directory: $LINUX_DIR"
echo "=========================================================="

BUILD_SUCCESS=1

# 1. Build Local Node (Java)
if [ "$SKIP_NODE" -eq 0 ]; then
    echo ""
    echo "[1/2] Building Linux Local Node Daemon..."
    if command -v mvn >/dev/null 2>&1; then
        echo "Executing: mvn clean package -DskipTests=true -f $LINUX_DIR/pom.xml..."
        if mvn clean package -DskipTests=true -f "$LINUX_DIR/pom.xml"; then
            echo "Linux Local Node daemon built successfully."
        else
            echo "ERROR: Maven build failed."
            BUILD_SUCCESS=0
        fi
    else
        REPO_ROOT="$(cd "$LINUX_DIR/.." && pwd)"
        EXISTING_JAR="$REPO_ROOT/desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"
        if [ -f "$EXISTING_JAR" ]; then
            echo "NOTE: mvn CLI is missing, but verified existing artifact found at: $EXISTING_JAR"
        else
            echo "BLOCKED: Maven (mvn) CLI is missing and no pre-built Local Node jar was found."
            BUILD_SUCCESS=0
        fi
    fi
fi

# 2. Build Flutter Desktop Application (Linux GTK+ Runner)
if [ "$SKIP_UI" -eq 0 ]; then
    echo ""
    echo "[2/2] Building Flutter Linux Desktop UI..."
    if ! command -v flutter >/dev/null 2>&1; then
        echo "BLOCKED: Flutter SDK is not installed on PATH."
        echo "         Cannot compile Linux Flutter desktop UI."
        BUILD_SUCCESS=0
    else
        # Verify GTK3 and CMake
        MISSING_TOOLS=0
        for tool in cmake ninja pkg-config; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                echo "MISSING tool: $tool"
                MISSING_TOOLS=1
            fi
        done
        if command -v pkg-config >/dev/null 2>&1; then
            if ! pkg-config --exists gtk+-3.0; then
                echo "MISSING package: gtk+-3.0 development headers"
                MISSING_TOOLS=1
            fi
        fi

        if [ "$MISSING_TOOLS" -ne 0 ]; then
            echo "BLOCKED: Native Linux C++ / GTK3 build toolchain is incomplete."
            echo "         Install prerequisites via: sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev"
            BUILD_SUCCESS=0
        else
            pushd "$FLUTTER_DIR" >/dev/null
            echo "Executing: flutter pub get in $FLUTTER_DIR..."
            flutter pub get
            echo "Executing: flutter build linux --release in $FLUTTER_DIR..."
            if flutter build linux --release; then
                echo "Flutter Linux desktop application built successfully."
            else
                echo "ERROR: Flutter build linux failed."
                BUILD_SUCCESS=0
            fi
            popd >/dev/null
        fi
    fi
fi

echo ""
echo "=========================================================="
if [ "$BUILD_SUCCESS" -eq 1 ]; then
    echo "Linux build completed successfully!"
    exit 0
else
    echo "Linux build BLOCKED or failed. See output above for required toolchains."
    exit 1
fi
