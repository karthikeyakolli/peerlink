#!/usr/bin/env bash
# PeerLink macOS Prerequisites & Toolchain Checker
# Inspects the macOS host for Darwin kernel, Xcode, CocoaPods, Java, and Flutter SDK.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo " PeerLink macOS Environment & Prerequisites Check"
echo " Project Directory: $MACOS_DIR"
echo "=========================================================="

HAS_FATAL=0

check_tool() {
    local name="$1"
    local cmd="$2"
    local required="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version="$("$cmd" --version 2>&1 | head -n 1 || echo "installed")"
        printf "  %-22s [%s] %s (%s)\n" "$name" "INSTALLED" "$required" "$version"
        return 0
    else
        printf "  %-22s [%s] %s (MISSING)\n" "$name" "MISSING" "$required"
        return 1
    fi
}

echo ""
echo "--- 1. macOS System & Apple Developer Tools ---"
if [ "$(uname)" = "Darwin" ]; then
    echo "  Operating System:      [DARWIN] $(sw_vers -productName 2>/dev/null || echo "macOS") $(sw_vers -productVersion 2>/dev/null || echo "") (Build $(sw_vers -buildVersion 2>/dev/null || echo ""))"
    echo "  Darwin Kernel:         $(uname -r) ($(uname -m))"

    if command -v xcode-select >/dev/null 2>&1; then
        DEV_DIR="$(xcode-select -p 2>/dev/null || echo "not configured")"
        echo "  Xcode Developer Path:  $DEV_DIR"
    fi

    if command -v xcodebuild >/dev/null 2>&1; then
        XCODE_VER="$(xcodebuild -version 2>/dev/null | head -n 1 || echo "installed")"
        printf "  %-22s [%s] %s (%s)\n" "Xcode" "INSTALLED" "Xcode 14+" "$XCODE_VER"
    else
        printf "  %-22s [%s] %s (MISSING - install via Mac App Store)\n" "Xcode" "MISSING" "Xcode 14+"
        HAS_FATAL=1
    fi
else
    echo "  Operating System:      [NON-DARWIN] $(uname -s) ($(uname -m))"
    echo "  BLOCKED: Native macOS compilation and Xcode require an Apple macOS host."
    HAS_FATAL=1
fi

check_tool "CocoaPods (pod)" "pod" "CocoaPods 1.12+" || true

echo ""
echo "--- 2. Runtime & Build Toolchains ---"
if ! check_tool "Java Runtime (JRE)" "java" "Java 21 LTS or 25"; then
    HAS_FATAL=1
fi
check_tool "Java Compiler (javac)" "javac" "JDK 21 or 25" || true
check_tool "Apache Maven" "mvn" "Maven 3.9+" || true
check_tool "Flutter SDK" "flutter" "Flutter 3.24+ (stable)" || true
check_tool "Git" "git" "Git 2.30+" || true

echo ""
echo "--- 3. macOS Subsystems & Security ---"
if [ "$(uname)" = "Darwin" ]; then
    if command -v security >/dev/null 2>&1; then
        echo "  Apple Keychain CLI:    [AVAILABLE] /usr/bin/security"
    else
        echo "  Apple Keychain CLI:    [MISSING]"
    fi

    if command -v caffeinate >/dev/null 2>&1; then
        echo "  caffeinate Tool:       [AVAILABLE] /usr/bin/caffeinate"
    else
        echo "  caffeinate Tool:       [MISSING]"
    fi

    if command -v osascript >/dev/null 2>&1; then
        echo "  AppleScript CLI:       [AVAILABLE] /usr/bin/osascript"
    else
        echo "  AppleScript CLI:       [MISSING]"
    fi
fi

echo ""
echo "=========================================================="
if [ "$HAS_FATAL" -ne 0 ]; then
    echo "STATUS: BLOCKED - macOS host with Xcode is required for native compilation."
    exit 1
else
    echo "STATUS: macOS toolchain check complete."
    exit 0
fi
