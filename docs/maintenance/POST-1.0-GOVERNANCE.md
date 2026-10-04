# PeerLink Post-1.0 Architecture Governance & Maintenance Framework

**Document**: `docs/maintenance/POST-1.0-GOVERNANCE.md`  
**Role**: PeerLink Maintainer & Architecture Governance Engineer  
**Phase**: 30 (Maintainer and Architecture Governance)  
**Release Baseline**: PeerLink 1.0.0-GA (`peerlink-v1.0.0`)  
**Status**: ESTABLISHED & MANDATORY  
**Audience**: Maintainers, Architecture Review Board, Platform Engineers, SRE  

---

## 1. Executive Summary & Foundational Policy

Following the production release of **PeerLink 1.0.0**, the project transitions formally from active feature construction to **long-term stability, architectural preservation, and security maintenance**.

The core architecture, wire protocols, storage schemas, and security boundaries are **frozen**. Uncontrolled feature growth, speculative re-architecting, and casual semantic mutations are strictly prohibited. 

Every future change must be:
1. **Evidence-driven** (grounded in verifiable crash logs, performance traces, or CVEs).
2. **Tested** (verified by regression tests added prior to code modification).
3. **Documented** (tracked in release notes and operational manuals).
4. **Backward-aware** (maintaining 100% wire interoperability with V1.0.0 nodes).
5. **Security-reviewed** (preserving zero-trust and key isolation invariants).
6. **Architecture-reviewed** (governed by an approved ADR whenever subsystem contracts are impacted).

---

## 2. Maintenance Scope & The 13 Core Maintenance Areas

Ongoing engineering focus is strictly restricted to the following 13 maintenance areas:

| Area | Focus Domain | Key Risks & Safeguards | Primary Tools / References |
|---|---|---|---|
| **1. Dependency Security** | Third-party libraries (Netty, gRPC, SQLite, Jackson) | Supply-chain CVEs. Automated weekly scanning; zero HIGH/CRITICAL allowed. | `mvn dependency-check:check`, Dependabot |
| **2. OS & Platform Updates** | Windows 11 updates, macOS Sequoia, Linux kernel/glibc | Deprecated OS APIs, sandbox tightening, systemd changes. | Platform matrix smoke tests |
| **3. Android Policy Changes** | Google Play Developer Policies, Android 14/15 | Foreground service restrictions, background sync kills, Scoped Storage. | `AndroidNodeFacade`, TargetSdk audits |
| **4. Flutter Updates** | Desktop & Mobile UI framework, Dart SDK | Deprecated Flutter plugins, rendering engine changes, desktop shell. | `flutter analyze`, `flutter test` |
| **5. Java Runtime Updates** | OpenJDK 17 LTS / OpenJDK 21 LTS runtime updates | JVM security CPU patches, garbage collector behavior, module system. | Compiler release target (`-release 17`) |
| **6. Supabase Changes** | Control plane REST API, GoTrue Auth, Realtime WS | Protocol changes in Phoenix Channel, token rotation, RLS rule drifts. | `SupabaseControlPlaneTest` |
| **7. Relay Infrastructure** | coturn STUN/TURN clusters (US, EU, AP) | Capacity exhaustion, packet loss, bandwidth throttling on symmetric NAT. | `systemctl status coturn`, Prometheus |
| **8. Certificate & Signing** | TLS certificates, Windows Authenticode, Apple Notarization | Expired Let's Encrypt certs, invalid signing signatures, revocations. | Certbot timer, Apple NotaryTool |
| **9. Crash Monitoring** | Daemon unhandled exceptions, native SIGSEGV | Unhandled edge cases. Target crash rate: < 0.05% of active sessions. | Sentry / local crash dump logs |
| **10. Performance Monitoring** | CPU usage during 1Gbps wire transfer, memory footprint | Memory leaks, buffer bloating. Idle RAM < 50MB, active < 180MB. | JProfiler, GC logs, benchmark suite |
| **11. User-Reported Bugs** | Real-world pilot and end-user issue reports | Must reproduce with evidence before fixing; strictly no scope creep. | [Change Policy](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/maintenance/CHANGE-POLICY.md) |
| **12. Security Incidents** | Key leaks, unauthorized relay usage, malicious peers | Immediate incident protocol execution; zero-downtime key revocation. | [Incident Response](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/operations/INCIDENT-RESPONSE.md) |
| **13. Backup & Recovery** | SQLite Online Backup integrity, state recovery | Database file corruption. Routine bit-exact verification tests. | `data-safety-smoke-test.ps1` |

---

## 3. Governance Rules & Architecture Decision Records (ADRs)

### 3.1 When is an ADR Mandatory?
An Architectural Decision Record must be submitted and approved in `docs/adr/` before implementing any change that:
* Modifies or extends protobuf messages in `protocol/src/main/proto/`.
* Adds a new transport mechanism or alters connection negotiation priority.
* Modifies local SQLite storage schema versioning (`schema_version > 3`).
* Alters the cryptographic identity model (Ed25519) or pairing flow (TOFU/SAS).
* Introduces a new external runtime dependency or cloud service.

### 3.2 ADR Repository Status
* **ADR-000**: [`docs/adr/ADR-000-ARCHITECTURE-FREEZE-AND-GOVERNANCE.md`](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/adr/ADR-000-ARCHITECTURE-FREEZE-AND-GOVERNANCE.md) — Formally establishes the post-1.0 architecture freeze and change protocol (**ACCEPTED**).

---

## 4. Current Known Limitations & Operational Dispositions

The following operational constraints documented during Beta (Phase 28) and Release (Phase 29) are active and dispositioned:

| Issue Identifier | Subsystem | Description & Operational Impact | Workaround & Disposition |
|---|---|---|---|
| **KI-AND-01** | Android OS | Aggressive OEM battery managers (Samsung OneUI, Xiaomi MIUI) kill background sync when screen is off for long periods. | Set battery usage to "Unrestricted" in system settings. Active foreground transfers are protected by `ForegroundService`. |
| **KI-AND-02** | Android OS | Scoped storage restrictions prevent syncing private third-party `/Android/data/` directories. | Synchronize standard media folders (`Documents/`, `DCIM/`, `Download/`) or use SAF tree picker. |
| **KI-AND-03** | Android OS | Android 10+ restricts background applications from reading the system clipboard. | Outbound clipboard push requires app in foreground; inbound clipboard push is received and applied immediately. |
| **KI-DSK-01** | Windows | Legacy Windows installs enforce `MAX_PATH` (260 characters) on file paths. | Enable Win32 Long Paths in Windows Registry or Group Policy. |
| **KI-DSK-02** | macOS | macOS 15 Sequoia requires explicit user consent for Local Network mDNS discovery. | Toggle ON in `System Settings > Privacy & Security > Local Network`. |
| **KI-NET-01** | Networking | Symmetric NAT to Symmetric NAT direct UDP hole punching fails in ~8-12% of configurations. | Automatic, seamless fallback to authenticated end-to-end encrypted TURN relays. |

---

## 5. Next Justified Maintenance Priorities

Without expanding scope, the next planned engineering activities for the V1.0.x maintenance stream are:

1. **Automated Weekly Dependency Scanning (Priority 1 - Security)**:
   * Establish automated GitHub Action / local CI cron running `mvn org.owasp:dependency-check-maven:check` weekly to alert maintainers to emerging CVEs.
2. **coturn Relay TLS Certificate Renewal Monitoring (Priority 2 - Operations)**:
   * Verify automated Certbot renewal hooks on relay clusters 30 days before expiration.
3. **Android 15 (Vanilla Ice Cream) Compatibility Validation (Priority 3 - Platform)**:
   * Validate foreground service behavior against Android 15 preview SDKs to ensure seamless forward compatibility for mobile users.
4. **Disaster Recovery Rehearsal (Priority 4 - Reliability)**:
   * Schedule the quarterly drill using `scripts/data-safety-smoke-test.ps1` and live node crash simulation.

---

## 6. Phase 30 Verification & Signoff

The governance architecture, regular checklist, change policies, and baseline freeze have been authored, verified, and established under version control.

```
PHASE 30 STATUS: ESTABLISHED
```
