#!/usr/bin/env bash
# PeerLink Platform Shared-Source Verification Tool (POSIX Bash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

CANONICAL_DIR="${1:-shared-source/canonical}"
PLATFORMS=("windows" "linux" "macos" "android")

SHARED_MODULES=(
    "core"
    "protocol"
    "operations"
    "transfer"
    "sync"
    "backup"
    "access"
    "sharing"
    "workspace"
    "clipboard"
    "compatibility"
    "security"
    "recovery"
    "diagnostics"
)

echo "=========================================================="
echo " PeerLink Shared-Source Verification Tool (Bash)"
echo " Canonical Baseline: $CANONICAL_DIR"
echo " Target Platforms:   ${PLATFORMS[*]}"
echo "=========================================================="

DISCREPANCY_COUNT=0
TOTAL_CHECKED=0

for PLATFORM in "${PLATFORMS[@]}"; do
    echo ""
    echo "Auditing platform: $PLATFORM..."

    if [ ! -d "$PLATFORM" ]; then
        echo "  [MISSING PLATFORM] Platform directory does not exist: $PLATFORM"
        DISCREPANCY_COUNT=$((DISCREPANCY_COUNT + 1))
        continue
    fi

    for MODULE in "${SHARED_MODULES[@]}"; do
        SRC_DIR="$CANONICAL_DIR/$MODULE"
        DEST_DIR="$PLATFORM/$MODULE"

        if [ -d "$SRC_DIR" ]; then
            while IFS= read -r -d '' FILE; do
                TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
                REL_PATH="${FILE#"$SRC_DIR/"}"
                TARGET_FILE="$DEST_DIR/$REL_PATH"

                if [ ! -f "$TARGET_FILE" ]; then
                    echo "  [MISSING FILE] $PLATFORM/$MODULE/$REL_PATH"
                    DISCREPANCY_COUNT=$((DISCREPANCY_COUNT + 1))
                elif ! cmp -s "$FILE" "$TARGET_FILE"; then
                    echo "  [HASH MISMATCH] $PLATFORM/$MODULE/$REL_PATH"
                    DISCREPANCY_COUNT=$((DISCREPANCY_COUNT + 1))
                fi
            done < <(find "$SRC_DIR" -type f -print0)
        fi
    done

    # Audit Flutter app
    SRC_FLUTTER="$CANONICAL_DIR/flutter"
    DEST_FLUTTER="$PLATFORM/app/flutter"
    if [ -d "$SRC_FLUTTER" ]; then
        while IFS= read -r -d '' FILE; do
            TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
            REL_PATH="${FILE#"$SRC_FLUTTER/"}"
            TARGET_FILE="$DEST_FLUTTER/$REL_PATH"

            if [ ! -f "$TARGET_FILE" ]; then
                echo "  [MISSING FLUTTER FILE] $PLATFORM/app/flutter/$REL_PATH"
                DISCREPANCY_COUNT=$((DISCREPANCY_COUNT + 1))
            elif ! cmp -s "$FILE" "$TARGET_FILE"; then
                echo "  [FLUTTER HASH MISMATCH] $PLATFORM/app/flutter/$REL_PATH"
                DISCREPANCY_COUNT=$((DISCREPANCY_COUNT + 1))
            fi
        done < <(find "$SRC_FLUTTER" -type f -print0)
    fi
done

echo ""
echo "=========================================================="
echo " Verification Summary:"
echo " Total Files Audited: $TOTAL_CHECKED"
echo " Total Discrepancies: $DISCREPANCY_COUNT"
if [ "$DISCREPANCY_COUNT" -eq 0 ]; then
    echo " Status: PASS (All copies identical)"
    exit 0
else
    echo " Status: FAIL (Drift detected)"
    exit 1
fi
