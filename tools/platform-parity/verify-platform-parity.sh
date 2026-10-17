#!/usr/bin/env bash
# PeerLink Read-Only Platform Parity Verifier (Bash)
# Verifies bit-for-bit parity among the four retained platform projects (windows, linux, macos, android)
# without requiring an authoritative canonical source tree or selecting one platform as truth.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PLATFORMS=("windows" "linux" "macos" "android")
MANIFEST_PATH="tools/platform-parity/PARITY-MANIFEST.json"

echo "=========================================================="
echo " PeerLink Read-Only Platform Parity Verification Tool"
echo " Manifest:          $MANIFEST_PATH"
echo " Target Platforms:  ${PLATFORMS[*]}"
echo " Mode:              Peer-to-Peer Invariant Hash Parity"
echo "=========================================================="

if [ ! -f "$MANIFEST_PATH" ]; then
    echo "ERROR: Manifest not found at $MANIFEST_PATH" >&2
    exit 1
fi

DISCREPANCIES=0
TOTAL_CHECKED=0

INVARIANT_MODULES=(
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

# 1. Audit Invariant Modules across all 4 platforms
echo ""
echo "[1/3] Auditing Invariant Backend Modules across platforms..."
for mod in "${INVARIANT_MODULES[@]}"; do
    # Find all files across platforms for this module
    mapfile -t files < <(find "${PLATFORMS[@]/%/\/$mod}" -type f 2>/dev/null | sed -E "s|^[^/]+/$mod/||" | sort -u)
    for rel in "${files[@]}"; do
        TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
        FIRST_HASH=""
        FIRST_PLATFORM=""
        for plat in "${PLATFORMS[@]}"; do
            target="$plat/$mod/$rel"
            if [ ! -f "$target" ]; then
                echo "  [MISSING INVARIANT FILE] Module: $mod | Path: $rel missing on $plat" >&2
                DISCREPANCIES=$((DISCREPANCIES + 1))
                continue
            fi
            hash=$(sha256sum "$target" | awk '{print $1}')
            if [ -z "$FIRST_HASH" ]; then
                FIRST_HASH="$hash"
                FIRST_PLATFORM="$plat"
            elif [ "$FIRST_HASH" != "$hash" ]; then
                echo "  [INVARIANT HASH MISMATCH] Module: $mod | Path: $rel" >&2
                echo "    $FIRST_PLATFORM: $FIRST_HASH" >&2
                echo "    $plat:    $hash" >&2
                DISCREPANCIES=$((DISCREPANCIES + 1))
            fi
        done
    done
done

# 2. Audit Invariant Flutter UI Paths
echo ""
echo "[2/3] Auditing Invariant Flutter UI Paths across platforms..."
FLUTTER_SHARED=(
    "lib/core/app_constants.dart"
    "lib/core/node_ipc_client.dart"
    "lib/core/protocol"
    "lib/features/activity"
    "lib/features/devices"
    "lib/features/files"
    "lib/features/home"
    "lib/features/search"
    "lib/features/settings"
    "lib/features/spaces"
    "lib/main.dart"
    "pubspec.yaml"
    "analysis_options.yaml"
)

for item in "${FLUTTER_SHARED[@]}"; do
    mapfile -t ffiles < <(find "${PLATFORMS[@]/%/\/app\/flutter\/$item}" -type f 2>/dev/null | sed -E "s|^[^/]+/app/flutter/||" | sort -u)
    for frel in "${ffiles[@]}"; do
        TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
        FIRST_HASH=""
        FIRST_PLATFORM=""
        for plat in "${PLATFORMS[@]}"; do
            target="$plat/app/flutter/$frel"
            if [ ! -f "$target" ]; then
                echo "  [MISSING FLUTTER FILE] Path: $frel missing on $plat" >&2
                DISCREPANCIES=$((DISCREPANCIES + 1))
                continue
            fi
            hash=$(sha256sum "$target" | awk '{print $1}')
            if [ -z "$FIRST_HASH" ]; then
                FIRST_HASH="$hash"
                FIRST_PLATFORM="$plat"
            elif [ "$FIRST_HASH" != "$hash" ]; then
                echo "  [FLUTTER HASH MISMATCH] Path: $frel" >&2
                echo "    $FIRST_PLATFORM: $FIRST_HASH" >&2
                echo "    $plat:    $hash" >&2
                DISCREPANCIES=$((DISCREPANCIES + 1))
            fi
        done
    done
done

# 3. Check for Forbidden References
echo ""
echo "[3/3] Auditing Build Graphs for Retired References..."
FORBIDDEN_REFS=("apps/peerlink-app" "shared-source/canonical")
for kw in "${FORBIDDEN_REFS[@]}"; do
    for plat in "${PLATFORMS[@]}"; do
        if grep -rq --exclude-dir=".git" "$kw" "$plat/pom.xml" "$plat/app/flutter/pubspec.yaml" 2>/dev/null; then
            echo "  [FORBIDDEN REFERENCE] $plat build files reference $kw" >&2
            DISCREPANCIES=$((DISCREPANCIES + 1))
        fi
    done
done

echo ""
echo "=========================================================="
echo " Parity Verification Summary:"
echo " Total Invariant Relative Files Checked: $TOTAL_CHECKED"
echo " Total Discrepancies Detected:          $DISCREPANCIES"

if [ "$DISCREPANCIES" -eq 0 ]; then
    echo " Status: PASS (Zero Accidental Drift; Perfect Peer-to-Peer Parity)"
    echo "=========================================================="
    exit 0
else
    echo " Status: FAIL ($DISCREPANCIES discrepancies detected)"
    echo "=========================================================="
    exit 1
fi
