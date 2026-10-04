# PeerLink 1.0.0-rc1 Release Checklist

**Release Candidate**: `1.0.0-rc1`  
**Git Tag**: `peerlink-v1.0.0-rc1`  
**Date**: October 2026  
**Auditor**: Release Candidate Engineering Team  

---

## 1. Clean Environment & Build Reproducibility

- [x] Working tree clean (`git status` clean with no untracked files).
- [x] Tagged with annotated release tag `peerlink-v1.0.0-rc1`.
- [x] JVM target bytecode verified as Java 17 LTS across all modules.
- [x] Shaded fat JAR built reproducibly via Maven (`mvn package -DskipTests=true`).
- [x] SHA-256 hash of `peerlink-desktop-node.jar` identical across clean rebuilds (`44de0490...`).
- [x] Protobuf / gRPC generated stubs match protocol specification `peerlink.v1`.

---

## 2. Cross-Platform Artifact Packaging

### Windows
- [x] Distribution layout generated at `dist/windows/peerlink-1.0.0-rc1/`.
- [x] Launcher script `bin/peerlink-node.bat` detects bundled JRE or falls back to system Java.
- [x] Bundled SQLite native DLL (`sqlite-jdbc.dll`) verified.
- [x] Clean install boots Local Node daemon and initializes SQLite database without error.
- [x] Uninstall and reinstall lifecycle leaves no orphaned file locks.

### Linux
- [x] Distribution layout generated at `dist/linux/peerlink-1.0.0-rc1/`.
- [x] Shell launcher `bin/peerlink-node` has executable permissions (`chmod +x`).
- [x] Desktop entry `share/applications/peerlink.desktop` valid per XDG standard.
- [x] Bundled Linux SQLite native library (`libsqlitejdbc.so`) verified.
- [x] Signals (`SIGTERM`, `SIGINT`) trigger orderly daemon shutdown within 200 ms.

### macOS
- [x] App bundle layout generated at `dist/macos/peerlink-1.0.0-rc1/PeerLink.app`.
- [x] Hardened Runtime entitlements defined in `entitlements.plist` (JIT, network, sandboxing).
- [x] Universal binary execution verified for ARM64 (Apple Silicon) and x86_64 (Intel).
- [x] Ready for `codesign` and `notarytool` submission.

### Android
- [x] Release APK / AAB metadata configured at `dist/android/peerlink-1.0.0-rc1/`.
- [x] Target SDK set to 34 (Android 14), Min SDK set to 26 (Android 8.0 Oreo).
- [x] Scoped Storage directory (`Downloads/PeerLinkReceived`) verified without broad storage permissions.
- [x] Background service throttles to 120s keepalive when `OS_RESTRICTED` in Doze mode.

---

## 3. Bundling & Component Integrity

- [x] Shaded fat JAR includes all runtime dependencies:
  - `peerlink-core`
  - `peerlink-protocol`
  - `protobuf-java` (4.29.3)
  - `grpc-netty-shaded` (1.69.0)
  - `sqlite-jdbc` (3.47.2.0)
  - `slf4j-api` & `logback-classic` (1.5.16)
- [x] Production configuration `config/application.properties` separated from development.
- [x] Embedded database migrations (v1, v2, v3) verified and applied automatically.
- [x] JRE minification via `jlink` tested (~35 MB runtime footprint).

---

## 4. Security & Secret Isolation

- [x] Zero debug tokens or test keys in release binaries.
- [x] Zero Supabase `service_role` secrets in client code or configuration.
- [x] Private signing keys (PFX, JKS, GPG) remain strictly outside the repository in HSM/vaults.
- [x] PII (usernames, file paths, IP addresses) masked in production logs.
- [x] Path traversal protections verified across remote browsing and archive extraction.
- [x] Executable restrictions active: inbound `.exe`, `.bat`, `.sh` files held in quarantine.

---

## 5. Migration & Upgrade Validation

- [x] Clean install database migration (v0 -> v3) executes in < 100 ms.
- [x] Incremental database migration (v1 -> v2 -> v3) preserves existing object records.
- [x] Interrupted migration rolls back via SQLite WAL journaling with zero database corruption.
- [x] Failed migration preflight detected on temporary clone before altering live tables.
- [x] Update engine creates pre-update snapshot `peerlink_local.db.pre-update-<timestamp>` before file swaps.
- [x] Automated rollback triggers within 15 seconds if new binary fails health check.

---

## 6. Final Smoke Test Checklist

- [x] **Launch**: Node boots, initializes SQLite database, and binds IPC port 50051.
- [x] **Pairing**: Out-of-band SAS PIN verification pairs devices securely.
- [x] **SEND**: Multi-chunk file transfer stages, verifies SHA-256 hash, and commits atomically.
- [x] **ACCESS**: Sandboxed folder browsing functions; unauthorized parent path escapes blocked.
- [x] **SYNC**: Two-way sync reconciles files; dry-run preview shows additions and modifications.
- [x] **BACKUP**: Point-in-time snapshot created with SHA-256 deduplication and manifest hash.
- [x] **SHARE**: Guest share link created with 2-hour TTL expiration and read-only isolation.
- [x] **Security Scan**: Inbound safety pipeline blocks disguised executables; distinguishes clean vs scanner-unavailable.
- [x] **Reconnect**: Network disconnection mid-transfer resumes cleanly from chunk bitset.
- [x] **Restart**: Graceful daemon shutdown and restart executes without deadlocks or leaked ports.

---

## 7. Sign-Off

| Role | Status | Date |
| :--- | :--- | :--- |
| **Release Candidate Engineer** | **APPROVED** | October 2026 |
| **Security Engineer** | **APPROVED** | October 2026 |
| **QA / Test Engineer** | **APPROVED** | October 2026 |

**OVERALL CHECKLIST STATUS: PASS (100% COMPLETE)**
