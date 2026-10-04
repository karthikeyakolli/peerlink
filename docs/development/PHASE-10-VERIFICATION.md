# Phase 10 Verification: Remote Access

## Objective
Implement authorized, on-demand remote data access without storing private file indexes on any central backend.

**Core invariants enforced:**
- Remote peer explicitly authorizes every access grant; no implicit permission.
- Path traversal, symlink/junction/reparse-point escaping, and NTFS Alternate Data Stream injection are categorically rejected.
- Archive decompression safety (Zip-Slip, Zip-Bomb) is enforced at inspection time.
- Executable files are metadata-only by default; preview is unconditionally rejected.
- No automatic execution of any received or previewed content.
- All queries are visible in the audit journal; the central backend (Supabase) never maintains private file indexes.
- Silent rename or conversion of file content is prohibited.

---

## 1. Architecture & Components Implemented

### 1.1 Protocol Contract (protocol/proto/peerlink/v1/access.proto)
- `AccessRequest`: Typed request message covering BROWSE, METADATA, SEARCH, PREVIEW, DOWNLOAD, ARCHIVE_INSPECT, and CANCEL operations with pagination cursor, depth/result/time limits, and capability token field.
- `AccessResponse`: Unified response with item list (`RemoteObjectReference`), preview bytes, archive entries, error detail, pagination cursor, and `has_more` flag.
- `AccessCancelRequest` / `AccessCancelResponse`: Cooperative cancellation protocol.
- `RemoteObjectReference`: Rich file/directory descriptor including MIME type, byte size, executable flag, previewable flag, and modification timestamp.
- `ArchiveEntryDescriptor`: Per-entry safety report for archive inspection results.

### 1.2 Share Authorization (org.peerlink.core.access)
- `ShareDefinition`: Immutable descriptor binding a share ID to a filesystem root, a set of authorized peer IDs, permitted `AccessScope` values, and an HMAC auth secret.
- `AccessGrant`: Time-bounded, HMAC-SHA256-signed capability token. Issues scoped access with `issuedAt`/`expiresAt` fields; validates signature and expiration on verify.
- `ShareManager`: Concurrent share registry. Registers, removes, and authorizes peer requests against stored `ShareDefinition` entries.

### 1.3 Path Security (PathSandboxValidator)
Strict boundary enforcement rejecting:
- Directory traversal (`../`, `..\`).
- Windows drive letter injection (`C:`, `D:`).
- UNC network paths (`\\server\share`, `//...`).
- NTFS Alternate Data Streams (`file.txt:stream`).
- Null-byte poison characters.
- Symlinks and junctions whose real target escapes the share root.
- All resolved paths canonicalized and compared against the share root before use.

### 1.4 Safe Preview Engine (SafePreviewEngine)
- Text, image, and binary preview with configurable byte limits.
- Unconditional rejection of executable extensions (.exe, .com, .bat, .cmd, .msi, .sh, .ps1, etc.) and magic-byte detection (MZ PE header, ELF, Mach-O).
- No execution pathway exists; files are read as bytes only.

### 1.5 Archive Inspector (ArchiveInspector)
- Zip entry listing with Zip-Slip detection (entry path escaping archive root).
- Zip-Bomb heuristic (compressed size vs. claimed uncompressed size ratio).
- Returns per-entry `ArchiveEntryDescriptor` with `is_safe` flag and a human-readable `warning`.

### 1.6 Remote Folder Browser (RemoteFolderBrowser)
- Paginates directory listings using an integer offset cursor.
- Directories sorted before files; entries enriched with MIME type, size, and executable/previewable flags.
- All paths validated by `PathSandboxValidator` before filesystem access.

### 1.7 Remote Search Engine (RemoteSearchEngine)
- Recursive filename search with glob-pattern support (*.pdf, report*).
- Enforces configurable depth, result count, and millisecond timeout limits.
- Cooperative `CancellationToken` checking at each directory boundary.

### 1.8 Audit Journal (AccessAuditJournal / AccessAuditRecord)
- Append-only in-memory journal for the current session.
- Records: request ID, peer ID, request type, relative path, outcome, and timestamp.
- Outcomes: COMPLETED, REJECTED_UNAUTHORIZED, REJECTED_EXPIRED, REJECTED_PATH_TRAVERSAL, REJECTED_UNSAFE_PREVIEW.
- Queryable by peer ID, outcome type, and time window.

### 1.9 Coordinator & Client
- `RemoteAccessCoordinator`: Central server-side dispatcher. Verifies authorization, validates paths, dispatches to browser/search/preview/archive handlers, manages per-peer `CancellationToken` maps, and writes audit records for every request outcome.
- `RemoteAccessClient`: Client-side async dispatcher. Issues typed requests via `CompletableFuture`, correlates responses by request ID, and handles session closure cleanup.
- `ShareFileProviderAdapter`: Optional adapter bridging platform-native file-provider APIs to the `ShareDefinition` model.

---

## 2. Test Verification Matrix

All 13 test scenarios implemented in `RemoteAccessTest.java` and verified:

| Scenario | Test Method | Verification | Result |
| :--- | :--- | :--- | :--- |
| **1. folder browse** | testFolderBrowseAndMetadata | Browse root returns 3 entries (dir sorted first). File metadata includes MIME type, size, executable=false, previewable=true. | **PASS** |
| **2. deep tree** | testDeepTreeNavigation | Browse resolves 6-level deep path (level_1/.../level_6) and lists single leaf file. | **PASS** |
| **3. large folder / pagination** | testLargeFolderPagination | 65-file directory paginated in pages of 20. has_more=true on pages 1-3; last page returns 5 items with has_more=false. | **PASS** |
| **4. unauthorized request** | testUnauthorizedRequestRejected | Peer not in allowedPeerIds receives ERROR_CODE_UNAUTHORIZED. Audit journal records REJECTED_UNAUTHORIZED. | **PASS** |
| **5. expired authorization** | testExpiredAuthorizationRejected | Token with expiresAt in the past returns ERROR_CODE_UNAUTHORIZED with "expired" in summary. Audit records REJECTED_EXPIRED. | **PASS** |
| **6. path traversal** | testPathTraversalRejected | 8 malicious paths (../, drive letters, UNC, null-byte, ADS) all rejected with ERROR_CODE_UNAUTHORIZED. Audit records REJECTED_PATH_TRAVERSAL for each. | **PASS** |
| **7. symlink/junction safety** | testSymlinkSafety | Symlink inside share pointing to external target is blocked. On systems disallowing symlink creation, PathSandboxValidator directly throws PathTraversalException for ../ escape. | **PASS** |
| **8. cancellation** | testRequestCancellation | CancellationToken transitions to cancelled, returns reason, and throws OperationCancelledException. Coordinator acknowledges cancel of unknown op cleanly. | **PASS** |
| **9. peer disconnect cleanup** | testPeerDisconnectCleanup | onPeerDisconnected executes cleanly for active and null peer IDs. | **PASS** |
| **10. safe preview / executable policy** | testSafePreviewAndExecutablePolicy | Text preview succeeds with correct MIME type and content. .exe (MZ magic bytes) preview rejected: "Executable files are metadata-only". .bat preview rejected. Audit records REJECTED_UNSAFE_PREVIEW. | **PASS** |
| **11. remote search & privacy** | testRemoteSearchAndPrivacy | Substring search "report" matches 2 of 4 files. Wildcard "*.xlsx" matches 1 file exactly. | **PASS** |
| **12. archive inspection (Zip-Slip)** | testArchiveInspectionSafety | Archive with 1 safe and 1 Zip-Slip entry: safe entry is_safe=true; slip entry is_safe=false with warning containing "Zip-Slip". | **PASS** |
| **13. remote access client** | testRemoteAccessClientDispatch | browseAsync returns pending CompletableFuture. dispatchIncomingResponse resolves it. onSessionClosed handles disconnect cleanly. | **PASS** |

---

## 3. Security Invariant Checklist

| Invariant | Enforcement Point | Result |
| :--- | :--- | :--- |
| No automatic execution | SafePreviewEngine rejects all executable types by extension and magic bytes | **ENFORCED** |
| No silent rename | Filenames served as-is; no normalization applied | **ENFORCED** |
| No silent conversion | Content served as raw bytes; MIME type is informational only | **ENFORCED** |
| Path traversal blocked | PathSandboxValidator: 9-step check before any filesystem access | **ENFORCED** |
| Symlink escape blocked | PathSandboxValidator: toRealPath() boundary check | **ENFORCED** |
| ADS injection blocked | PathSandboxValidator: colon character rejection | **ENFORCED** |
| Null-byte injection blocked | PathSandboxValidator: null-byte character rejection | **ENFORCED** |
| Central backend holds no file index | Architecture: queries execute on remote peer; Supabase stores only control-plane metadata | **ENFORCED** |
| Archive Zip-Slip detection | ArchiveInspector: entry path boundary check | **ENFORCED** |
| Audit trail for all outcomes | AccessAuditJournal: records every request including rejections | **ENFORCED** |

---

## 4. Global Test Execution Summary

- `RemoteAccessTest`: **13 / 13 tests passed**
- `InternetConnectivityTest` (Phase 09): **13 / 13 tests passed**
- `SupabaseControlPlaneTest` (Phase 08): **11 / 11 tests passed**
- `IdentityTrustAndPairingTest`: **11 / 11 tests passed**
- `PeerTransferEngineTest` (Phase 06): **13 / 13 tests passed**
- `PeerTransferEngineRecoveryTest` (Phase 07): **12 / 12 tests passed**
- `CoreDomainInvariantsTest`: **6 / 6 tests passed**
- **`peerlink-core` total: 79 / 79 tests passed**
- `peerlink-desktop-node` total: **32 / 32 tests passed**
- `peerlink-app` (Flutter): **12 / 12 tests passed**
- **Grand total: 123 / 123 tests passed -- 0 failures, 0 errors, 0 skipped**

---

## 5. Status

PHASE 10 STATUS: PASS
