# PeerLink Final Recovery Validation

**Document Version**: 1.0  
**Phase**: 19 (Production Hardening)  
**Status**: VALIDATED & CERTIFIED

---

## 1. Crash and Power-Loss Recovery Contract

PeerLink adheres strictly to a zero-data-loss, zero-silent-corruption recovery model.

### 1.1 In-Flight Operation Recovery Table

| State Prior to Crash | State on Node Restart | Recovery Action Taken | Blind Replay Permitted? |
| :--- | :--- | :--- | :--- |
| `CREATED` | `CANCELLED` | Marked cancelled; user may re-initiate | **NO** |
| `PREPARING` | `CANCELLED` | Cleaned up from memory | **NO** |
| `VALIDATED` | `CANCELLED` | Preflight checks must be re-run | **NO** |
| `AUTHORIZED` | `CANCELLED` | Re-authorization required | **NO** |
| `EXECUTING` | `OUTCOME_UNKNOWN` | Flagged for peer query reconciliation | **NEVER** |
| `COMMITTED` | `COMMITTED` | Preserved as historical fact | N/A |
| `FAILED` | `FAILED` | Preserved with failure diagnostic | N/A |
| `CANCELLED` | `CANCELLED` | Preserved | N/A |

### 1.2 The `OUTCOME_UNKNOWN` Invariant
If a process crashes while writing chunks or sending final commit frames:
- PeerLink **never assumes** whether the remote peer received the file or committed it.
- The local node places the operation into `OUTCOME_UNKNOWN`.
- On reconnection, the `ReconciliationFramework` sends a lightweight `TransferOperationStatusQuery`.
- If the remote confirms receipt and SHA-256 match, the operation transitions to `COMMITTED`.
- If the remote reports failure or missing chunks, the transfer resumes from the last confirmed chunk offset.

---

## 2. Power-Cut & Staging Isolation

1. **Two-Phase Commit for Transfers**:
   - Phase 1: All chunks written to `.peerlink_staging/{transfer_id}/{item_index}.part`.
   - Phase 2: Once the full manifest is downloaded, verified against the expected SHA-256 hash, and scanned for malware:
     - Target destination is checked for conflict.
     - Atomic file rename / move is performed to destination path.
     - Staging directory is unlinked.
2. **Interrupted Writes**:
   - A power outage mid-write corrupts only the `.part` staging file.
   - On reboot, `NodeWatchdog` and `StagingDirectoryManager` identify uncommitted staging folders and clean them up.
   - Target files remain unmodified; zero 0-byte or truncated files are ever left in the user's directory.

---

## 3. Sync Divergence & Mass-Change Protection Recovery

1. **Causal Version Vector Clock**:
   - Each peer tracks causally independent modifications via `CausalVersion`.
   - Network disconnections or simultaneous offline edits never cause silent overwrites. Both changes are preserved; a `ConflictRecord` is registered.
2. **Mass Change Hold**:
   - If ransomware or an accidental `rm -rf` deletes hundreds of files, `MassChangeProtector` pauses synchronization immediately.
   - The user must explicitly inspect and confirm the deletions via the UI before tombstones are propagated to remote peers.

---

## 4. Backup & Restore Interruption Safety

1. **Immutable Historical Chains**:
   - Backup snapshots are content-addressed and cryptographically verified.
   - An interrupted backup snapshot job simply discards the incomplete snapshot metadata without corrupting previously completed snapshots.
2. **Safe Restore Operations**:
   - Restore restores files through staging first. If interrupted, the destination workspace is left intact.
