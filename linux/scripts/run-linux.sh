#!/usr/bin/env bash
# PeerLink Linux Application Launcher
# Starts the Linux Local Node daemon and optionally launches the Flutter Linux desktop UI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_DIR/.." && pwd)"
FLUTTER_DIR="$LINUX_DIR/app/flutter"

PORT=50051
DATA_DIR="$LINUX_DIR/data/node1"
TOKEN="dev-token-default"
NODE_ONLY=0
UI_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --node-only) NODE_ONLY=1; shift ;;
        --ui-only) UI_ONLY=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=========================================================="
echo " PeerLink Linux Application Launcher"
echo " Base Directory: $LINUX_DIR"
echo "=========================================================="

# Locate Java Runtime
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVA_BIN="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_BIN="java"
else
    echo "FATAL: Java runtime not found. Please install Java 21+ or set JAVA_HOME."
    exit 1
fi

# Locate Local Node Jar
LOCAL_JAR="$LINUX_DIR/target/peerlink-linux-node-0.1.0-SNAPSHOT.jar"
SHADED_JAR="$REPO_ROOT/desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

NODE_JAR=""
if [ -f "$LOCAL_JAR" ]; then
    NODE_JAR="$LOCAL_JAR"
elif [ -f "$SHADED_JAR" ]; then
    NODE_JAR="$SHADED_JAR"
fi

NODE_PID=""
cleanup() {
    if [ -n "$NODE_PID" ] && kill -0 "$NODE_PID" 2>/dev/null; then
        echo "Terminating Local Node daemon (PID: $NODE_PID)..."
        kill "$NODE_PID" || true
    fi
}
trap cleanup EXIT INT TERM

if [ "$UI_ONLY" -eq 0 ]; then
    if [ -z "$NODE_JAR" ]; then
        echo "ERROR: Local Node JAR not found at $LOCAL_JAR or $SHADED_JAR."
        echo "       Run build-linux.sh first."
        exit 1
    fi

    mkdir -p "$DATA_DIR"

    echo ""
    echo "=== Launching Linux Local Node Daemon ==="
    echo "Runtime:   $JAVA_BIN"
    echo "JAR:       $NODE_JAR"
    echo "Port:      $PORT"
    echo "Data Dir:  $DATA_DIR"
    echo "Token:     [CONFIGURED]"
    echo "========================================="

    if [ "$NODE_ONLY" -eq 1 ]; then
        exec "$JAVA_BIN" -jar "$NODE_JAR" --port "$PORT" --data-dir "$DATA_DIR" --token "$TOKEN"
    else
        "$JAVA_BIN" -jar "$NODE_JAR" --port "$PORT" --data-dir "$DATA_DIR" --token "$TOKEN" &
        NODE_PID=$!
        echo "Local Node daemon started in background (PID: $NODE_PID)."
        sleep 2
    fi
fi

if [ "$NODE_ONLY" -eq 0 ]; then
    echo ""
    echo "=== Launching Flutter Linux Desktop UI ==="
    # Check if compiled binary exists
    RELEASE_BIN="$FLUTTER_DIR/build/linux/x64/release/bundle/peerlink_app"
    if [ -f "$RELEASE_BIN" ]; then
        echo "Running compiled release binary: $RELEASE_BIN..."
        "$RELEASE_BIN"
    elif command -v flutter >/dev/null 2>&1; then
        pushd "$FLUTTER_DIR" >/dev/null
        echo "Running Flutter Linux app via flutter run..."
        flutter run -d linux
        popd >/dev/null
    else
        echo "BLOCKED: Flutter SDK is not installed on PATH and release binary not found."
        echo "         Local Node daemon is active on port $PORT, but Desktop UI cannot run."
    fi
fi
