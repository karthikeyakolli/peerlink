#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# PeerLink Official Maven Wrapper for Linux/macOS (POSIX Shell)
# Pinned Apache Maven 3.9.9 Wrapper
# ----------------------------------------------------------------------------
set -euo pipefail

WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MVN_PROPS="$WRAPPER_DIR/.mvn/wrapper/maven-wrapper.properties"

if [ ! -f "$MVN_PROPS" ]; then
    echo "ERROR: Cannot find $MVN_PROPS" >&2
    exit 1
fi

DIST_URL=$(grep '^distributionUrl=' "$MVN_PROPS" | cut -d'=' -f2- || true)
if [ -z "$DIST_URL" ]; then
    DIST_URL="https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.zip"
fi

MAVEN_CACHE="${HOME}/.m2/wrapper/dists/apache-maven-3.9.9-bin"
MAVEN_HOME="$MAVEN_CACHE/apache-maven-3.9.9"

if [ ! -x "$MAVEN_HOME/bin/mvn" ]; then
    echo "[mvnw] Apache Maven 3.9.9 is not cached. Downloading from $DIST_URL..."
    mkdir -p "$MAVEN_CACHE"
    ZIP_FILE="$MAVEN_CACHE/apache-maven-3.9.9-bin.zip"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$DIST_URL" -o "$ZIP_FILE"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$DIST_URL" -O "$ZIP_FILE"
    else
        echo "[mvnw] ERROR: Neither curl nor wget is available." >&2
        exit 1
    fi
    echo "[mvnw] Extracting Maven 3.9.9..."
    unzip -q -o "$ZIP_FILE" -d "$MAVEN_CACHE"
    rm -f "$ZIP_FILE"
    chmod +x "$MAVEN_HOME/bin/mvn"
    echo "[mvnw] Apache Maven 3.9.9 installed successfully to $MAVEN_HOME."
fi

exec "$MAVEN_HOME/bin/mvn" "$@"
