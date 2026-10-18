# PeerLink Phase 04 — Feature Completeness and UX Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit every UI screen across Windows and Android, connect every control to real operational backend services (Access, Sync, Backup, Journal, Trust), remove mock/fabricated devices and states, defer unverified experimental features (Web Beam, Hotspot P2P, Burn-After-Read), and ensure all user actions perform verified operations or state why they are unavailable.

**Architecture:** Connect the Flutter UI on desktop (via `NodeIpcClient` over localhost gRPC) and on Android (via `AndroidNodeBridge` over Platform Channels) to the underlying Java `core` engines: `SyncEngine`, `BackupEngine`, `RemoteAccessCoordinator`, `OperationJournal`, and `TrustStore`. Enforce zero-trust invariants, mass-change protections, Merkle verification, and safe conflict preservation across all platforms.

**Tech Stack:** Flutter / Dart, Java 17, gRPC, Protobuf v3, SQLite WAL, JUnit 5, Flutter Test, Win32 / Android SAF.

**Spec:** [USER_REQUEST] — Phase 04: Real Access/Sync/Backup, authoritative Home/Devices, actual OperationJournal Activity, indexed Search, live Settings, deferred unverified features.

## Global Constraints

- **Rule 1:** Read the relevant specification before modifying code.
- **Rule 2:** Do not change frozen architecture silently.
- **Rule 4:** Do not mark a task complete without running the required verification.
- **Rule 5:** Never place normal user file content in Supabase.
- **Rule 6:** Never treat discovery as trust.
- **Rule 7:** Never treat timestamps as sync truth.
- **Rule 8:** Never treat watcher events as filesystem truth.
- **Rule 9:** Never blindly replay destructive operations after uncertain outcomes (`OUTCOME_UNKNOWN`).
- **Rule 10:** Never auto-execute received files.
- **Rule 11:** Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
- **Rule 12:** Never trust localhost merely because it is localhost.
- **Platform Separation:** Retain physically separate source code for Windows, Android, Linux, and macOS.
- **UX Invariant:** A worker, snackbar, or modal must not report success unless the operation actually completed or was durably accepted at the explicitly described stage.

## Review Focus

1. **Blind replay on recovery:** If an operation in the journal is `OUTCOME_UNKNOWN`, self-healing buttons must run diagnostic checks and prompt for user reconciliation; they must never automatically re-execute destructive deletes or file commits.
2. **Silent overwrite during restore or sync:** Sync and Backup restore operations must never silently clobber existing disk files; they must apply destination policies (`RESTORE_CONFLICT_ALTERNATIVE_PATH`, `KEEP_BOTH`, etc.) and preserve tombstones.
3. **Mass-change false accepts:** Bulk file deletions (>50% of files) in a sync folder must trigger a `MassChangeProtector` hold that requires explicit user confirmation before applying deletions.
4. **Offline / unverified peer access:** Remote Access requests to an offline or un-paired peer must be cleanly rejected with a clear explanation rather than showing mock files or spinning indefinitely.
5. **Selection loss on failure:** Transient network or authentication rejections must display clear error diagnostics without discarding the user's staged file paths or space configurations.

---

### Task 1: Home Screen UX Simplification & InstantBeam Authoritative Wiring

**Files:**
- Modify: `windows/app/flutter/lib/features/home/home_screen.dart`
- Modify: `peerlink-android-studio/lib/features/home/home_screen.dart`
- Sync to: `linux/`, `macos/`, `android/`, `shared-source/canonical/`
- Test: `windows/app/flutter/test/home_ux_simplification_test.dart`

**Interfaces:**
- Consumes: `NodeIpcClient.currentState`, `NodeIpcClient.initiateSend`, `AndroidNodeBridge.initiateSend`
- Produces: Simplified Home screen showing only real paired devices in `InstantBeamDeck`, consolidated single local node status card, removed duplicate Quick Text, and deferred unverified experimental features (Web Beam, Hotspot P2P, Burn-After-Read).

- [ ] **Step 1: Write failing widget test for simplified Home Screen**
  - Verify `InstantBeamDeck` displays real paired peers or an informative empty state when no peers are paired (no hardcoded "MacBook Pro", "Pixel 9", "Ubuntu Studio" with fake fixed fingerprints).
  - Verify duplicate Local Node status panels and duplicate Quick Text entry points are eliminated.
  - Verify deferred experimental tools (Web Beam, Hotspot P2P, Burn-After-Read) are removed from the default production shelf.
  - Test file: `windows/app/flutter/test/home_ux_simplification_test.dart`.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/home_ux_simplification_test.dart` in `windows/app/flutter`
  - Expected: FAIL.

- [ ] **Step 3: Update `home_screen.dart` to match actual capabilities**
  - Connect `InstantBeamDeck` to real paired devices. If no devices are paired, render an empty state with a "Pair a Device" action.
  - In `_handleInstantBeam`: When tapping a trusted peer, check for staged files; if files are staged, call `_client.initiateSend` (or native bridge) with real feedback; if none staged, guide user to pick files.
  - Remove duplicate quick tool cards (Quick Text, Burn Beam, Web Beam, Hotspot P2P, Radar Sonar) from the shelf.
  - Keep the primary bilateral SEND and RECEIVE hero buttons and single authoritative Local Node status card.

- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/home_ux_simplification_test.dart` in `windows/app/flutter`
  - Expected: PASS.

- [ ] **Step 5: Sync to other platform trees**

---

### Task 2: Devices Screen & Authoritative Trust & Remote Access

**Files:**
- Modify: `windows/app/flutter/lib/features/devices/devices_screen.dart`
- Modify: `peerlink-android-studio/lib/features/devices/devices_screen.dart`
- Sync to: `linux/`, `macos/`, `android/`, `shared-source/canonical/`
- Test: `windows/app/flutter/test/devices_trust_access_test.dart`

**Interfaces:**
- Consumes: `NodeIpcClient.currentState` (peerId, node status), `TrustStore`, `PairingCoordinator`
- Produces: Authoritative Device pairing, real fingerprint display, genuine trust revocation, and scoped capability browsing modal.

- [ ] **Step 1: Write failing widget test for Devices Screen**
  - Verify device list does not contain hardcoded fake devices or fixed fake fingerprints.
  - Verify local node fingerprint displayed is authentic (or retrieved from node status/keystore).
  - Verify "Verify & Trust" pairing persists paired device and "Revoke Trust" genuinely removes device.
  - Verify Access/Browse action checks device connectivity and displays clear unavailable state if peer is offline.
  - Test file: `windows/app/flutter/test/devices_trust_access_test.dart`.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/devices_trust_access_test.dart` in `windows/app/flutter`
  - Expected: FAIL.

- [ ] **Step 3: Implement authoritative trust management in `devices_screen.dart`**
  - Remove hardcoded devices (`MacBook Pro 16" (Work)`, `Pixel 8 Pro (Personal)`, `Bob (Guest Project Share)`).
  - Connect to authoritative local peer ID and fingerprint from `NodeIpcClient.instance.currentState`.
  - Implement real device list management with persistent trust state.
  - Provide an Access/Browse dialog that checks remote peer connectivity, enforces scoped permissions, and gracefully handles offline peers.

- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/devices_trust_access_test.dart` in `windows/app/flutter`
  - Expected: PASS.

- [ ] **Step 5: Sync to other platform trees**

---

### Task 3: Spaces Screen Real Sync, Conflict Resolution & Verifiable Backup

**Files:**
- Modify: `windows/app/flutter/lib/features/spaces/spaces_screen.dart`
- Modify: `peerlink-android-studio/lib/features/spaces/spaces_screen.dart`
- Sync to: `linux/`, `macos/`, `android/`, `shared-source/canonical/`
- Test: `windows/app/flutter/test/spaces_real_sync_backup_test.dart`

**Interfaces:**
- Consumes: Real local directory paths, `SyncDryRunResult`, `ConflictResolution`, `BackupManifest`
- Produces: Verified Sync dry-run computation, conflict resolution with non-destructive `.conflict` preservation, mass-change hold override, and verifiable backup snapshot capture/restore.

- [ ] **Step 1: Write failing widget test for Spaces Screen**
  - Verify sync dry-run examines actual local directory contents rather than static placeholder strings.
  - Verify conflict resolution options (`KEEP_BOTH`, `KEEP_LOCAL`, `ACCEPT_REMOTE`) record authoritative decisions and do not silently delete data.
  - Verify mass-change warning enforces hold when bulk deletions are detected.
  - Verify backup snapshots show real directory file counts and Merkle root hash, and restore enforces conflict policy.
  - Test file: `windows/app/flutter/test/spaces_real_sync_backup_test.dart`.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/spaces_real_sync_backup_test.dart` in `windows/app/flutter`
  - Expected: FAIL.

- [ ] **Step 3: Implement real sync & backup operations in `spaces_screen.dart`**
  - Replace hardcoded fake spaces with a real configurable sync spaces model with local path validation.
  - In `_showDryRunPreview`: Compute real directory statistics and diffs from actual files on disk.
  - In `_showConflictResolver`: Implement resolution policies that generate non-destructive `.conflict` files when `KEEP_BOTH` is selected.
  - In `_showMassChangeWarning`: Implement explicit user confirmation requirement to release the hold.
  - In Backup tab: Add "Create Snapshot" which inspects a real directory, computes SHA-256 Merkle root hash, and creates a verified snapshot record; and Restore with conflict safety (`FAIL_ON_CONFLICT` or `ALTERNATIVE_PATH`).

- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/spaces_real_sync_backup_test.dart` in `windows/app/flutter`
  - Expected: PASS.

- [ ] **Step 5: Sync to other platform trees**

---

### Task 4: Activity Screen Real Operation Journal & Safe Self-Healing

**Files:**
- Modify: `windows/app/flutter/lib/features/activity/activity_screen.dart`
- Modify: `peerlink-android-studio/lib/features/activity/activity_screen.dart`
- Sync to: `linux/`, `macos/`, `android/`, `shared-source/canonical/`
- Test: `windows/app/flutter/test/activity_journal_recovery_test.dart`

**Interfaces:**
- Consumes: `OperationJournal`, `OperationRecord`, `NodeIpcClient.currentState`
- Produces: Real operation journal viewer, active diagnostic problem solver, and strictly non-blind reconciliation for `OUTCOME_UNKNOWN` states (Rule 9).

- [ ] **Step 1: Write failing widget test for Activity Screen**
  - Verify history items reflect real operations from the journal rather than static demo text.
  - Verify `OUTCOME_UNKNOWN` operations are flagged as uncertain and do NOT offer a blind "Replay" button.
  - Verify self-healing diagnostics run real node health/connectivity checks.
  - Test file: `windows/app/flutter/test/activity_journal_recovery_test.dart`.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/activity_journal_recovery_test.dart` in `windows/app/flutter`
  - Expected: FAIL.

- [ ] **Step 3: Implement real journal display & safe reconciliation in `activity_screen.dart`**
  - Remove hardcoded demo problem records and history records.
  - Display actual operation history (from `NodeIpcClient` transfer history and operation updates).
  - In problem cards: Clearly explain network disconnection or failed transfers; if an operation state is `OUTCOME_UNKNOWN`, offer "Run Reconciliation Diagnostic" or "Inspect Staging", NEVER blindly replay destructive operations.
  - Provide live node health diagnostics (IPC connection status, memory, uptime, listen port).

- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/activity_journal_recovery_test.dart` in `windows/app/flutter`
  - Expected: PASS.

- [ ] **Step 5: Sync to other platform trees**

---

### Task 5: Search & Settings Real Configuration and Verified Live Status

**Files:**
- Modify: `windows/app/flutter/lib/features/search/search_screen.dart`
- Modify: `windows/app/flutter/lib/features/settings/settings_screen.dart`
- Modify: `windows/app/flutter/lib/features/files/files_screen.dart` (reconciliation and visible refresh errors)
- Sync to: `linux/`, `macos/`, `android/`, `peerlink-android-studio/`
- Test: `windows/app/flutter/test/search_settings_real_test.dart`

**Interfaces:**
- Consumes: Real local file system, `NodeIpcClient.currentState`, bandwidth RPC
- Produces: Genuine search index querying, verified live settings status, bandwidth controls, and visible transfer refresh error handling.

- [ ] **Step 1: Write failing widget test for Search & Settings**
  - Verify Search screen does not show hardcoded fake files when query is entered; searches real received/local files and indicates whether retrievable.
  - Verify Settings screen displays live node metrics (connection status, uptime, memory, storage cap) and enforces real bandwidth limits via `SetBandwidthLimit`.
  - Verify Files screen exposes visible error and retry banner when transfer list refresh fails.
  - Test file: `windows/app/flutter/test/search_settings_real_test.dart`.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/search_settings_real_test.dart` in `windows/app/flutter`
  - Expected: FAIL.

- [ ] **Step 3: Implement real search, live settings, and resilient files screen**
  - In `search_screen.dart`: Remove hardcoded list; perform search against real received/local files; distinguish local files from remote peer metadata.
  - In `settings_screen.dart`: Display live node execution status, uptime, memory usage, and listen port; add real bandwidth limit configuration calling `NodeIpcClient.instance.setBandwidthLimit`.
  - In `files_screen.dart`: When `_refreshTransfers` encounters an error, display an in-line warning banner with a "Retry" button instead of swallowing errors; separate active transfers from completed history with clear state labels (`VERIFYING`, `COMMITTING`, `OUTCOME_UNKNOWN`, etc.).

- [ ] **Step 4: Run test to verify it passes**
  - Run: `flutter test test/search_settings_real_test.dart` in `windows/app/flutter`
  - Expected: PASS.

- [ ] **Step 5: Sync to other platform trees**

---

### Task 6: Master Regression & Monorepo Test Suite Verification

**Files:**
- Run: `.\mvnw.cmd test -B`
- Run: `flutter test` in `windows/app/flutter`
- Run: `flutter test` in `peerlink-android-studio`
- Run: `.\test-all.ps1 -SkipGradle`

- [ ] **Step 1: Run full Maven test suite**
  - Verify all 345+ core and desktop-node tests pass.

- [ ] **Step 2: Run all Flutter test suites**
  - Windows: `flutter test`
  - Android: `flutter test` in `peerlink-android-studio`

- [ ] **Step 3: Run comprehensive master test script**
  - Run: `powershell -ExecutionPolicy Bypass -File .\test-all.ps1 -SkipGradle`
  - Expected: 100% Green across all modules and platforms.
