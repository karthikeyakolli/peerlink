#!/usr/bin/env bash
# PeerLink Linux Release Packaging Script
# Packages the Linux Local Node and native desktop application into a relocatable tarball.

set -euo pipefail

VERSION="1.0.0-rc1"
OUTPUT_DIR="dist"

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_DIR/.." && pwd)"

echo "=========================================================="
echo " PeerLink Linux Release Packaging: v$VERSION"
echo " Base Directory: $LINUX_DIR"
echo "=========================================================="

# 1. Locate Node JAR
LOCAL_JAR="$LINUX_DIR/target/peerlink-linux-node-0.1.0-SNAPSHOT.jar"
SHADED_JAR="$REPO_ROOT/desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

NODE_JAR=""
if [ -f "$LOCAL_JAR" ]; then
    NODE_JAR="$LOCAL_JAR"
elif [ -f "$SHADED_JAR" ]; then
    NODE_JAR="$SHADED_JAR"
fi

if [ -z "$NODE_JAR" ]; then
    echo "Local Node JAR not found at $LOCAL_JAR or $SHADED_JAR."
    echo "Attempting build via build-linux.sh..."
    bash "$SCRIPT_DIR/build-linux.sh" --skip-ui
    if [ -f "$LOCAL_JAR" ]; then
        NODE_JAR="$LOCAL_JAR"
    elif [ -f "$SHADED_JAR" ]; then
        NODE_JAR="$SHADED_JAR"
    else
        echo "ERROR: Cannot package: Local Node JAR is missing."
        exit 1
    fi
fi

# 2. Prepare Distribution Layout
TARGET_DIST="$LINUX_DIR/$OUTPUT_DIR/peerlink-linux-$VERSION"
echo ""
echo "[1/4] Preparing distribution directory: $TARGET_DIST..."

rm -rf "$TARGET_DIST"
mkdir -p "$TARGET_DIST/bin"
mkdir -p "$TARGET_DIST/lib"
mkdir -p "$TARGET_DIST/share/applications"
mkdir -p "$TARGET_DIST/share/icons/hicolor/512x512/apps"
mkdir -p "$TARGET_DIST/config"

# Copy Local Node JAR
cp "$NODE_JAR" "$TARGET_DIST/lib/peerlink-linux-node.jar"

# Generate Launcher Script for Local Node
cat << 'EOF' > "$TARGET_DIST/bin/peerlink-node"
#!/usr/bin/env bash
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PEERLINK_HOME="$(cd "$BIN_DIR/.." && pwd)"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVA_CMD="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="java"
else
    echo "ERROR: Java 21+ runtime is required to run PeerLink Local Node." >&2
    exit 1
fi

exec "$JAVA_CMD" -Dfile.encoding=UTF-8 -jar "$PEERLINK_HOME/lib/peerlink-linux-node.jar" "$@"
EOF
chmod +x "$TARGET_DIST/bin/peerlink-node"

# Production Config
cat << EOF > "$TARGET_DIST/config/application.properties"
# PeerLink Linux Release Configuration (v$VERSION)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
EOF

# Desktop Entry
cat << EOF > "$TARGET_DIST/share/applications/peerlink.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=PeerLink
GenericName=Local-First P2P File Transfer & Collaboration
Comment=Secure, end-to-end encrypted direct peer-to-peer file synchronization and transfer
Exec=peerlink-app
Icon=peerlink
Terminal=false
Categories=Network;FileTransfer;P2P;Utility;
Keywords=p2p;transfer;sync;share;encrypted;peerlink;
StartupWMClass=peerlink_app
MimeType=application/x-peerlink-package;
EOF

# Copy Icon if present
ICON_SRC="$LINUX_DIR/app/flutter/assets/icons/app_icon.png"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$TARGET_DIST/share/icons/hicolor/512x512/apps/peerlink.png"
fi

# Check for compiled Flutter Linux desktop bundle
FLUTTER_BUNDLE="$LINUX_DIR/app/flutter/build/linux/x64/release/bundle"
echo ""
echo "[2/4] Checking Flutter Linux desktop bundle..."
if [ -d "$FLUTTER_BUNDLE" ]; then
    echo "Found compiled release bundle at $FLUTTER_BUNDLE. Copying..."
    cp -r "$FLUTTER_BUNDLE/"* "$TARGET_DIST/bin/"
else
    echo "Flutter release bundle not present in $FLUTTER_BUNDLE (skipped)."
fi

# 3. Generate Release Manifest and Checksums
echo ""
echo "[3/4] Generating release manifest and SHA-256 signatures..."
JAR_HASH="$(sha256sum "$TARGET_DIST/lib/peerlink-linux-node.jar" | awk '{print $1}')"

cat << EOF > "$TARGET_DIST/manifest.json"
{
  "name": "PeerLink Linux",
  "version": "$VERSION",
  "buildPlatform": "linux",
  "architecture": "$(uname -m 2>/dev/null || echo "x86_64")",
  "timestampUtc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "components": {
    "localNode": {
      "jar": "lib/peerlink-linux-node.jar",
      "sha256": "$JAR_HASH",
      "minJavaVersion": 21
    },
    "desktopEntry": "share/applications/peerlink.desktop",
    "launcher": "bin/peerlink-node"
  }
}
EOF

pushd "$TARGET_DIST" >/dev/null
find . -type f ! -name "SHA256SUMS" -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
popd >/dev/null

# 4. Create Tarball Archive
echo ""
echo "[4/4] Creating tar.gz archive..."
ARCHIVE_NAME="peerlink-linux-$VERSION.tar.gz"
pushd "$LINUX_DIR/$OUTPUT_DIR" >/dev/null
tar -czf "$ARCHIVE_NAME" "peerlink-linux-$VERSION"
ARCHIVE_HASH="$(sha256sum "$ARCHIVE_NAME" | awk '{print $1}')"
echo "$ARCHIVE_HASH  $ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
popd >/dev/null

echo ""
echo "=========================================================="
echo " Packaging Successful!"
echo " Directory: $TARGET_DIST"
echo " Tarball:   $LINUX_DIR/$OUTPUT_DIR/$ARCHIVE_NAME"
echo " SHA-256:   $ARCHIVE_HASH"
echo "=========================================================="
