# PeerLink Release Engineering: Security & Code Signing

## 1. Signing Policy & Secret Isolation

PeerLink enforces strict cryptographic provenance across all distribution channels:
1. **Never Commit Private Keys:** Certificates, PFX files, JKS/PKCS12 keystores, and signing tokens must never exist in version control or CI/CD logs.
2. **Environment Variable Injection:** Key passwords, aliases, and certificates are injected at packaging time via hardware-backed security modules (HSM) or CI vault secrets (`PEERLINK_KEYSTORE_PASSWORD`, etc.).
3. **Double Verification:** Every binary is verified immediately following signature generation before inclusion into installers or delta packages.

---

## 2. Windows Authenticode Signing

PeerLink Windows binaries (`peerlink.exe`, `peerlink-node.bat`, launcher executables, and MSIX/InnoSetup installers) must be signed with an EV Code Signing Certificate via Microsoft `signtool.exe`.

### Execution Workflow
```powershell
# Set path to signtool from Windows SDK
$SignTool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"

# Sign application executable with SHA-256 and RFC 3161 Timestamp
& $SignTool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /sha1 $env:CERT_THUMBPRINT "dist\windows\peerlink-1.0.0\bin\peerlink.exe"

# Verify signature
& $SignTool verify /pa /v "dist\windows\peerlink-1.0.0\bin\peerlink.exe"
```

---

## 3. macOS Code Signing & Notarization

PeerLink macOS bundles (`PeerLink.app`) must meet Apple Hardened Runtime requirements and pass automated notary service inspection.

### Hardened Runtime Entitlements (`entitlements.plist`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Deep Signing & Notarization Commands
```bash
# 1. Sign embedded JRE runtime binaries
find dist/macos/PeerLink.app/Contents/runtime -type f -perm +111 -exec \
  codesign --force --options runtime --sign "Developer ID Application: PeerLink Team ($TEAM_ID)" {} \;

# 2. Sign main bundle
codesign --force --deep --options runtime --entitlements entitlements.plist \
  --sign "Developer ID Application: PeerLink Team ($TEAM_ID)" dist/macos/PeerLink.app

# 3. Create DMG or ZIP for notarization
ditto -c -k --keepParent dist/macos/PeerLink.app dist/macos/PeerLink.zip

# 4. Submit to Apple Notary Service
xcrun notarytool submit dist/macos/PeerLink.zip \
  --keychain-profile "PeerLink-Notary" \
  --wait

# 5. Staple ticket to app
xcrun stapler staple dist/macos/PeerLink.app
```

---

## 4. Android Keystore & APK/AAB Signing

Android release builds use a dedicated PKCS12 release keystore:

### Key Generation (Reference Only - Keystore Stored in HSM)
```bash
keytool -genkey -v -keystore peerlink-release.keystore \
  -alias peerlink -keyalg RSA -keysize 4096 -validity 10000 \
  -deststoretype PKCS12
```

### Gradle Build Configuration (`android/key.properties`)
```properties
storePassword=ENV_SECRET_KEYSTORE_PASSWORD
keyPassword=ENV_SECRET_KEY_PASSWORD
keyAlias=peerlink
storeFile=/secure/path/to/peerlink-release.keystore
```

### APK Signature Verification via `apksigner`
```bash
apksigner verify --verbose --print-certs dist/android/peerlink-release.apk
```
*Verification criteria:*
- Minimum Signature Scheme v2 & v3 supported.
- Verified identity matches PeerLink developer certificate fingerprint.
