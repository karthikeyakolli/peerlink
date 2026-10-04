# PeerLink Release Candidate Certification Checklist

This checklist defines the strict gating criteria required before a build artifact can be designated as an official **Release Candidate (RC)** for distribution.

---

## 1. Architecture & Security Compliance

- [x] **Zero Silent Overwrites:** All conflicting files produce deterministic conflict copies or require explicit user confirmation.
- [x] **Two-Phase Staging:** Inbound files remain in isolated `.peerlink_staging/` until hash verification completes.
- [x] **Non-Authoritative Cloud:** Local nodes operate autonomously during Supabase outages; zero reliance on cloud authority for P2P transfers.
- [x] **Secret Isolation:** Verified that zero service-role keys, developer tokens, or test credentials exist in release binaries.
- [x] **Path Traversal Protection:** All remote browse, search, and zip extraction paths are strictly validated against root bounds.
- [x] **Fail-Closed Malware Policy:** If anti-malware scanning is enabled but the scanner daemon is unavailable, files remain quarantined.

---

## 2. Reproducibility & Build Verification

- [x] **Clean Toolchain:** Build succeeds from a clean checkout with pinned JDK 17/21, Maven 3.9.6, and Flutter 3.24.x.
- [x] **Automated Test Suite:** 100% pass rate across JVM and Dart suites (251 JVM unit/integration tests passing).
- [x] **Standalone Desktop Packaging:** Shaded fat JAR (`peerlink-desktop-node.jar`) bundles all dependencies (SQLite native DLLs/SOs, gRPC, Netty).
- [x] **Bundled JRE Support:** Desktop distribution does not mandate system Java installation; runtime layout verified.
- [x] **Integrity Manifest:** `manifest.json` generated with accurate SHA-256 binary digests.

---

## 3. Cross-Platform Certification

- [x] **Windows ↔ Windows:** Local loopback, LAN, and TURN relay verified.
- [x] **Windows ↔ Linux:** Direct TCP and ICE traversal verified.
- [x] **Windows ↔ macOS:** Full file transfer, sync, and remote browse verified.
- [x] **Windows ↔ Android:** Wi-Fi Direct and LAN transfers verified with Scoped Storage.
- [x] **Android ↔ Android:** Mobile-to-mobile transfer verified with Foreground Service and battery restrictions.

---

## 4. Update & Rollback Verification

- [x] **Signed Updates:** Update packages include detached Ed25519 / Authenticode signatures.
- [x] **Protocol Version Gates:** Manifest `min_supported_protocol` verified before update execution.
- [x] **Schema Migration Dry-Run:** Schema upgrades are validated on temporary DB copy before live database touch.
- [x] **Pre-Update DB Snapshot:** Automatic snapshot `peerlink_local.db.pre-update-<timestamp>` created.
- [x] **Health Check & Rollback:** Daemon self-test validated; failure triggers atomic rollback of binaries and database snapshot.

---

## 5. User Experience & Release Observability

- [x] **No Misleading UI States:** "Completed", "Online", and "Safe" status indicators reflect verifiable truth.
- [x] **Problems Center:** Actionable recovery messaging for network drops, storage exhaustion, and permission issues.
- [x] **Privacy-Safe Diagnostics:** Logs and diagnostic bundles mask user file contents and sensitive paths.

---

## Final Release Gate Certification

| Review Item | Status | Sign-Off Date | Reviewer |
| :--- | :--- | :--- | :--- |
| **Code Freeze** | VERIFIED | 2026-10-03 | Release Engineering |
| **Security Hardening** | VERIFIED | 2026-10-03 | Security Lead |
| **Cross-Platform Matrix** | VERIFIED | 2026-10-03 | QA Lead |
| **Data Integrity Audit** | VERIFIED | 2026-10-03 | Principal Engineer |

**FINAL RECOMMENDATION: RELEASE CANDIDATE READY**
