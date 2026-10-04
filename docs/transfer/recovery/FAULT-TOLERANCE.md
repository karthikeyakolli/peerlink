# PeerLink Fault Tolerance & Failure Scenarios Guide

This document details the 12 failure modes evaluated, handled, and verified under Phase 07.

---

## 1. The 12 Deliberate Failure Modes & Recovery Mechanics

| # | Scenario | Failure Trigger | Engine Behavior & Recovery | Invariant Upheld |
|---|----------|-----------------|-----------------------------|-------------------|
| **1** | **Interrupt at 10%** | Pause/kill after first 10% bytes streamed | Sender pauses cleanly. On resume, receiver reports ACKed chunks bitset. Sender transmits **only** remaining ~90% missing chunks. | **Zero Duplicate Retransmission**: Previously ACKed bytes are never resent. |
| **2** | **Interrupt at 40%** | Network interrupted at 40% bytes | Receiver retains staged `.part` chunks. Sender resumes via `TransferResumeOffer`. Only remaining ~60% chunks are transferred. | **Progress Preservation**: Staged progress is never discarded on transient interruption. |
| **3** | **Kill Receiver** | SIGKILL / abrupt exit on receiver process | Staging directory retains valid written `.part` files. Upon receiver node restart, staging manager scans partial chunks. Resumption completes remaining chunks and promotes to destination. | **Crash Durability**: Receiver restart does not invalidate partially written chunks. |
| **4** | **Kill Sender** | Process termination on sender node | Sender restarts, reads `TransferSessionJournal`, identifies in-flight transfer, sends `TransferResumeOffer` to receiver, queries ACKed chunks, and streams missing chunks to completion. | **Client Crash Recovery**: Sender can resume interrupted operations across restarts. |
| **5** | **Disconnect Network** | TCP RST / FIN / keepalive timeout mid-stream | In-flight transfer transitions to `TRANSFER_STATE_PAUSED`. Operation stage remains in `WAITING`. No staging files are removed. | **Pristine Destination**: Destination folder has zero partial or corrupt files. |
| **6** | **Reconnect** | Network interface recovers / peer rediscovers | Sender issues `TransferResumeOffer`. Receiver accepts with bitset of ACKed chunks. Transfer completes and files are cryptographically verified. | **Automatic Reconnection**: Seamless resume without manual user restart. |
| **7** | **Corrupt a Chunk** | Single bitflip / byte corruption during chunk transit | Receiver checks chunk SHA-256 before disk write. On mismatch, returns `TransferChunkAck(success=false, retry_requested=true)`. Sender resends chunk up to 3 times. Retry succeeds. | **Per-Chunk Verification**: Corrupt chunks are detected and retried immediately before whole-file verify. |
| **8** | **Fill Destination Disk** | Usable disk space < required manifest bytes | **(a) Preflight**: rejects offer upfront with `ERROR_CODE_RESOURCE_EXHAUSTED`. **(b) Mid-transfer**: staging cleaned up, destination left untouched. | **No Partial Write**: Destination disk is protected from partial orphan files. |
| **9** | **Mutate Source During Transfer** | File modified (size, timestamp, hash) on sender disk | `validateSourceFile()` detects divergence in size or `lastModifiedTime`. Aborts transfer with `SourceMutationException`. Operation marked `FAILED`. | **Content Truth**: Destination never receives torn or mutated content. |
| **10** | **Duplicate Resume Request** | Network retransmit causes duplicate `TransferResumeOffer` | Receiver processes resume offer idempotently, returning identical `TransferResumeState`. | **Idempotent Negotiation**: Duplicates do not spawn duplicate staging or file corruption. |
| **11** | **Lose Final Acknowledgement** | Remote receiver commits successfully, but final ACK drops | Sender marks operation as `OUTCOME_UNKNOWN`. Sender reconnects and queries `TransferOperationStatusQuery`. Receiver returns `is_committed = true` with original receipt. Sender commits locally. | **NO Blind Replay**: Commits and destructive actions are NEVER repeated blindly. |
| **12** | **Restart Both Peers** | Both sender and receiver killed simultaneously | Both recover durable journals on restart. Sender queries receiver state, retrieves ACKed chunks list, sends remainder, passes SHA-256 verification, and commits. | **Bilateral Fault Tolerance**: Full recovery even if all cluster members restart. |

---

## 2. Measurement Assertions

Each test measures and validates 4 concrete metrics:
1. **Retransmitted Data (bytes)**: Must equal exactly the byte count of missing/un-ACKed chunks. Already ACKed bytes are strictly 0 retransmitted bytes.
2. **Recovery Time (ms)**: Measured from failure injection to final verified receipt generation.
3. **Resulting Content Hash (SHA-256)**: Final committed file in destination is cryptographically verified to match the source file SHA-256 bit-for-bit.
4. **Final Operation State**: Verified as `COMMITTED` in both sender and receiver `OperationJournal`.
