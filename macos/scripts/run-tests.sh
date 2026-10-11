#!/usr/bin/env bash
# PeerLink macOS Test Runner
# Runs unit and integration tests for the macOS Local Node and Flutter desktop app.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$MACOS_DIR/app/flutter"

SKIP_NODE_TESTS=0
SKIP_UI_TESTS=0

for arg in "$@"; do
    case "$arg" in
        --skip-node-tests) SKIP_NODE_TESTS=1 ;;
        --skip-ui-tests)   SKIP_UI_TESTS=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

echo "=========================================================="
echo " PeerLink macOS Test Execution"
echo " Base Directory: $MACOS_DIR"
echo "=========================================================="

HAS_FAILURE=0

# 1. macOS Local Node Tests (JUnit 5)
if [ "$SKIP_NODE_TESTS" -eq 0 ]; then
    echo ""
    echo "[1/2] Running macOS Local Node Unit & Integration Tests..."
    if command -v mvn >/dev/null 2>&1; then
        echo "Executing: mvn test -f $MACOS_DIR/pom.xml..."
        if mvn test -f "$MACOS_DIR/pom.xml"; then
            echo "Local Node (JUnit): PASSED"
        else
            echo "Local Node (JUnit): FAILED"
            HAS_FAILURE=1
        fi
    else
        echo "Local Node (JUnit): BLOCKED (Maven CLI missing)"
    fi
fi

# 2. macOS Flutter App Tests
if [ "$SKIP_UI_TESTS" -eq 0 ]; then
    echo ""
    echo "[2/2] Running macOS Flutter Desktop Tests..."
    if command -v flutter >/dev/null 2>&1; then
        pushd "$FLUTTER_DIR" >/dev/null
        echo "Executing: flutter test in $FLUTTER_DIR..."
        if flutter test; then
            echo "Flutter Desktop Tests: PASSED"
        else
            echo "Flutter Desktop Tests: FAILED"
            HAS_FAILURE=1
        fi
        popd >/dev/null
    else
        echo "Flutter Desktop Tests: BLOCKED (Flutter SDK missing on PATH)"
    fi
fi

echo ""
echo "=========================================================="
if [ "$HAS_FAILURE" -ne 0 ]; then
    echo "Test execution failed."
    exit 1
else
    echo "Test execution completed successfully."
    exit 0
fi
