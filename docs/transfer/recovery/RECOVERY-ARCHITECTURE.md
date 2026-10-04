# PeerLink Resumable Transfer & Recovery Architecture

## 1. Executive Summary

Phase 07 transforms PeerLink's basic SEND engine into a battle-tested, fault-tolerant, resumable, and recoverable transfer engine capable of surviving network partitions, abrupt node terminations, corrupt chunks, and lost acknowledgements without corrupting data or duplicating commits.

```
       Sender Node                                      Receiver Node
  ┌───────────────────┐                             ┌───────────────────┐
  │  OperationJournal │                             │  OperationJournal │
  │ TransferSession   │                             │ TransferSession   │
  │      Journal      │                             │      Journal      │
  └─────────┬─────────┘                             └─────────┬─────────┘
            │                                                 │
            │ 1. TransferOffer(Manifest)                      │
            ├────────────────────────────────────────────────►│ (Resource Preflight)
            │                                                 │ (Prepare Staging)
            │ 2. TransferResponse(Accepted)                   │
            │◄────────────────────────────────────────────────┤
            │                                                 │
            │ 3. TransferChunk (with SHA-256)                 │
            ├────────────────────────────────────────────────►│ (Write to Staging)
            │ 4. TransferChunkAck(Success/Retry)              │ (Check Chunk Hash)
            │◄────────────────────────────────────────────────┤
            │                                                 │
            │ [Failure / Pause / Kill / Disconnect]           │
            │                                                 │
            │ 5. TransferResumeOffer                          │
            ├────────────────────────────────────────────────►│ (Inspect Staging)
            │ 6. TransferResumeState(AckedChunkIndices)       │ (Query Acked Bitset)
            │◄────────────────────────────────────────────────┤
            │                                                 │
            │ 7. Transfer Remaining Chunks Only               │
            ├────────────────────────────────────────────────►│
            │                                                 │
            │                                                 │ (Cryptographic Verify)
            │                                                 │ (Atomic Dest Commit)
            │                                                 │ (Store Receipt)
            │ 8. TransferCompletedReceipt [LOST IN TRANSIT]   │
            │   - - - - - - - - - - - - - - - - - - - - - ✖   │
            │                                                 │
            │ (Timeout / Mark OUTCOME_UNKNOWN)                │
            │ 9. TransferOperationStatusQuery(OperationId)    │
            ├────────────────────────────────────────────────►│ (Lookup Journal/Receipt)
            │ 10. TransferOperationStatusResponse(Committed)  │
            │◄────────────────────────────────────────────────┤ (Never Re-Commit!)
            ▼                                                 ▼
```

---

## 2. Core Architectural Pillars

### 2.1 Durable Transfer Manifest & Chunk State
- **TransferManifest**: Uniquely identified by `transfer_id` and durable `operation_id`. Contains total bytes, chunk size (64 KB default), item count, and full cryptographic SHA-256 manifests.
- **ChunkStatus**: Each chunk moves through a strict lifecycle:
  `CHUNK_STATUS_PENDING` → `CHUNK_STATUS_IN_FLIGHT` → `CHUNK_STATUS_ACKED` or `CHUNK_STATUS_FAILED`.
- **TransferSessionJournal**: Authoritative journal tracking per-chunk ACKs, received byte counts, and completion receipts. Persisted across engine restarts.

### 2.2 Isolated Destination Staging & Multi-File Transactions
- All chunks are written to isolated staging (`<staging_root>/<transfer_id>/<item_index>.part`).
- Files are **NEVER** written unverified to the destination directory.
- All items in a multi-file transfer are cryptographically verified against SHA-256 before any file is promoted.
- If any file fails verification or the destination runs out of disk space, the entire transfer rolls back: staging files are expunged and zero partial files exist in the destination.
- Once verified, files are atomically committed (`StandardCopyOption.ATOMIC_MOVE`).

### 2.3 Resumption & Bandwidth Throttling
- **Pause & Resume**: Transfer can be cleanly paused (`TRANSFER_STATE_PAUSED`).
- **Selective Retransmission**: When resuming, receiver responds with `TransferResumeState` containing `acked_chunk_indices`. Sender transmits **only** un-ACKed chunks.
- **Duplicate Resume Idempotence**: Redundant `TransferResumeOffer` requests produce consistent, idempotent resume states without corrupting active transfers.
- **Bandwidth Controls**: `BandwidthLimiter` implements a token-bucket rate limiter enabling dynamic bandwidth caps (`setRateLimit(bytesPerSecond)`).

### 2.4 Lost Final ACK & `OUTCOME_UNKNOWN` Reconciliation
- **Critical Invariant**: If receiver successfully commits files and records the receipt, but the network drops before sender receives the final ACK:
  1. Sender marks the operation as `OUTCOME_UNKNOWN`.
  2. Sender reconnects and queries the receiver via `TransferOperationStatusQuery` with the durable `operation_id`.
  3. Receiver inspects its `OperationJournal` and `TransferSessionJournal`, confirms the operation was already committed, and returns `is_committed = true` with the original `TransferCompletedReceipt`.
  4. Sender transitions local operation to `COMMITTED` and saves the receipt.
  5. **NEVER** blindly retry destructive or committing actions!

### 2.5 Startup Crash Recovery
- When a node starts up, `StartupRecoveryManager` inspects the journal:
  - All operations left in `EXECUTING` state are automatically marked `OUTCOME_UNKNOWN`.
  - Operations left in `CREATED` or `VALIDATED` are safely marked `CANCELLED`.
  - Staging directories for non-terminal operations are retained for resumption.
