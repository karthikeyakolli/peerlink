# Phase 03: Real SEND, Transfer State and Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete genuine SEND workflows through actual production UI and node on both Windows and Android, eliminating fabricated transfer IDs and mock staging, enforcing authoritative operation journaling, bounded chunk verification, safe staging, and failure recovery.

**Architecture:** 
- **Windows**: The Flutter desktop UI wires real file browsing and drag-and-drop directly into `NodeIpcClient.initiateSend()`. Production fallback paths that fabricate demo transfer IDs (`xfer-desk-...`) are removed. The Local Node daemon validates payloads and destination policies, enforces cryptographic trust checks, establishes/uses authenticated `PeerSession` instances over TCP/TLS, streams bounded chunks with SHA-256 integrity verification, and safely commits files after staging.
- **Android**: The standalone Flutter UI invokes `AndroidNodeBridge.initiateSend()`, which connects to `AndroidNodeFacade`. Content is resolved through genuine SAF/ContentResolver URI abstractions rather than raw filesystem paths. Operations are committed to the durable SQLite operation journal *before* acceptance, preventing premature transfer start events and ensuring durability across process recreation.
- **Shared**: Authoritative operation journal enforces idempotency, prevents blind replay of destructive operations, isolates unverified data in quarantine, and streams files without reading entire large payloads into RAM.

**Tech Stack:** Java 21/17 (portable Core, Netty TCP/TLS, SQLite WAL, JUnit 5), Dart 3.13 / Flutter 3.47 (Glassmorphic Material 3, gRPC, MethodChannel).

**Spec:** `AGENTS.md`, `docs/INDEX.md`, `docs/development/PHASE-WISE-PLAN.md`, `docs/transfer/ARCHITECTURE.md`, `docs/transfer/recovery/FAULT-TOLERANCE.md`.

## Global Constraints

- Never place normal user file content in Supabase.
- Never treat discovery as trust.
- Never treat timestamps as sync truth.
- Never treat watcher events as filesystem truth.
- Never blindly replay destructive operations after uncertain outcomes.
- Never auto-execute received files.
- Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
- Never trust localhost merely because it is localhost.
- Remove all fallback paths that fabricate transfer IDs or display successful staging when the node is disconnected.
- Preserve the user's selected files on error or node disconnection; never discard selections prematurely.
- Never load entire large files into memory solely to compute hashes or recover state.

## Review Focus

1. **Disconnected Node Failures**: Attempting to send when the Local Node daemon is offline must report an immediate failure state and retain the user's selected files without generating fake transfer IDs.
2. **Untrusted Peer Enforcement**: Attempting to send to an untrusted or revoked peer ID must be rejected by the Local Node before any data leaves the host.
3. **SAF Content-URI Distinction**: Android `content://` URIs must be handled via `ContentResolver` streams without ever casting to `java.io.File` or misinterpreting URIs as filesystem paths.
4. **Interrupted Transfer & Crash Recovery**: A transfer killed mid-stream must preserve valid chunks in staging, register the state in the durable operation journal, and resume without destructive re-write or corrupted hash commit.
5. **Memory Bounding**: Chunk streaming must use fixed buffers (e.g., 64 KB) with rolling SHA-256 calculation to support multi-gigabyte files without OutOfMemoryError.

---

### Task 1: Eliminate Fabricated Transfer Paths & Wire Real File Selection on Windows UI

**Files:**
- Create: `windows/app/flutter/lib/platform/windows_file_dialog.dart`
- Modify: `windows/app/flutter/lib/features/files/files_screen.dart`
- Modify: `windows/app/flutter/lib/design_system/components/desktop_dropzone.dart`
- Test: `windows/app/flutter/test/real_send_workflow_test.dart`

**Interfaces:**
- Produces: `WindowsFileDialog.pickFiles() -> Future<List<String>>`
- Produces: `WindowsFileDialog.pickDirectory() -> Future<String?>`
- Consumes: `NodeIpcClient.instance.initiateSend()`

- [ ] **Step 1: Write failing widget test in `real_send_workflow_test.dart`**
  - Verify that when `NodeIpcClient` is disconnected, `_initiateSend` displays an error banner and does NOT generate a fabricated transfer ID.
  - Verify that selected file paths are NOT cleared when an initiation fails.
  - Verify real file selection action updates the selected files list.

- [ ] **Step 2: Run test to verify it fails**
  - Run: `flutter test test/real_send_workflow_test.dart` in `windows/app/flutter`
  - Expected: FAIL due to existing mock fallback path generating `xfer-desk-...`.

- [ ] **Step 3: Implement `WindowsFileDialog` & real file selection in `files_screen.dart`**
  - Create `WindowsFileDialog` using Win32 / PowerShell OpenFileDialog to pick real Windows files and directories.
  - Replace fake `_quickMediaFiles` with actual selected file items (`SelectedFileInfo`).
  - Add "Add Files...", "Add Folder...", and "Clear" buttons.
  - Connect `DesktopDropzone` to accept dragged files and folders.
  - Remove fake `demoId = 'xfer-desk-...'` branch from `files_screen.dart`.
  - When disconnected, display: `"Local Node daemon is disconnected. Please start the node to transfer files."`
  - Keep `_sourcePathsController` and selected file state intact on failure.

- [ ] **Step 4: Run Flutter test to verify it passes**
  - Run: `flutter test test/real_send_workflow_test.dart`
  - Expected: PASS.

---

### Task 2: Implement Real Session Transfer Coordination & Staging Receiver in Java Local Node

**Files:**
- Modify: `core/src/main/java/org/peerlink/core/transfer/TransferSessionCoordinator.java`
- Modify: `core/src/main/java/org/peerlink/core/transfer/PeerTransferEngine.java`
- Modify: `core/src/main/java/org/peerlink/core/transport/PeerSessionManager.java`
- Modify: `desktop-node/src/main/java/org/peerlink/desktop/ipc/DesktopLocalNodeServiceImpl.java`
- Modify: `desktop-node/src/main/java/org/peerlink/desktop/runtime/DesktopNodeDaemon.java`
- Sync to: `windows/src/main/java/org/peerlink/`

**Interfaces:**
- Consumes: `PeerSessionManager`, `PeerTransferEngine`, `TransferSessionCoordinator`
- Produces: Bi-directional `TransferSessionCoordinator` multiplexing transfers on active `PeerSession`
- Produces: `PeerTransferEngine.sendTransferOverSession` with full chunk integrity & atomic commit

- [x] **Step 1: Write failing integration test for two-node real session transfer**
  - Test file: `desktop-node/src/test/java/org/peerlink/desktop/transport/RealSendWorkflowIntegrationTest.java`
  - Verify Alice Local Node sends a multi-chunk file to Bob Local Node over authenticated `PeerSession`.
  - Verify Bob receives chunks in staging, verifies full-file SHA-256, and commits to destination directory.
  - Verify invalid/untrusted peer is cleanly rejected.

- [x] **Step 2: Run test and verify it fails**
  - Run: `.\mvnw.cmd test -pl desktop-node -Dtest=RealSendWorkflowIntegrationTest -B`
  - Expected: FAIL / ClassNotFoundException.

- [x] **Step 3: Wire `PeerSessionManager` and `DesktopNodeDaemon` to register session receivers**
  - Add session lifecycle listener support to `PeerSessionManager` so new sessions automatically attach a `TransferSessionCoordinator` and `TransferSessionReceiver`.
  - Ensure `sendTransferOverSession` uses the session's active coordinator so response acks and incoming receiver messages do not overwrite each other.
  - Implement pause/resume and cancellation signaling over `TransferWireMessage`.
  - Ensure `DesktopLocalNodeServiceImpl.initiateSend` initiates an outbound transport session if one does not already exist with a trusted peer.

- [x] **Step 4: Run integration test to verify it passes**
  - Run: `.\mvnw.cmd test -pl desktop-node -Dtest=RealSendWorkflowIntegrationTest -B`
  - Expected: PASS with 100% hash verification and atomic commit.

---

### Task 3: Implement Genuine Android SAF Content-URI Handling & Durable NodeFacade

**Files:**
- Modify: `core/src/main/java/org/peerlink/core/android/AndroidNodeFacade.java`
- Modify: `core/src/main/java/org/peerlink/core/android/AndroidStorageAbstraction.java`
- Modify: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/android/AndroidNodeFacade.java`
- Modify: `peerlink-android-studio/lib/features/files/files_screen.dart`
- Sync to: `android/` and `shared-source/canonical/`
- Test: `core/src/test/java/org/peerlink/core/android/AndroidRealSendWorkflowTest.java`

**Interfaces:**
- Consumes: `AndroidStorageAbstraction.ContentResolverBridge`, `OperationJournal`
- Produces: `AndroidNodeFacade.initiateSend(PeerId, List<String> contentUris)`
- Produces: Durable operation journaling before transfer start event emission

- [x] **Step 1: Write failing unit/integration test for Android SAF Send & Journaling**
  - Test: `core/src/test/java/org/peerlink/core/android/AndroidRealSendWorkflowTest.java`
  - Verify `content://` URIs are resolved via `ContentResolverBridge` without touching `java.io.File`.
  - Verify operation record is durably written to `OperationJournal` before any transfer event is emitted.
  - Verify invalid/unreadable SAF URIs fail gracefully without creating orphan journal entries.
  - Verify state recovery across simulated process death.

- [x] **Step 2: Run test to verify failure**
  - Run: `.\mvnw.cmd test -pl core -Dtest=AndroidRealSendWorkflowTest -B`
  - Expected: FAIL.

- [x] **Step 3: Implement genuine SAF URI streaming & durable transfer acceptance**
  - Update `AndroidNodeFacade.initiateSend` to validate and resolve all `content://` URIs via `storageAbstraction`.
  - Create and durably commit `OperationRecord` to `operationJournal` in `PREPARING` state *before* returning transfer ID or emitting transfer-start events.
  - Add bounded chunk streaming from `InputStream` directly into transfer chunks.
  - Ensure failure states cleanly transition to `FAILED` with non-destructive cleanup.

- [x] **Step 4: Update Flutter Android UI (`peerlink-android-studio`)**
  - Remove mock `/storage/emulated/0/...` placeholders in Android UI.
  - Connect to `AndroidNodeBridge.initiateSend` and ensure user selections are preserved on rejection or failure.

- [x] **Step 5: Run Android unit/integration test to verify it passes**
  - Run: `.\mvnw.cmd test -pl core -Dtest=AndroidRealSendWorkflowTest -B`
  - Expected: PASS.

---

### Task 4: Cross-Platform Regression & Multi-Node Acceptance Verification

**Files:**
- Run: `test-all.ps1 -SkipGradle`
- Run: `windows/app/flutter` test suite
- Run: `peerlink-android-studio` test suite
- Run: `desktop-node` test suite

- [x] **Step 1: Run full Maven suite for Core and Desktop Node**
  - Run: `.\mvnw.cmd test -B`
  - Expected: 100% Green across all JVM reactor tests.

- [x] **Step 2: Run Flutter test suites on Windows and Android**
  - Run: `flutter test` in `windows/app/flutter`
  - Run: `flutter test` in `peerlink-android-studio`
  - Expected: All tests pass.

- [x] **Step 3: Run comprehensive verification script**
  - Run: `.\test-all.ps1 -SkipGradle`
  - Expected: All modules PASSED.
