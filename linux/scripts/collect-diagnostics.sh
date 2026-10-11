#!/usr/bin/env bash
# PeerLink Linux Diagnostics Collection Script
# Gathers system kernel, glibc, desktop environment, D-Bus, Secret Service, ports, and Local Node logs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

exec_diag() {
    echo "=========================================================="
    echo " PeerLink Linux System & Runtime Diagnostics"
    echo " Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo " Base Directory: $LINUX_DIR"
    echo "=========================================================="

    echo ""
    echo "--- 1. Operating System & Kernel ---"
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "OS Name:         ${PRETTY_NAME:-$NAME}"
    else
        echo "OS Name:         Unknown Linux"
    fi
    echo "Kernel Release:  $(uname -r)"
    echo "Architecture:    $(uname -m)"
    if command -v ldd >/dev/null 2>&1; then
        echo "Glibc Version:   $(ldd --version | head -n 1)"
    else
        echo "Glibc Version:   ldd not found"
    fi

    echo ""
    echo "--- 2. Desktop Environment & XDG Session ---"
    echo "Desktop:         ${XDG_CURRENT_DESKTOP:-Not set}"
    echo "Session Type:    ${XDG_SESSION_TYPE:-Not set (X11 / Wayland)}"
    echo "Config Home:     ${XDG_CONFIG_HOME:-$HOME/.config}"
    echo "Data Home:       ${XDG_DATA_HOME:-$HOME/.local/share}"
    echo "Cache Home:      ${XDG_CACHE_HOME:-$HOME/.cache}"
    echo "Runtime Dir:     ${XDG_RUNTIME_DIR:-Not set}"
    echo "D-Bus Bus:       ${DBUS_SESSION_BUS_ADDRESS:-Not set}"

    echo ""
    echo "--- 3. Linux Native Subsystems ---"
    if command -v secret-tool >/dev/null 2>&1; then
        echo "Secret Service:  AVAILABLE (secret-tool found)"
    else
        echo "Secret Service:  MISSING (falling back to AES-256-GCM encrypted local store)"
    fi

    if command -v systemd-inhibit >/dev/null 2>&1; then
        echo "systemd-inhibit: AVAILABLE (sleep lock support enabled)"
    else
        echo "systemd-inhibit: MISSING (sleep lock disabled)"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        echo "notify-send:     AVAILABLE (desktop notifications enabled)"
    else
        echo "notify-send:     MISSING"
    fi

    echo ""
    echo "--- 4. Java & Toolchains ---"
    echo "JAVA_HOME:       ${JAVA_HOME:-Not set}"
    if command -v java >/dev/null 2>&1; then
        echo "Java Path:       $(command -v java)"
        echo "Java Version:    $(java -version 2>&1 | head -n 1)"
    else
        echo "Java:            NOT FOUND"
    fi

    for t in javac mvn flutter cmake ninja pkg-config git; do
        if command -v "$t" >/dev/null 2>&1; then
            printf "  %-14s: FOUND (%s)\n" "$t" "$(command -v "$t")"
        else
            printf "  %-14s: NOT FOUND\n" "$t"
        fi
    done

    echo ""
    echo "--- 5. Network Port Availability ---"
    for port in 50051 53317; do
        if command -v ss >/dev/null 2>&1; then
            if ss -tulpn 2>/dev/null | grep -q ":$port "; then
                echo "  Port $port: IN USE"
            else
                echo "  Port $port: AVAILABLE"
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
                echo "  Port $port: IN USE"
            else
                echo "  Port $port: AVAILABLE"
            fi
        else
            echo "  Port $port: Status check unavailable (ss/netstat missing)"
        fi
    done

    echo ""
    echo "--- 6. Credential Storage Directory ---"
    CRED_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/peerlink/credentials"
    if [ -d "$CRED_DIR" ]; then
        PERMS="$(stat -c "%a" "$CRED_DIR" 2>/dev/null || stat -f "%Op" "$CRED_DIR" 2>/dev/null || echo "unknown")"
        COUNT="$(find "$CRED_DIR" -type f -name "*.cred" 2>/dev/null | wc -l)"
        echo "  Directory: $CRED_DIR (Permissions: $PERMS, Credentials: $COUNT)"
    else
        echo "  Directory: $CRED_DIR (Not yet created)"
    fi

    echo ""
    echo "--- 7. Local Node Recent Logs ---"
    FOUND_LOGS=0
    for log_dir in "$LINUX_DIR/data/node1/logs" "$LINUX_DIR/data/node1" "${XDG_DATA_HOME:-$HOME/.local/share}/peerlink/logs"; do
        if [ -d "$log_dir" ]; then
            LATEST_LOG="$(find "$log_dir" -maxdepth 1 -name "*.log" -printf '%T+ %p\n' 2>/dev/null | sort -r | head -n 1 | awk '{print $2}')"
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
