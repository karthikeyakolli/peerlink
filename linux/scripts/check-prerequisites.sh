#!/usr/bin/env bash
# PeerLink Linux Prerequisites & Toolchain Checker
# Inspects the Linux host for GCC/Clang, CMake, GTK3, Secret Service, Java, and Flutter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo " PeerLink Linux Environment & Prerequisites Check"
echo " Project Directory: $LINUX_DIR"
echo "=========================================================="

HAS_FATAL=0

check_tool() {
    local name="$1"
    local cmd="$2"
    local required="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version="$("$cmd" --version 2>&1 | head -n 1 || echo "installed")"
        printf "  %-20s [%s] %s (%s)\n" "$name" "INSTALLED" "$required" "$version"
        return 0
    else
        printf "  %-20s [%s] %s (MISSING)\n" "$name" "MISSING" "$required"
        return 1
    fi
}

check_pkg() {
    local name="$1"
    local pkg="$2"

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "$pkg" 2>/dev/null; then
        local ver
        ver="$(pkg-config --modversion "$pkg" 2>/dev/null || echo "present")"
        printf "  %-20s [%s] %s (%s)\n" "$name" "INSTALLED" "$pkg" "$ver"
        return 0
    else
        printf "  %-20s [%s] %s (MISSING - install via apt/dnf)\n" "$name" "MISSING" "$pkg"
        return 1
    fi
}

echo ""
echo "--- Compilers & Build Tools ---"
check_tool "C Compiler (gcc)" "gcc" "GCC 10+" || true
check_tool "C++ Compiler (g++)" "g++" "G++ 10+" || true
check_tool "CMake" "cmake" "CMake 3.20+" || true
check_tool "Ninja" "ninja" "Ninja build" || true
check_tool "pkg-config" "pkg-config" "pkg-config tool" || true

echo ""
echo "--- Native Linux Development Libraries ---"
check_pkg "GTK+ 3.0" "gtk+-3.0" || true
check_pkg "GLib 2.0" "glib-2.0" || true
check_pkg "Secret Service" "libsecret-1" || true
check_pkg "systemd D-Bus" "libsystemd" || true

echo ""
echo "--- Runtime & Toolchains ---"
if ! check_tool "Java Runtime (JRE)" "java" "Java 21 LTS or 25"; then
    HAS_FATAL=1
fi
check_tool "Java Compiler (javac)" "javac" "JDK 21 or 25" || true
check_tool "Apache Maven" "mvn" "Maven 3.9+" || true
check_tool "Flutter SDK" "flutter" "Flutter 3.24+ (stable)" || true
check_tool "Git" "git" "Git 2.30+" || true

echo ""
echo "=========================================================="
if [ "$HAS_FATAL" -ne 0 ]; then
    echo "STATUS: FATAL - Minimum Java 21+ runtime is required to run Local Node."
    exit 1
else
    echo "STATUS: Toolchain check complete."
fi
