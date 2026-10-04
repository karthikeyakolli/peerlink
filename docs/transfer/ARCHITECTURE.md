# PeerLink Basic File Send Architecture & Transfer Protocol

## 1. Overview
The PeerLink File Send capability provides secure, point-to-point, user-visible direct file transmission between trusted devices. It is grounded in the zero-trust principle: **content truth lives exclusively in the local node filesystem, and unverified bytes must never contaminate destination storage.**

---

## 2. End-to-End Pipeline & State Machine

```
User Intent (Flutter UI)
          ↓
Local Node IPC (Authenticated gRPC)
          ↓
Object Resolution (FileManifestBuilder)
          ↓
Authorization (Peer Authorization & Session Check)
          ↓
Resource Preflight (TransferPreflight: Usable Space & Permissions)
          ↓
Session Connection (PeerSession: QUIC / TCP-TLS)
          ↓
Transfer (Chunk streaming into StagingDirectoryManager: .peerlink/staging/<transferId>/)
          ↓
Integrity Verification (Streaming SHA-256 calculation & manifest comparison)
          ↓
Atomic Commit (DestinationConflictResolver: FAIL_IF_EXISTS / OVERWRITE / RENAME_WITH_SUFFIX)
          ↓
Operation Journal & History (LocalSqliteStorage / OperationJournal: COMMITTED)
```

### Transfer State Lifecycle:
```
           ┌───────────┐
           │ PREPARING │ (Manifest generation, preflight checks)
           └─────┬─────┘
                 │
           ┌─────▼──────┐
           │ CONNECTING │ (Session validation with target peer)
           └─────┬──────┘
                 │
          ┌──────▼───────┐
    ┌────►│ TRANSFERRING │ (Chunk transmission & ACK tracking)
    │     └──────┬───────┘
    │            │
    │     ┌──────▼───────┐
    │     │   RECEIVED   │ (All chunks arrived in staging)
    │     └──────┬───────┘
    │            │
    │     ┌──────▼───────┐
    │     │  VERIFYING   │ (SHA-256 integrity calculation)
    │     └──────┬───────┘
    │            │
    │     ┌──────▼───────┐
    │     │  COMMITTING  │ (Atomic filesystem promotion & permission sanitization)
    │     └──────┬───────┘
    │            │
    │     ┌──────▼───────┐
    │     │  COMPLETED   │ (Receipt issued, history updated)
    │     └──────────────┘
    │
    ├──────────────────────────┐
    ▼                          ▼
┌────────┐               ┌───────────┐
│ FAILED │ (Purges stage)│ CANCELLED │ (Purges stage)
└────────┘               └───────────┘
```

---

## 3. Core Components & Responsibilities

### 3.1 FileManifestBuilder (`org.peerlink.core.transfer.FileManifestBuilder`)
- Generates reproducible, portable transfer manifests.
- Computes streaming SHA-256 hashes per item and aggregate root hash.
- Supports single files, multiple files, empty zero-byte files, and complex directory trees.
- Normalizes path separators to standard forward slashes (`/`), stripping Windows backslashes and drive letters.
- Canonical UTF-8 Unicode filename preservation.

### 3.2 TransferPreflight (`org.peerlink.core.transfer.TransferPreflight`)
- Verifies destination directory existence or creates parent directories safely.
- Performs disk space preflight: verifies `usableSpace >= totalBytesNeeded + reserveBytes (50MB)`.
- Verifies write permissions on destination filesystem prior to accepting transfer offers.
- Fast-fails with machine-readable error details before network bandwidth is wasted.

### 3.3 DestinationConflictResolver (`org.peerlink.core.transfer.DestinationConflictResolver`)
- Enforces strict collision resolution policies:
  - `FAIL_IF_EXISTS`: Throws `DestinationConflictException` if destination file exists.
  - `OVERWRITE`: Safely replaces destination target upon successful verification.
  - `RENAME_WITH_SUFFIX`: Appends deterministic numeric suffix `filename (1).ext` while preserving original extension.
- Prevents directory traversal attacks (`../` or `..\\`) using path canonicalization.

### 3.4 StagingDirectoryManager (`org.peerlink.core.transfer.StagingDirectoryManager`)
- Isolates in-flight content in `.peerlink/staging/<transferId>/`.
- Chunks written to temporary staging files (`.part`).
- **NEVER** writes unverified content directly to final destination.
- Runs cryptographic verification: compares computed SHA-256 against expected manifest hash.
- On verification success: executes atomic rename / promotion (`Files.move(..., ATOMIC_MOVE)`).
- Strips executable permissions (`setExecutable(false)`) on committed files to ensure received files are never executed.
- On cancellation or failure: cleans up and purges staging directory immediately.

### 3.5 TransferProgressTracker (`org.peerlink.core.transfer.TransferProgressTracker`)
- Thread-safe tracking of transferred bytes, total bytes, item index, and state.
- Real-time rolling speed estimation (bytes per second).
- Instant cancellation support with atomic cancellation flags.

### 3.6 PeerTransferEngine (`org.peerlink.core.transfer.PeerTransferEngine`)
- Sender and receiver coordination orchestrating manifests, offers, chunks, verify results, and commit signals.
- Tied directly to `OperationJournal` (`CREATED → VALIDATED → AUTHORIZED → EXECUTING → COMMITTED`).

### 3.7 Desktop Local Node & UI Integration
- IPC endpoints in `DesktopLocalNodeServiceImpl`: `InitiateSend`, `CancelTransfer`, `GetTransfer`, `ListTransfers`, `RevealInFolder`.
- Windows shell integration in `RevealInFolderUtil` using native `explorer.exe /select,"<path>"`.
- Flutter UI in `apps/peerlink-app/lib/features/files/files_screen.dart` with live progress bars, speed gauges, verification badges, cancellation, and folder reveal.

---

## 4. Security Rules & Invariants
1. **Never write unverified final content directly to final destination:** All bytes land in staging.
2. **Never execute received files:** Executable permissions are stripped upon commit.
3. **Never silently rename due to incompatibility:** Policy is explicit (`FAIL_IF_EXISTS`, `OVERWRITE`, `RENAME_WITH_SUFFIX`).
4. **Never silently convert files:** Bytes received match bytes sent byte-for-byte.
5. **Durable Journaling:** Every transfer is backed by an `OperationRecord` ensuring auditability and crash recovery.
