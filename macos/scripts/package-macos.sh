#!/usr/bin/env bash
# PeerLink macOS Release Packaging Script
# Packages the macOS Local Node and Flutter desktop application into a standard PeerLink.app bundle and archive.

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
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"

echo "=========================================================="
echo " PeerLink macOS Release Packaging: v$VERSION"
echo " Base Directory: $MACOS_DIR"
echo "=========================================================="

# 1. Locate Node JAR
LOCAL_JAR="$MACOS_DIR/target/peerlink-macos-node-0.1.0-SNAPSHOT.jar"
SHADED_JAR="$REPO_ROOT/desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar"

NODE_JAR=""
if [ -f "$LOCAL_JAR" ]; then
    NODE_JAR="$LOCAL_JAR"
elif [ -f "$SHADED_JAR" ]; then
    NODE_JAR="$SHADED_JAR"
fi

if [ -z "$NODE_JAR" ]; then
    echo "Local Node JAR not found at $LOCAL_JAR or $SHADED_JAR."
    echo "Attempting build via build-macos.sh..."
    bash "$SCRIPT_DIR/build-macos.sh" --skip-ui
    if [ -f "$LOCAL_JAR" ]; then
        NODE_JAR="$LOCAL_JAR"
    elif [ -f "$SHADED_JAR" ]; then
        NODE_JAR="$SHADED_JAR"
    else
        echo "ERROR: Cannot package: Local Node JAR is missing."
        exit 1
    fi
fi

# 2. Prepare PeerLink.app Bundle Layout
TARGET_DIST="$MACOS_DIR/$OUTPUT_DIR/peerlink-macos-$VERSION"
APP_BUNDLE="$TARGET_DIST/PeerLink.app"
CONTENTS="$APP_BUNDLE/Contents"

echo ""
echo "[1/4] Preparing macOS Application Bundle: $APP_BUNDLE..."

rm -rf "$TARGET_DIST"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Java"
mkdir -p "$CONTENTS/Resources/config"

# Copy Local Node JAR
cp "$NODE_JAR" "$CONTENTS/Java/peerlink-macos-node.jar"

# Generate Launcher Script for Local Node daemon
cat << 'EOF' > "$CONTENTS/MacOS/peerlink-node"
#!/usr/bin/env bash
set -euo pipefail
CONTENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVA_CMD="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="java"
else
    echo "ERROR: Java 21+ runtime is required to run PeerLink Local Node." >&2
    exit 1
fi

exec "$JAVA_CMD" -Dfile.encoding=UTF-8 -jar "$CONTENTS_DIR/Java/peerlink-macos-node.jar" "$@"
EOF
chmod +x "$CONTENTS/MacOS/peerlink-node"

# Info.plist
cat << EOF > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>peerlink_app</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.peerlink.desktop</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>PeerLink</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 PeerLink. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

echo "APPL????" > "$CONTENTS/PkgInfo"

# Production Config
cat << EOF > "$CONTENTS/Resources/config/application.properties"
# PeerLink macOS Release Configuration (v$VERSION)
peerlink.node.port=50051
peerlink.node.bind-host=127.0.0.1
peerlink.storage.max-db-mb=256
peerlink.storage.staging-retention-hours=24
peerlink.transfer.max-concurrent=4
peerlink.security.fail-closed-scanning=true
EOF

# Check for compiled Flutter macOS desktop release bundle
FLUTTER_RELEASE_APP="$MACOS_DIR/app/flutter/build/macos/Build/Products/Release/peerlink.app"
echo ""
echo "[2/4] Checking compiled Flutter macOS application bundle..."
if [ -d "$FLUTTER_RELEASE_APP" ]; then
    echo "Found compiled release application at $FLUTTER_RELEASE_APP. Merging..."
    cp -R "$FLUTTER_RELEASE_APP/Contents/MacOS/"* "$CONTENTS/MacOS/" || true
    cp -R "$FLUTTER_RELEASE_APP/Contents/Frameworks" "$CONTENTS/" 2>/dev/null || true
    cp -R "$FLUTTER_RELEASE_APP/Contents/Resources/"* "$CONTENTS/Resources/" 2>/dev/null || true
else
    echo "Flutter release .app not present in $FLUTTER_RELEASE_APP (skipped native binary merge)."
fi

# 3. Generate Release Manifest and Checksums
echo ""
echo "[3/4] Generating release manifest and SHA-256 signatures..."
JAR_HASH="$(sha256sum "$CONTENTS/Java/peerlink-macos-node.jar" | awk '{print $1}')"

cat << EOF > "$TARGET_DIST/manifest.json"
{
  "name": "PeerLink macOS",
  "version": "$VERSION",
  "buildPlatform": "macos",
  "architecture": "$(uname -m 2>/dev/null || echo "universal2")",
  "timestampUtc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "components": {
    "localNode": {
      "jar": "PeerLink.app/Contents/Java/peerlink-macos-node.jar",
      "sha256": "$JAR_HASH",
      "minJavaVersion": 21
    },
    "bundle": "PeerLink.app",
    "launcher": "PeerLink.app/Contents/MacOS/peerlink-node"
  }
}
EOF

pushd "$TARGET_DIST" >/dev/null
find . -type f ! -name "SHA256SUMS" -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
popd >/dev/null

# 4. Create Tarball Archive
echo ""
echo "[4/4] Creating tar.gz archive..."
ARCHIVE_NAME="peerlink-macos-$VERSION.tar.gz"
pushd "$MACOS_DIR/$OUTPUT_DIR" >/dev/null
tar -czf "$ARCHIVE_NAME" "peerlink-macos-$VERSION"
ARCHIVE_HASH="$(sha256sum "$ARCHIVE_NAME" | awk '{print $1}')"
echo "$ARCHIVE_HASH  $ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
popd >/dev/null

echo ""
echo "=========================================================="
echo " Packaging Successful!"
echo " Directory: $TARGET_DIST"
echo " Tarball:   $MACOS_DIR/$OUTPUT_DIR/$ARCHIVE_NAME"
echo " SHA-256:   $ARCHIVE_HASH"
echo "=========================================================="
