# Phase 19 Verification: SQLite, Schema, and Recovery Consistency

## 1. Executive Summary
**Status: PASS (20/20 standalone automated tests passed, 0 failures, 0 regressions)**

Phase 19 completed an evidence-based audit and normalization of PeerLink's local SQLite storage layer, schema migration pipeline, and crash recovery model.

Key accomplishments:
1. **Schema Migration v5 Implemented:** Added 10 normalized tables with foreign keys (`ON DELETE CASCADE`), indexes, and unique constraints for genuinely implemented features.
2. **First Normal Form (1NF) Normalization:** Replaced legacy comma-separated `operations.target_object_ids` with normalized `operation_targets` with ordering, including backward-compatible backfill migration from v4 databases.
3. **Intent vs. Verified Effect Distinction:** Decoupled user/AI requested `intent` (`OperationIntent`) from verified filesystem mutations (`operation_effects`), providing durable forensic verification.
4. **SQLite/Filesystem Boundary Non-Atomicity:** Acknowledged and solved the inability of database transactions to cover external filesystem mutations through `ReconciliationFramework`, crash classification (`CONFIRMED_COMMITTED`, `CONFIRMED_NOT_COMMITTED`, `CONFLICT_DETECTED`), and prohibition of blind replay.
5. **Durability & Crash Policy Documented:** Formally documented `WAL` mode, `synchronous = NORMAL`, and the boundary between process-crash durability vs. OS/power-loss guarantees.
6. **User Data Invariant Upheld:** Preserved user database files during corruption scenarios without silent deletion or recreation.

---

## 2. Evidence-Based Schema Audit

### 2.1 Audit of Genuinely Implemented Features & Storage Models

| Feature Domain | Legacy Schema (v1-v4) | Normalized v5 Schema | Constraints & Integrity |
| :--- | :--- | :--- | :--- |
| **Operation Targets** | Comma-separated `operations.target_object_ids` | `operation_targets` (1NF) | Foreign key to `operations(operation_id)` `ON DELETE CASCADE`, composite primary key `(operation_id, object_id)`, index on `object_id`. |
| **Verified Effects** | Implicit / untracked | `operation_effects` | Foreign key to `operations(operation_id)` `ON DELETE CASCADE`, indexed by `operation_id` and `target_path`. Records verified content SHA-256 and byte counts. |
| **Trusted Peers** | Unstructured metadata or in-memory | `trusted_peers` | Primary key `peer_id`, index on `device_id`, cryptographic revocation tracking (`is_revoked`, `revocation_reason`, `revoked_at`). |
| **Content & Lineage** | `object_index` (flat) | `object_versions` | Foreign key to `object_index(object_id)` `ON DELETE CASCADE`, composite PK `(object_id, version_seq)`, vector clock JSON lineage, tombstone support. |
| **Shares** | Ad-hoc or in-memory | `shares` & `share_allowed_peers` | Relational 1:N access list, expiration timestamps, grace periods, one-time consumption markers, guest access flags. |
| **Workspaces** | Flat directory references | `workspaces` & `workspace_members` | Policy epoch tracking, role hierarchy (`ADMIN`, `MEMBER`, `OBSERVER`), revocation flags, foreign keys. |
| **Backup Storage** | Blind metadata dumps | `backup_snapshots` & `backup_versions` | Deduplication tracking via `storage_hash`, file manifests, encryption flags, foreign key relationships. |
| **Malware Scans** | Ephemeral event logs | `scan_results` | Primary key `content_hash`, scan verdict caching, scanner engine attribution, scan duration metrics. |
| **Forensic Recovery** | Untracked restart logs | `recovery_journal` | Foreign key to `operations(operation_id)` `ON DELETE CASCADE`, records reconciliation decision, evidence hash, disk path, timestamp. |

### 2.2 Schema Evolution (v1 through v5)
- **v1 (Initial):** Core `operations` journal table with `state`, `intent`, `actor_peer_id`, `idempotency_key`, and `created_at`.
- **v2 (Crash Recovery):** Added `journal_stage`, `interrupted_at`, and `notes` to `operations`.
- **v3 (Object Indexing):** Added `object_index` table (`object_id`, `indexed_at`, `last_seen_at`).
- **v4 (Transfer Sessions):** Added `transfer_sessions` and `transfer_chunks` tables for resumable chunk transport.
- **v5 (Phase 19 Normalization):**
  - Added `operation_targets` and automatic backfill from v4 comma-separated fields.
  - Added `operation_effects` for post-execution verified filesystem effects.
  - Added `trusted_peers`, `object_versions`, `shares`, `share_allowed_peers`, `workspaces`, `workspace_members`, `backup_snapshots`, `backup_versions`, `scan_results`, and `recovery_journal`.
  - Added 14 high-performance indexes covering lookups, joins, and foreign key cascades.

---

## 3. Durable Operation Model & State Transitions

### 3.1 Valid State Machine Lifecycle
Operations strictly progress through the following deterministic lifecycle:
```
CREATED ──► VALIDATED ──► AUTHORIZED ──► EXECUTING ──► COMMITTED
   │             │             │             │
   ▼             ▼             ▼             ▼
CANCELLED     CANCELLED     CANCELLED     OUTCOME_UNKNOWN ──► RECOVERY_REQUIRED
                                             │
                                             └──► COMMITTED / FAILED (via Reconciliation)
```

- **Terminal States:** `COMMITTED`, `FAILED`, and `CANCELLED`. Once an operation enters a terminal state, terminal guard constraints prevent further modification.
- **Crash State:** Any operation found in `EXECUTING` state during node startup is transitioned to `OUTCOME_UNKNOWN`. It cannot be blindly executed or replayed.
- **Pre-Execution Cancellation:** Operations in `CREATED`, `VALIDATED`, or `AUTHORIZED` state at restart were never dispatched; they are safely transitioned to `CANCELLED`.

### 3.2 Distinguishing Intent from Verified External Effects
- **Requested Intent (`OperationIntent`):** Represents user or AI intent (`SEND`, `ACCESS`, `SYNC`, `BACKUP`, `CONNECT`, `WORKSPACE`, `CLIPBOARD`, `SMART_ACTION`).
- **Verified Effects (`operation_effects`):** Recorded only after the external filesystem mutation is completely committed and verified against disk (SHA-256 hash, bytes affected, verified timestamp).

---

## 4. SQLite / Filesystem Boundary & Non-Atomicity Recovery

### 4.1 Non-Atomicity Realities
Database transactions guarantee ACID properties for database rows, but **cannot** extend atomicity across local filesystems. If power is interrupted while writing file payload chunks or renaming staged files, SQLite state and disk state can diverge.

### 4.2 Reconciliation Framework
PeerLink implements `ReconciliationFramework.reconcileFilesystemBoundary(operationId, targetPath, expectedSha256)`:
1. **`CONFIRMED_COMMITTED`:** Target file exists on disk and its SHA-256 hash matches the expected hash. Safe to mark operation `COMMITTED` and record verified effect.
2. **`CONFIRMED_NOT_COMMITTED`:** Target file does not exist on disk. Safe to mark operation `FAILED` or cancel without destructive side effects.
3. **`CONFLICT_DETECTED`:** Target file exists but hash does not match, or I/O error occurred. Operation is escalated to `RECOVERY_REQUIRED` and flagged for manual or conflict resolution. Never blindly overwritten.

### 4.3 Recovery Journal
Every reconciliation decision is durably recorded in `recovery_journal`:
- `recovery_id` (UUID)
- `operation_id` (FK)
- `decision` (`CONFIRMED_COMMITTED`, `CONFIRMED_NOT_COMMITTED`, `CONFLICT_DETECTED`)
- `evidence_hash` (Disk file SHA-256 observed)
- `filesystem_path` (Path inspected)
- `reconciled_at` (Epoch ms)
- `explanation` (Forensic rationale)

---

## 5. SQLite Durability & Storage Policy

### 5.1 Pragmas and Journal Mode
PeerLink configures SQLite on every connection via `LocalSqliteStorage.initPragmas()`:
- `PRAGMA journal_mode = WAL;` (Write-Ahead Logging for high concurrency and crash resilience).
- `PRAGMA synchronous = NORMAL;` (Syncs at critical WAL checkpoints; zero database corruption on process crashes).
- `PRAGMA foreign_keys = ON;` (Strict relational referential integrity and cascade deletion).
- `PRAGMA temp_store = MEMORY;` (Fast temporary operations in memory).
- `PRAGMA cache_size = -8000;` (8 MB page cache).

### 5.2 Process-Crash vs. OS/Power-Loss Guarantees
- **Process-Crash Resilience (`synchronous = NORMAL`):** SQLite's WAL index and write-ahead log ensure complete transactional consistency across unexpected JVM termination, SIGKILL, or process crashes. No committed transactions are lost, and WAL recovery restores consistency on reopening.
- **Power-Loss / OS Crash Guarantee:** On abrupt power loss before a WAL checkpoint sync, uncheckpointed WAL frames may not have been flushed to physical platter/NAND cells if the drive controller reordered writes. PeerLink addresses this by combining `synchronous = NORMAL` with explicit atomic rename staging and `ReconciliationFramework` on startup.

### 5.3 Live User Data Preservation Invariant
**PeerLink never deletes or silently recreates a live user database.**
When `PRAGMA quick_check` or `PRAGMA integrity_check` detects database corruption:
1. Connection initialization fails explicitly with a detailed exception.
2. An `IntegrityCheckFailed` event is published to `NodeEventBus`.
3. The corrupt file remains untouched on disk for forensic inspection, backup restoration, or repair.

---

## 6. Verification Test Results

### 6.1 Phase 19 Standalone Test Suite Execution
Executed via `tools/run-phase19-tests.ps1`:

```
==========================================================
 PeerLink Phase 19 SQLite Schema & Recovery Consistency
==========================================================
Running Test 01: Clean Migration v0 -> v5 Schema Generation & PRAGMAs... PASS
Running Test 02: Upgrade from Existing v4 Database & Backfill Normalization... PASS
Running Test 03: Normalized operation_targets 1NF Storage & Ordering... PASS
Running Test 04: Foreign Key Cascade & Relational Constraints on Operations... PASS
Running Test 05: Distinguishing Requested Intent from Verified operation_effects... PASS
Running Test 06: Valid Operation State Machine Progression Lifecycle... PASS
Running Test 07: Invalid State Transition Rejection & Terminal Guard... PASS
Running Test 08: Duplicate Operation Idempotency Key Rejection... PASS
Running Test 09: Startup Recovery: Interrupted EXECUTING Marked OUTCOME_UNKNOWN... PASS
Running Test 10: Startup Recovery: Pre-Execution Operations Cleanly Cancelled... PASS
Running Test 11: Filesystem Boundary Reconciliation: Match -> CONFIRMED_COMMITTED... PASS
Running Test 12: Filesystem Boundary Reconciliation: Missing -> CONFIRMED_NOT_COMMITTED... PASS
Running Test 13: Filesystem Boundary Reconciliation: Mismatch -> CONFLICT_DETECTED... PASS
Running Test 14: Non-Atomicity SQLite-Filesystem Boundary Crash Recovery... PASS
Running Test 15: Normalized trusted_peers Storage & Cryptographic Revocation... PASS
Running Test 16: Normalized object_versions Causal Vector Clock Lineage... PASS
Running Test 17: Normalized shares Storage & share_allowed_peers Relations... PASS
Running Test 18: Normalized workspaces Scope & workspace_members Role Mapping... PASS
Running Test 19: Normalized backup_snapshots & backup_versions Deduplication... PASS
Running Test 20: Database Corruption Handling Without Deleting Live Database... PASS
==========================================================
 Phase 19 Test Execution Summary: 20 PASSED, 0 FAILED
==========================================================
```

### 6.2 Regression & Cross-Platform Parity Verification
- **Phase 18 (AI Gateway Boundaries):** 20 PASSED, 0 FAILED (`tools/run-phase18-tests.ps1`).
- **Phase 17 (Platform Integrations & Workspaces):** 20 PASSED, 0 FAILED (`tools/run-phase17-tests.ps1`).
- **Cross-Platform Invariant Parity:** 567 files checked, 0 accidental drift (`tools/sync-platform-shared/verify-shared.ps1`).
