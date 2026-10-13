# PeerLink Phase 17 Verification Report: Workspaces and Platform Integrations

**Date:** October 13, 2026  
**Status:** PASS (20 of 20 Tests Passed, 100% Assertion Success)  
**Execution Environment:** OpenJDK 25 (Pure Java SE Runtime) on Windows 11  
**Test Suite:** `Phase17StandaloneTestRunner` (`tools/run-phase17-tests.ps1`)  
**Cross-Platform Parity:** PASS (567 invariant files checked, 0 accidental drift)

---

## 1. Executive Summary

Phase 17 audits, implements, hardens, and verifies PeerLink's **Workspaces (Shared Spaces)**, **Clipboard Synchronization Safety**, and **Native Platform Integrations** across **Windows**, **macOS**, **Linux**, and **Android**.

Key architectural invariants verified:
1. **Authoritative Local Node Policy Enforcement (UI as Presentation Layer):**
   - All access decisions, boundary enforcements, share authorizations, and sensitivity gate inspections occur strictly inside the authoritative Local Node engine.
   - The UI acts purely as a presentation layer displaying platform-appropriate features, while disabled/unsupported integrations are clearly marked and rendered non-operational.
2. **Platform-Specific Integrations (No False Abstractions):**
   - **Windows:** Native File Explorer context menus (`PeerLinkSend`), reveal with selection (`explorer.exe /select,...`), default application launch, WinRT/PowerShell toast notifications, Windows Share Sheet contract, DPAPI credential storage, and live Windows Defender Firewall diagnostic execution (`netsh advfirewall`).
   - **macOS:** Finder Sync integration / Quick Actions, Finder reveal (`open -R`), AppleScript notifications (`display notification`), macOS Keychain credential storage, and sandbox entitlement validation (`com.apple.security.*`). Unsupported desktop features (Windows DPAPI/Registry, Linux D-Bus, Android SAF) return `false`.
   - **Linux:** Desktop environment detection (`XDG_CURRENT_DESKTOP`, `DESKTOP_SESSION` for GNOME, KDE, XFCE), `xdg-open` reveal/open, `notify-send` with urgency levels (`low`, `normal`, `critical`), FreeDesktop Secret Service credential storage, and desktop action registrations.
   - **Android:** System share sheet, Content URI ingestion (`content://...`) via `ContentResolverBridge`, Storage Access Framework (SAF) document picker (`SAF_DOCUMENT_PICKER`), MediaStore integration, Keystore-backed secrets, and runtime permissions. Desktop context menu hooks return `false`.
3. **Android Share Intent Ingestion Pipeline (`AndroidShareIntentIngestor`):**
   - Handles `ACTION_SEND` (single item) and `ACTION_SEND_MULTIPLE` (batch items).
   - Resolves `content://` URIs safely via `ContentResolverBridge`.
   - **Never bypasses safety:** All shared content streams are routed through `InboundSafetyPipeline`:
     - Mandatory read permission check; permission denial aborts cleanly.
     - Filename sanitization (rejects directory traversal `../` and null bytes `\0`).
     - Bounded size reading (enforces `DEFAULT_MAX_SHARE_BYTES = 50 MB`).
     - Staged into secure quarantine (`QuarantineZone`).
     - Decompression bomb detection (compression ratio > 100:1 and recursion depth > 3 rejected and deleted).
     - Executable format inspection (PE, ELF, Mach-O).
     - Antivirus scan with error transparency.
     - Files committed to destination with executable permissions revoked (`setExecutable(false)`).
4. **Android Lifecycle & Background Policy Constraints (`AndroidBackgroundPolicy`):**
   - Opportunistic background sync (via WorkManager) is blocked during Doze mode (`deviceIdleMode`) or Power Save mode (`powerSaveMode`).
   - Sync on metered cellular is blocked when Data Saver is active.
   - Transfers exceeding 5 MB or 5 seconds mandate promotion to an Android Foreground Service with a persistent notification.
5. **Workspace Scope Boundary Containment & Role Hierarchy (`SharedWorkspace` & `WorkspaceScope`):**
   - `WorkspaceScope` strictly confines operations to the designated `rootDirectory`; path traversal attempts (`../../`) or null byte injections throw `SecurityException`.
   - `SharedWorkspace` enforces hierarchical roles (`OWNER`, `ADMIN`, `EDITOR`, `CONTRIBUTOR`, `VIEWER`, `OBSERVER`).
   - Owners cannot be revoked or demoted. Revoked members are permanently barred from read and write actions.
   - Policy changes increment `policyEpoch`; in-flight or cached operations presenting an older epoch are immediately invalidated.
6. **Clipboard Safety, Sensitivity Inspection, & Loop Prevention (`ClipboardManager`):**
   - `ClipboardSensitivityInspector` blocks automated broadcast of sensitive private keys (RSA/EC), JWT authentication tokens (`eyJ...`), API keys (GitHub/AWS), credit cards, and credential strings.
   - Size limit strictly enforced: payloads exceeding `MAX_CLIPBOARD_SIZE_BYTES = 5 MB` are rejected.
   - `ClipboardLoopGuard` drops self-originating echoes and duplicate content hashes.
   - Mode `OFF` completely halts outgoing and incoming clipboard propagation.

---

## 2. Test Execution Summary (20/20 PASS)

| Test ID | Test Scenario | Verified Behavior | Result |
|:---|:---|:---|:---:|
| **Test 01** | Windows Platform Adapter Feature Query & Detection | Queries platform features; Windows capabilities enabled, non-Windows disabled. | **PASS** |
| **Test 02** | Windows File Explorer Reveal & Context Menu | Tests explorer reveal command and context menu registry registration. | **PASS** |
| **Test 03** | Windows Defender Firewall Query Execution | Executes real `netsh advfirewall` diagnostics on Windows host; reports status & suggestions. | **PASS** |
| **Test 04** | Windows DPAPI / In-Memory Credential Isolation | Secure storage, retrieval, deletion, and account isolation in credential storage. | **PASS** |
| **Test 05** | macOS Platform Adapter Finder Reveal & Keychain Storage | Tests macOS adapter capability matrix, `open -R` reveal, and Keychain storage. | **PASS** |
| **Test 06** | macOS Sandbox Permissions & Entitlements | Entitlement checks (`com.apple.security.*`) and permission request/check lifecycle. | **PASS** |
| **Test 07** | Linux Platform Adapter Desktop Environment & XDG | Detects desktop environment (`GNOME`/`KDE`/`XFCE`), `xdg-open` reveal, and XDG actions. | **PASS** |
| **Test 08** | Linux Secret Service & Notification Urgency | FreeDesktop Secret Service storage and `notify-send` urgency levels (`low`, `normal`, `critical`). | **PASS** |
| **Test 09** | Android Platform Adapter Capability Set & Picker | Enables `SYSTEM_SHARE_SHEET` and `SAF_DOCUMENT_PICKER`; desktop context menus return false. | **PASS** |
| **Test 10** | Android Runtime Permissions & Keystore Storage | Runtime permission grant flow (`READ_MEDIA_IMAGES`) and Keystore credential storage. | **PASS** |
| **Test 11** | Android Background Policy & Power Save / Doze | Blocks sync in Doze/PowerSave/DataSaver; mandates Foreground Service for large transfers. | **PASS** |
| **Test 12** | Android Share Intent: Single Clean File (`ACTION_SEND`) | Ingests `content://` URI through `InboundSafetyPipeline`; commits non-executable file cleanly. | **PASS** |
| **Test 13** | Android Share Intent: Multiple Files (`ACTION_SEND_MULTIPLE`) | Batch ingestion of multiple content URIs; all files validated and committed cleanly. | **PASS** |
| **Test 14** | Android Share Intent: Permission Denial Rejection | Denied read permission (`canRead = false`) halts ingestion with `PERMISSION_DENIED`. | **PASS** |
| **Test 15** | Android Share Intent: Malware Quarantined & Deleted | Ingested content with malware signature intercepted and deleted from quarantine. | **PASS** |
| **Test 16** | Android Share Intent: Traversal & Decompression Bomb | Traversal filename (`../../escape.sh`) and 150KB zip bomb rejected in quarantine. | **PASS** |
| **Test 17** | Workspace Scope Boundary Containment | Confines operations to workspace root; directory traversal escape throws `SecurityException`. | **PASS** |
| **Test 18** | Workspace Authorization, Role Hierarchy, and Revocation | Authorizes `WRITE`, `DELETE`, `READ`, `ADMIN`; enforces owner protection and revoked peer barring. | **PASS** |
| **Test 19** | Workspace Policy Epoch Invalidation | Advancing membership advances `policyEpoch`; stale epoch operations strictly rejected. | **PASS** |
| **Test 20** | Clipboard Safety, Sensitivity Gating, 5MB Limit & Loop Guard | Blocks private keys and JWTs; rejects >5MB text; drops self-echoes; respects mode `OFF`. | **PASS** |

---

## 3. Key Components Implemented & Hardened

### 3.1 `AndroidShareIntentIngestor` (`org.peerlink.core.platform.android`)
- Safely handles Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intents.
- Connects Android `ContentResolverBridge` to `InboundSafetyPipeline`.
- Guarantees that content shared from third-party Android apps goes through complete pre-flight checks, quarantine staging, hash verification, bomb inspection, malware scanning, and non-executable filesystem commitment.

### 3.2 `WorkspaceScope` (`org.peerlink.core.workspace` & `org.peerlink.core.collaboration.workspace`)
- Strict path confinement: `isPathWithinScope(Path candidate)` and `resolvePathWithinScope(String relativePath)`.
- Eliminates path traversal escapes (`../`, `\0`, drive letters, UNC paths) for all workspace-scoped file operations.

### 3.3 `WindowsPlatformAdapter` (`org.peerlink.core.platform.windows`)
- Live Windows shell execution on host:
  - `explorer.exe /select,"<path>"` highlights target files in File Explorer.
  - `netsh.exe advfirewall firewall show rule` diagnoses active firewall rules and generates accurate allow rules when missing.
  - Windows DPAPI credential storage preserves secret isolation per service/account.

### 3.4 `AndroidBackgroundPolicy` (`org.peerlink.core.android`)
- Enforces OS battery and network constraints:
  - Doze mode (`deviceIdleMode`) and Power Save mode (`powerSaveMode`) prevent background synchronization.
  - Cellular metered network with Data Saver active prevents background sync.
  - Transfers $\ge 5$ MB mandate promotion to an Android Foreground Service.

---

## 4. Cross-Platform Parity & Invariant Audit

All platform adapters and shared workspace models were synchronized across canonical and platform trees:
- `core/src/main/java/org/peerlink/core/platform/`
- `core/src/main/java/org/peerlink/core/collaboration/workspace/`
- `core/src/main/java/org/peerlink/core/workspace/`
- `shared-source/canonical/core/platform/`
- `shared-source/canonical/workspace/`
- `windows/` & `windows/src/main/java/org/peerlink/core/`
- `linux/` & `linux/src/main/java/org/peerlink/core/`
- `macos/` & `macos/src/main/java/org/peerlink/core/`
- `android/` & `android/src/main/java/org/peerlink/core/`

Parity verification executed via `tools/sync-platform-shared/verify-shared.ps1`:
```
==========================================================
 PeerLink Cross-Platform Parity Verification Tool
 Manifest:          shared-source/PARITY-MANIFEST.json
 Target Platforms:  windows, linux, macos, android
==========================================================
Parity Verification Summary:
 Total Invariant Files Checked: 567
 Total Accidental Drift:        0
 Status: PASS (Zero Accidental Drift; Perfect Invariant Parity)
==========================================================
```

---

## 5. Verification Commands

To reproduce the test suite and verification checks:

```powershell
# 1. Run Phase 17 Workspaces & Platform Integrations Suite (20 tests)
powershell -ExecutionPolicy Bypass -File tools/run-phase17-tests.ps1

# 2. Run All Preceding Phase Suites for Regression Protection (80 tests)
powershell -ExecutionPolicy Bypass -File tools/run-phase13-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/run-phase14-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/run-phase15-tests.ps1
powershell -ExecutionPolicy Bypass -File tools/run-phase16-tests.ps1

# 3. Verify Cross-Platform Parity & Zero Accidental Drift
powershell -ExecutionPolicy Bypass -File tools/sync-platform-shared/verify-shared.ps1
```
