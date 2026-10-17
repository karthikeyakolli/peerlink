# PeerLink Android Studio Edition — System Architecture

**Document Version:** 1.2.0 (Phase 25 Verified Baseline)  
**Target:** Standalone Android Application Workspace (`peerlink-android-studio`)

---

## 1. Architectural Philosophy

PeerLink is a privacy-first, distributed personal data platform. It is designed to connect personal devices directly without intermediate cloud storage. The Android Studio edition provides a self-contained, mobile-first implementation with strict physical separation from other platform targets.

```
+---------------------------------------------------------------------------------------+
|                                    Flutter UI Shell                                   |
|   (Material 3, Mobile Navigation, Send/Receive, Device Pairing, Sync, History, Settings) |
+-------------------------------------------+-------------------------------------------+
                                            | Platform Channel / Event Stream
                                            v
+---------------------------------------------------------------------------------------+
|                                  Native Android Host                                  |
|                               (Kotlin / Java 17 / AGP 9.1.0)                          |
|                                                                                       |
|  +---------------------------------------------------------------------------------+  |
|  |                             AndroidNodeFacade                                   |  |
|  |  Coordinates lifecycle, environmental changes, Keystore identity, and storage   |  |
|  +---------------------+-------------------+-------------------+-------------------+  |
|                        |                   |                   |                      |
|                        v                   v                   v                      v
|  +---------------------+   +---------------+   +---------------+   +---------------+  |
|  | AndroidKeyStore     |   | SafStorage    |   | Discovery     |   | Services      |  |
|  | - Ed25519 Identity  |   | - Scoped SAF  |   | - Android NSD |   | - Foreground  |  |
|  | - AES-GCM at rest   |   | - Quarantine  |   | - Wi-Fi Direct|   | - WorkManager |  |
|  | - Truthful SecLevel |   | - Checksums   |   | - mDNS/DNS-SD |   | - Notifs      |  |
|  +---------------------+   +---------------+   +---------------+   +---------------+  |
|                                                                                       |
|  +---------------------------------------------------------------------------------+  |
|  |                      Durable SQLite Operation Journal (Phase 25)                |  |
|  | - SQLite WAL mode + Foreign Keys                                                |  |
|  | - Unique index on idempotency_key                                               |  |
|  | - Strict terminal state transition guards                                       |  |
|  | - Startup Reconciliation without Blind Replay (Rule 9)                         |  |
|  +---------------------------------------------------------------------------------+  |
|                                                                                       |
|  +---------------------------------------------------------------------------------+  |
|  |                       Core Transfer & Protocol Engine                           |  |
|  | - Wire Contracts (Protobuf v1: peerlink/v1/*.proto)                             |  |
|  | - 3-Way Ed25519 Handshake & Zero-Trust Peer Verification                        |  |
|  | - Full Duplex Streaming over Framed OS TCP Sockets                              |  |
|  | - Chunked Transfer with End-to-End SHA-256 Integrity                            |  |
|  | - Safe Destination Handler (Atomic Quarantine Staging, Executable-Stripping)    |  |
|  | - Authoritative Access Scope Enforcement, Token HMACs, and Path Sandbox        |  |
|  | - Causal Vector Clock Ordering (Rule 7: Timestamps are NOT Sync Truth)          |  |
|  | - Snapshot Retention Pruning and Safe Restore (Refuses Silent Overwrite)       |  |
|  | - Statvfs SELinux Fallback (File.getUsableSpace) for Android Sandbox            |  |
|  +---------------------------------------------------------------------------------+  |
+---------------------------------------------------------------------------------------+
```

---

## 2. Component Separation & Boundaries

### 2.1 Cryptographic Identity, Fingerprinting & Pairing Safety
- **Protocol Identity:** Conforms strictly to PeerLink standard `KeyType.KEY_TYPE_ED25519`.
- **Derivation Rule:** `DERIVATION_RULE_V1 = "v1:ed25519:sha256_16"` (`peer_<16-hex>`).
- **Full Fingerprint (Phase 25):** Full 64-hex SHA-256 digest formatted as `SHA256:<64-hex>` via `getFullFingerprintHex()`, providing 256-bit second-preimage collision resistance.
- **Short Fingerprint:** Formatted as `SHA256:<16-hex>` for concise display in compact UI lists.
- **Out-of-Band Pairing Safety Numbers (Phase 25):** 30-digit numeric SAS (Short Authentication String) formatted into 6 blocks of 5 digits (e.g., `12345 67890 12345 67890 12345 67890`), derived deterministically from SHA-512 over the lexicographically sorted public keys of both peers (`computeSafetyNumber`). Symmetric derivation ensures both initiator and responder view identical verification codes regardless of who initiates the connection.
- **Storage Protection at Rest:** Android KeyStore does not natively support Ed25519 keypair generation or signing. The Ed25519 private key is held in memory by `PeerCryptoSigner` and encrypted at rest using AES-256-GCM. The AES-256 master key is generated and stored securely in `AndroidKeyStore` (`AndroidKeyStoreProvider`), targeting StrongBox/TEE where available.
- **AES-GCM Nonce Uniqueness:** Each encryption operation generates a fresh cryptographically random 96-bit IV directly via `SecureRandom` or `KeyStoreProvider` (`cipher.getIV()`). Reusing nonces across encryptions is strictly prevented.
- **Truthful Security Level Reporting:** `isDirectHardwareSigning()` truthfully returns `false`. `isHardwareProtectedAtRest()` returns `true` only when the underlying AES master key is verified to reside in hardware (`SecurityLevel.STRONGBOX` or `SecurityLevel.TRUSTED_ENVIRONMENT`).
- **Corruption Invariant:** Corrupted identity metadata, altered master keys, or tampered private key ciphertexts fail closed and refuse silent regeneration, preventing accidental device identity forks or security bypass.

### 2.2 Networking & P2P Connectivity
- **Local Discovery:** Uses Android `NsdManager` (`_peerlink._tcp.local`) for discovery on the local Wi-Fi network. Discovery is strictly informational and does not constitute trust.
- **Connection Establishment:** Direct TCP client/server sockets on high ports (`StandardTcpTransportProvider`).
- **Handshake & Mutual Authentication:** 3-way Ed25519 cryptographic challenge-response (`HandshakeRequest`, `HandshakeResponse`, `HandshakeAck`). Nodes exchange ephemeral nonces, sign them with their respective Ed25519 private keys, and verify against their local `TrustStore`.
- **Zero-Trust Enforcement:** Untrusted peers attempting connection are immediately rejected with `ERROR_CODE_UNAUTHENTICATED` without disclosing internal state.
- **Payload Framing:** 4-byte length-prefixed protocol buffer messages streamed over duplex TLS/TCP channels.
- **ICE / TURN Relay Demarcation:** Direct LAN socket transport is fully functional and verified. STUN/TURN traversal interfaces exist for NAT traversal but are demarcated from direct LAN operations.

### 2.3 The Four Real Operation Modes
1. **SEND Mode:** Selected content (via SAF `content://` or filesystem) is transmitted via chunked protobuf messages (`TransferManifest`, `TransferChunk`, `TransferChunkAck`). Receiver verifies each chunk's SHA-256 digest, stages bytes in `.part` quarantine files, verifies the overall file hash, and atomically commits to the destination. Received files have executable bits stripped.
2. **ACCESS Mode:** Implemented by `RemoteAccessCoordinator` and `ShareManager`. Enforces authoritative capability tokens, HMAC verification, granular scope restrictions (`BROWSE`, `DOWNLOAD`, `SEARCH`, `PREVIEW`), instant owner revocation, and strict path sandboxing rejecting directory traversal escapes (`../`).
3. **SYNC Mode:** Implemented by `SyncManifest`, `SyncObject`, `ConflictDetector`, and `CausalVersion`. Employs vector clocks for causal ordering across peers. Invariant Rule 7 is strictly enforced: timestamps are never used as conflict authority. Detected concurrent edits (`DELETE_VS_MODIFY`, `CONCURRENT_CONTENT_EDIT`) are surfaced for explicit resolution. Deletions produce persistent `Tombstone`s that persist through offline reconciliation.
4. **BACKUP Mode:** Implemented by `BackupEngine` and `FileBasedBackupTarget`. Creates point-in-time immutable snapshot manifests with SHA-256 verification. Applies retention policies (`RetentionPolicy.keepLastN(N)`) to prune unreferenced historical snapshots while preserving protected versions. Safe restore under `FAIL_ON_CONFLICT` refuses silent overwriting of conflicting user files.

### 2.4 Durable Operation Journal & Startup Recovery (Phase 25)
- **Persistent SQLite Journal:** `AndroidSqliteOperationJournal` provides ACID transaction durability backed by Android's native SQLite database (`peerlink_journal.db`):
  - **Write-Ahead Logging (WAL):** Enabled via `PRAGMA journal_mode=WAL` with `PRAGMA foreign_keys=ON`.
  - **Terminal State Guards:** Once an operation enters a terminal state (`COMMITTED`, `ABORTED`, `FAILED`, `OUTCOME_UNKNOWN`), subsequent transitions throw `IllegalStateException`.
  - **Idempotency Guarantee:** A unique SQL index on `idempotency_key` rejects duplicate submissions with `IllegalArgumentException`.
  - **Chunk Progress Persistence:** Tracks incremental chunk index and bytes transferred for resumable operations.
- **Startup Recovery Reconciliation (Rule 9):** Implemented by `AndroidStartupRecoveryManager`:
  - Scans all uncommitted or in-flight operations left behind from unexpected process termination.
  - Verifies target staging files and destination hashes rather than blindly replaying destructive operations.
  - If a destination file already exists and matches the expected SHA-256 digest, transitions the operation safely to `COMMITTED`.
  - If bytes are partial or invalid, safely cleans up staging artifacts (`.part` quarantine files) and marks the operation `OUTCOME_UNKNOWN` with descriptive diagnosis notes.

### 2.5 Android Lifecycle, Background Execution & Sandbox Compat
- **Foreground Service:** `PeerLinkForegroundService` is registered as `FOREGROUND_SERVICE_TYPE_DATA_SYNC` under Android 14+ (API 34–36/37) requirements with persistent status notifications.
- **WorkManager:** `PeerLinkSyncWorker` runs periodic sync and backup tasks when unmetered network and non-low battery constraints are satisfied.
- **SELinux Statvfs Fallback:** On Android, unprivileged apps reading `/proc/mounts` via `Files.getFileStore()` trigger `SecurityException`. PeerLink catches this and falls back to `File.getUsableSpace()` (statvfs), ensuring disk space preflight checks succeed reliably on all Android API levels.

---

## 3. Physical Source Isolation

The standalone Android Studio workspace does not depend on any outer directories:
- **No Symlinks:** All required classes and resources exist physically within `peerlink-android-studio/`.
- **No Path Escapes:** Neither `pubspec.yaml` nor `build.gradle.kts` uses paths containing `../..` that escape `peerlink-android-studio/`.
- **Clean Java Set:** Only Android-compatible Java classes are copied into `android/app/src/main/java/`. Desktop-only packages (`java.net.http`, `java.lang.management`, `DesktopLocalNodeServiceGrpc`) are strictly omitted.

