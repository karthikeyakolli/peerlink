#!/usr/bin/env bash
# PeerLink macOS — Open Native Xcode Workspace
# Resolves paths relative to the project root and launches Xcode on macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE="$MACOS_DIR/app/flutter/macos/Runner.xcworkspace"
PROJECT="$MACOS_DIR/app/flutter/macos/Runner.xcodeproj"

echo "=========================================================="
echo " PeerLink macOS — Opening Native Xcode Workspace"
echo " Base Directory: $MACOS_DIR"
echo "=========================================================="

if [ ! -d "$WORKSPACE" ]; then
    # Fallback to app/macos
    if [ -d "$MACOS_DIR/app/macos/Runner.xcworkspace" ]; then
        WORKSPACE="$MACOS_DIR/app/macos/Runner.xcworkspace"
        PROJECT="$MACOS_DIR/app/macos/Runner.xcodeproj"
    else
        echo "ERROR: Xcode workspace artifact not found at $WORKSPACE."
        exit 1
    fi
fi

echo "Xcode Workspace: $WORKSPACE"
echo "Xcode Project:   $PROJECT"

if [ "$(uname)" = "Darwin" ]; then
    if command -v open >/dev/null 2>&1; then
        echo "Launching Xcode..."
        open "$WORKSPACE"
        echo "Xcode opened successfully."
        exit 0
    else
        echo "ERROR: 'open' command not found."
        exit 1
    fi
else
    echo ""
    echo "BLOCKED: Xcode IDE can only be launched on an Apple macOS (Darwin) host."
    echo "         Artifacts verified present at:"
    echo "         Workspace: $WORKSPACE"
    echo "         Project:   $PROJECT"
    exit 0
fi
