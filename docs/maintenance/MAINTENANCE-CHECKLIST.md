# PeerLink Post-1.0 Regular Maintenance Checklist & Verification SOP

**Document**: `docs/maintenance/MAINTENANCE-CHECKLIST.md`  
**Version**: 1.0.0  
**Phase**: 30 (Maintainer & Architecture Governance)  
**Status**: ACTIVE  
**Audience**: On-Call Maintainers, SRE, Quality Engineering  

---

## 1. Cadence Overview

To preserve system integrity and prevent regressions, maintainers must perform standardized audits on a defined schedule:

| Frequency | Maintenance Activity | Target Subsystems | Responsible Role |
|---|---|---|---|
| **Continuous / Daily** | Automated CI Build, Crash Monitoring, Telemetry Alerting | All Modules, Relay Clusters | SRE On-Call |
| **Weekly** | Dependency Vulnerability Audit, Relay Health, Cert Expirations | Maven Dependencies, coturn, Supabase | Security Engineer |
| **Monthly** | Protocol Compatibility Check, Migration Replay, Security Regressions | Protocol, Local SQLite, Security | Maintainer |
| **Quarterly** | Disaster Recovery Drill, Full Backup Verification, Matrix Smoke Test | Multi-Platform, Backup Subsystem | Governance Lead |

---

## 2. Standardized Audit Procedures & Commands

### 2.1 Check 1: Dependency Vulnerability Audit
* **Objective**: Detect emerging CVEs in transitive and direct dependencies (Netty, gRPC, Protobuf, SQLite, Jackson/Gson).
* **Execution**:
  ```bash
  mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7.0
  ```
* **Pass Criteria**: Zero HIGH or CRITICAL CVEs (CVSS >= 7.0) in production dependencies.
* **Escalation**: If a CVE is identified, initiate [Runbook: Vulnerability Remediation](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/operations/INCIDENT-RESPONSE.md).

---

### 2.2 Check 2: Protocol Compatibility Check
* **Objective**: Guarantee that binary serialization and contract schemas remain 100% backward/forward compatible with V1.0.0.
* **Execution**:
  ```bash
  mvn test -Dtest=ProtocolContractCompatibilityTest -pl protocol
  ```
* **Pass Criteria**: `Tests run: 1, Failures: 0, Errors: 0`. No unknown wire fields or tag collisions.

---

### 2.3 Check 3: Database Migration Check
* **Objective**: Verify that upgrading from SQLite Schema v1 to v2 to v3 executes cleanly without table lock or data corruption.
* **Execution**:
  ```bash
  mvn test -Dtest=DatabaseMigrationManagerTest,LocalSqliteStorageTest -pl desktop-node
  ```
* **Pass Criteria**: Clean replay of all schema versions with `PRAGMA integrity_check` returning `ok`.

---

### 2.4 Check 4: Deterministic Release Build Check
* **Objective**: Confirm that release packaging builds reproduce identical bytecode and valid SHA-256 signatures.
* **Execution**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/package-desktop.ps1 -TargetPlatform windows -Version "1.0.0"
  ```
* **Pass Criteria**: Standalone fat JAR size ~39.5 MB; SHA-256 recorded in `manifest.json`.

---

### 2.5 Check 5: Security Regression Suite
* **Objective**: Verify zero regressions in cryptographic key isolation, TOFU pairing, clipboard sanitization, and antivirus fail-closed scanning.
* **Execution**:
  ```bash
  mvn test -Dtest=IdentityTrustAndPairingTest,FileSafetyAndCompatibilityTest,ProductionHardeningTest -pl core
  ```
* **Pass Criteria**: All security tests pass with 0 failures.

---

### 2.6 Check 6: Backup Verification
* **Objective**: Verify zero-lock online SQLite backup and bit-exact recovery.
* **Execution**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/data-safety-smoke-test.ps1
  ```
* **Pass Criteria**: Output logs `FINAL DATA-SAFETY TEST RESULT: PASS` with 100% bit-exact SHA-256 match.

---

### 2.7 Check 7: Disaster Recovery Test
* **Objective**: Simulate sudden crash, ungraceful kill, and offline control plane outage.
* **Execution**:
  ```bash
  mvn test -Dtest=DesktopChaosIntegrationTest,PeerTransferEngineRecoveryTest -pl desktop-node,core
  ```
* **Pass Criteria**: Automatic recovery of interrupted transfer state; seamless fallback to offline local mode.

---

### 2.8 Check 8: Cross-Platform Matrix Smoke Test
* **Objective**: Validate core functionality across Windows, macOS, Linux, and Android.
* **Execution**:
  ```bash
  mvn test -Dtest=AndroidNodeSystemTest,SecureSessionTransportTest -pl core,desktop-node
  ```
* **Pass Criteria**: All 11 Android lifecycle tests and all 9 Transport tests pass with 0 errors.

---

## 3. Platform & Dependency Watch Checklist

Maintainers must review platform announcements monthly:

* [ ] **Android Policy Changes**:
  * Check Google Play TargetSdk requirements (current: TargetSdk 34).
  * Check foreground service data sync type mandates (`FOREGROUND_SERVICE_DATA_SYNC`).
* [ ] **Flutter / Dart Engine**:
  * Review Flutter LTS releases for breaking engine changes.
* [ ] **Java Toolchain**:
  * Review OpenJDK security CPU patches (quarterly security advisories for Java 17 and 21).
* [ ] **Supabase Platform Updates**:
  * Verify Phoenix Channel WebSocket stability and GoTrue token expiration changes.
* [ ] **Relay Infrastructure (coturn)**:
  * Check TLS certificate validity (`openssl s_client -connect turns.peerlink.io:5349`). Ensure cert has > 30 days before expiration.
