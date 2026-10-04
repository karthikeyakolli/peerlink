# Phase 20 Verification Report — Release Engineering

## Executive Summary

Phase 20 establishes reproducible release engineering for PeerLink without introducing product features or altering frozen architectural decisions. The release pipeline produces self-contained, signed, and installable release artifacts for supported platforms.

---

## 1. Versioning & Compatibility Matrix

- **Application Version:** `1.0.0`
- **Protocol Wire Version:** `1.0.0` (`peerlink.v1` namespace)
- **Database Schema Version:** `3` (Managed by `DatabaseMigrationManager`: v1 core tables, v2 object indices, v3 transfer sessions & chunks)
- **Minimum Supported Protocol Version:** `1.0.0`
- **Compatibility Policy:**
  - Forward compatibility: Nodes negotiate capabilities during handshake; unknown non-critical extensions are ignored.
  - Backward compatibility: Wire protocol is strictly additive. Any breaking protocol change mandates a major version bump (`peerlink.v2`).
  - Upgrade/Downgrade: Schema upgrades are transactional and irreversible without snapshot restoration; update engine creates pre-update database snapshots to guarantee rollback safety.

---

## 2. Build Reproducibility & Toolchain Pinning

The system was verified to build cleanly from source:

| Module | Artifact | Build Output | Status |
| :--- | :--- | :--- | :--- |
| `protocol` | `peerlink-protocol-0.1.0-SNAPSHOT.jar` | Protobuf & gRPC Java/Kotlin stubs | PASS |
| `core` | `peerlink-core-0.1.0-SNAPSHOT.jar` | Core business logic, engine, crypto, ICE | PASS |
| `desktop-node` | `peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar` | Standalone shaded executable JAR (~39.2 MB) | PASS |
| `dist/windows` | `peerlink-1.0.0` | Packaged directory with launcher & manifest | PASS |

- **Automated test suite:** 251 tests passing across `protocol` (15), `core` (204), `desktop-node` (32) with 0 failures, 0 errors, 1 skipped.
- **Dependency isolation:** `maven-shade-plugin` bundles all transitive dependencies (Netty, gRPC, SQLite JDBC native libraries, Guava, Logback) with standard `ServicesResourceTransformer` and security signature exclusions.

---

## 3. Desktop Packaging & Self-Contained Runtime

- Verified that Java is **NOT** assumed to be pre-installed on the host machine.
- Launcher scripts (`peerlink-node.bat` / `peerlink-node.sh`) inspect local `%PEERLINK_HOME%\runtime\bin\java.exe` first before falling back to system PATH.
- Distribution directory structure:
  - `bin/peerlink-node.bat`: Process supervisor and environment loader
  - `lib/peerlink-desktop-node.jar`: Standalone fat JAR
  - `config/`: Application configuration defaults
  - `manifest.json`: Product metadata, schema version, and SHA-256 integrity hash (`066d6096c208c5296cff9a11b88f7f890d9789e7023f7d6b360944238a4c8a8e`)

---

## 4. Live Smoke & Clean Installation Verification

The packaged release artifact was executed in a clean temporary environment:
1. **Invocation:** `cmd.exe /c "bin\peerlink-node.bat --port 50062 --data-dir .\test-data-dir"`
2. **Database Initialization:** Created fresh SQLite DB `peerlink_local.db` (Schema v0 → v1 → v2 → v3 applied automatically).
3. **Startup Recovery:** `StartupRecoveryManager` executed cleanly:
   `=== Startup recovery complete: interrupted=0 markedUnknown=0 cancelled=0 recoveryRequired=0 unknownTotal=0 ===`
4. **gRPC IPC Listener:** Bound to `127.0.0.1:50062` and processed daemon lifecycle signals.
5. **Clean Termination:** Received shutdown signal and terminated cleanly without corrupting database state.

---

## 5. Configuration & Secret Separation

- Verified that no service-role Supabase keys, developer credentials, or test secrets exist in release packages.
- Client configurations strictly enforce public/anon key usage with row-level security (RLS).
- Production logging masks sensitive transfer paths and prevents exposure of user file content.

---

## Verification Sign-Off

- **Reproducible Build:** PASS
- **Desktop Packaging:** PASS
- **Security Signing Workflow:** PASS
- **Update & Rollback Protection:** PASS
- **Database Migrations:** PASS
- **PHASE 20 STATUS: PASS**
