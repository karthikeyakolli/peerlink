# PeerLink 1.0.0-rc1 Build Manifest

**Document Version**: 1.0  
**Phase**: 27 (Release Candidate Engineering)  
**Release Tag**: `peerlink-v1.0.0-rc1`  
**Packaging Date**: October 2026  
**Reproducibility**: Deterministic Bytecode & Shaded Artifact  

---

## 1. Toolchain & Environment Metadata

| Parameter | Value |
| :--- | :--- |
| **Java Compiler Toolchain** | OpenJDK 21 LTS (`21.0.12`) |
| **Target Bytecode Specification** | Java 17 LTS (`-source 17 -target 17`) |
| **Build Automation** | Apache Maven 3.9.9 / Maven Wrapper |
| **Kotlin Compiler** | 1.9.24 |
| **Protoc Compiler** | 3.25.5 / Protobuf Java Runtime 4.29.3 |
| **gRPC Toolchain** | gRPC-Java 1.69.0 / Netty Shaded 1.69.0 |
| **Flutter SDK** | 3.24.x LTS (Dart 3.5.x) |
| **Android Build Tools** | Gradle 8.7 / Android Gradle Plugin 8.4.x |

---

## 2. Core Release Artifacts & Cryptographic Checksums

| Platform | Artifact File / Directory | Size (Bytes) | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **JVM (All Platforms)** | `lib/peerlink-desktop-node.jar` | 4,407,390 B (~4.4 MB) | `44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e` |
| **Windows Desktop** | `dist/windows/peerlink-1.0.0-rc1/` | Bundle directory | `44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e` (core jar) |
| **Linux Desktop** | `dist/linux/peerlink-1.0.0-rc1/` | Bundle directory | `44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e` (core jar) |
| **macOS Desktop** | `dist/macos/peerlink-1.0.0-rc1/PeerLink.app` | App Bundle | `44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e` (core jar) |
| **Android Mobile** | `dist/android/peerlink-1.0.0-rc1/` | Release layout | `44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e` (core jar) |

---

## 3. Platform Distribution Trees

### 3.1 Windows Distribution Tree
```
dist/windows/peerlink-1.0.0-rc1/
├── bin/
│   └── peerlink-node.bat (Windows daemon launcher)
├── config/
│   └── application.properties (Production node properties)
├── lib/
│   └── peerlink-desktop-node.jar (Shaded fat JAR)
├── runtime/ (Lightweight modular JRE via jlink)
└── manifest.json (Release metadata)
```

### 3.2 Linux Distribution Tree
```
dist/linux/peerlink-1.0.0-rc1/
├── bin/
│   └── peerlink-node (POSIX executable launcher)
├── config/
│   └── application.properties
├── lib/
│   └── peerlink-desktop-node.jar
├── share/
│   └── applications/
│       └── peerlink.desktop (XDG desktop integration)
└── manifest.json
```

### 3.3 macOS Distribution Tree
```
dist/macos/peerlink-1.0.0-rc1/
├── PeerLink.app/
│   └── Contents/
│       ├── MacOS/
│       │   └── PeerLink (Hardened runtime shell)
│       ├── Java/
│       │   └── peerlink-desktop-node.jar
│       └── Resources/
├── entitlements.plist (Hardened runtime entitlements)
└── manifest.json
```

### 3.4 Android Distribution Tree
```
dist/android/peerlink-1.0.0-rc1/
├── apk/
│   └── release-info.txt (SDK 26–34, Foreground Sync Service permissions)
├── bundle/
└── manifest.json
```

---

## 4. Canonical Platform Manifest Schema (`manifest.json`)

```json
{
  "product": "PeerLink",
  "version": "1.0.0-rc1",
  "protocol_version": "1.0.0",
  "schema_version": 3,
  "min_supported_protocol": "1.0.0",
  "node_jar_sha256": "44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e",
  "packaged_at": "2026-10-04T09:29:30.825Z"
}
```

---

## 5. Verification Command

To verify the integrity of the standalone fat JAR on any machine:
```powershell
(Get-FileHash dist\windows\peerlink-1.0.0-rc1\lib\peerlink-desktop-node.jar -Algorithm SHA256).Hash.ToLower() -eq "44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e"
```
Or on Linux/macOS:
```bash
echo "44de049039ee49f52fc8b321aa2c0f271b3715ddf6b15f16777457391978939e  dist/linux/peerlink-1.0.0-rc1/lib/peerlink-desktop-node.jar" | sha256sum --check
```

---

BUILD MANIFEST STATUS: VERIFIED & SEALED
