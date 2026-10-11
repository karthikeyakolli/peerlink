#!/usr/bin/env bash
# PeerLink macOS Diagnostics Collection Script
# Gathers macOS system version, Darwin kernel, SIP, Gatekeeper, Xcode, Keychain, ports, and logs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

exec_diag() {
    echo "=========================================================="
    echo " PeerLink macOS System & Runtime Diagnostics"
    echo " Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo " Base Directory: $MACOS_DIR"
    echo "=========================================================="

    echo ""
    echo "--- 1. Operating System & Darwin Kernel ---"
    if [ "$(uname)" = "Darwin" ]; then
        echo "OS Product Name: $(sw_vers -productName 2>/dev/null || echo "macOS")"
        echo "OS Version:      $(sw_vers -productVersion 2>/dev/null || echo "unknown") (Build $(sw_vers -buildVersion 2>/dev/null || echo "unknown"))"
    else
        echo "OS Name:         $(uname -s) (Non-macOS Host)"
    fi
    echo "Darwin Kernel:   $(uname -r)"
    echo "Architecture:    $(uname -m)"

    echo ""
    echo "--- 2. macOS Security & Integrity Systems ---"
    if [ "$(uname)" = "Darwin" ]; then
        if command -v csrutil >/dev/null 2>&1; then
            echo "System Integrity Protection (SIP): $(csrutil status 2>/dev/null || echo "unknown")"
        else
            echo "System Integrity Protection:       csrutil not available"
        fi

        if command -v spctl >/dev/null 2>&1; then
            echo "Gatekeeper Status:                 $(spctl --status 2>/dev/null || echo "unknown")"
        else
            echo "Gatekeeper Status:                 spctl not available"
        fi

        if command -v security >/dev/null 2>&1; then
            echo "Keychain Service:                  AVAILABLE"
            echo "Default Keychain:                  $(security default-keychain 2>/dev/null || echo "none")"
        else
            echo "Keychain Service:                  MISSING"
        fi
    else
        echo "macOS Security Subsystems: N/A on non-Darwin host"
    fi

    echo ""
    echo "--- 3. Apple Developer Tools & Toolchains ---"
    if command -v xcode-select >/dev/null 2>&1; then
        echo "Xcode Developer Dir: $(xcode-select -p 2>/dev/null || echo "not set")"
    else
        echo "Xcode Developer Dir: xcode-select NOT FOUND"
    fi

    if command -v xcodebuild >/dev/null 2>&1; then
        echo "Xcode Version:       $(xcodebuild -version 2>/dev/null | head -n 1 || echo "unknown")"
    else
        echo "Xcode Version:       xcodebuild NOT FOUND"
    fi

    for t in pod java javac mvn flutter git; do
        if command -v "$t" >/dev/null 2>&1; then
            printf "  %-14s: FOUND (%s)\n" "$t" "$(command -v "$t")"
        else
            printf "  %-14s: NOT FOUND\n" "$t"
        fi
    done

    echo ""
    echo "--- 4. Network Port Availability ---"
    for port in 50051 53317; do
        if command -v lsof >/dev/null 2>&1; then
            if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
                echo "  Port $port: IN USE"
            else
                echo "  Port $port: AVAILABLE"
            fi
        else
            echo "  Port $port: Check unavailable (lsof missing)"
        fi
    done

    echo ""
    echo "--- 5. Credential Storage Directory ---"
    CRED_DIR="$HOME/Library/Application Support/PeerLink/credentials"
    if [ -d "$CRED_DIR" ]; then
        COUNT="$(find "$CRED_DIR" -type f -name "*.cred" 2>/dev/null | wc -l)"
        echo "  Directory: $CRED_DIR (Found $COUNT stored encrypted credentials)"
    else
        echo "  Directory: $CRED_DIR (Not yet created)"
    fi

    echo ""
    echo "--- 6. Local Node Recent Logs ---"
    FOUND_LOGS=0
    for log_dir in "$MACOS_DIR/data/node1/logs" "$MACOS_DIR/data/node1" "$HOME/Library/Logs/PeerLink"; do
        if [ -d "$log_dir" ]; then
            LATEST_LOG="$(find "$log_dir" -maxdepth 1 -name "*.log" -print 2>/dev/null | head -n 1)"
            if [ -n "$LATEST_LOG" ] && [ -f "$LATEST_LOG" ]; then
                echo "  Latest log file: $LATEST_LOG"
                echo "  --- Tail (last 10 lines): ---"
                tail -n 10 "$LATEST_LOG" | sed 's/^/    /'
                FOUND_LOGS=1
                break
            fi
        fi
    done
    if [ "$FOUND_LOGS" -eq 0 ]; then
        echo "  No log files recorded yet."
    fi

    echo ""
    echo "=========================================================="
    echo " Diagnostics Collection Complete."
    echo "=========================================================="
}

if [ -n "$OUTPUT_FILE" ]; then
    exec_diag | tee "$OUTPUT_FILE"
    echo "Diagnostics output written to: $OUTPUT_FILE"
else
    exec_diag
fi
