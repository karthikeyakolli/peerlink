#!/usr/bin/env bash
# PeerLink Platform Shared-Source Synchronization Tool (POSIX Bash)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

CANONICAL_DIR="${1:-shared-source/canonical}"
DRY_RUN="${DRY_RUN:-false}"
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
echo " PeerLink Shared-Source Synchronization Tool (Bash)"
echo " Canonical Source: $CANONICAL_DIR"
echo " Target Platforms: ${PLATFORMS[*]}"
if [ "$DRY_RUN" = "true" ]; then
    echo " MODE: DRY-RUN (No files will be modified)"
fi
echo "=========================================================="

TOTAL_COPIED=0
TOTAL_UP_TO_DATE=0

for PLATFORM in "${PLATFORMS[@]}"; do
    echo ""
    echo "Processing platform: $PLATFORM..."
    mkdir -p "$PLATFORM"

    for MODULE in "${SHARED_MODULES[@]}"; do
        SRC_DIR="$CANONICAL_DIR/$MODULE"
        DEST_DIR="$PLATFORM/$MODULE"

        if [ -d "$SRC_DIR" ]; then
            while IFS= read -r -d '' FILE; do
                REL_PATH="${FILE#"$SRC_DIR/"}"
                TARGET_FILE="$DEST_DIR/$REL_PATH"
                TARGET_DIR="$(dirname "$TARGET_FILE")"

                if [ -f "$TARGET_FILE" ] && cmp -s "$FILE" "$TARGET_FILE"; then
                    TOTAL_UP_TO_DATE=$((TOTAL_UP_TO_DATE + 1))
                else
                    echo "  [SYNC] $MODULE/$REL_PATH"
                    if [ "$DRY_RUN" != "true" ]; then
                        mkdir -p "$TARGET_DIR"
                        cp -p "$FILE" "$TARGET_FILE"
                    fi
                    TOTAL_COPIED=$((TOTAL_COPIED + 1))
                fi
            done < <(find "$SRC_DIR" -type f -print0)
        fi
    done

    # Sync Flutter app common code
    SRC_FLUTTER="$CANONICAL_DIR/flutter"
    DEST_FLUTTER="$PLATFORM/app/flutter"
    if [ -d "$SRC_FLUTTER" ]; then
        while IFS= read -r -d '' FILE; do
            REL_PATH="${FILE#"$SRC_FLUTTER/"}"
            TARGET_FILE="$DEST_FLUTTER/$REL_PATH"
            TARGET_DIR="$(dirname "$TARGET_FILE")"

            if [ -f "$TARGET_FILE" ] && cmp -s "$FILE" "$TARGET_FILE"; then
                TOTAL_UP_TO_DATE=$((TOTAL_UP_TO_DATE + 1))
            else
                echo "  [SYNC] app/flutter/$REL_PATH"
                if [ "$DRY_RUN" != "true" ]; then
                    mkdir -p "$TARGET_DIR"
                    cp -p "$FILE" "$TARGET_FILE"
                fi
                TOTAL_COPIED=$((TOTAL_COPIED + 1))
            fi
        done < <(find "$SRC_FLUTTER" -type f -print0)
    fi
done

echo ""
echo "=========================================================="
echo " Synchronization Summary:"
echo " Files Copied/Updated: $TOTAL_COPIED"
echo " Files Up-To-Date:     $TOTAL_UP_TO_DATE"
echo "=========================================================="
