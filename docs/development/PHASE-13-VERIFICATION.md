# PHASE 13 — BACKUP AND RESTORE: Verification Report

## PASS Criterion

A user can recover historical data and prove that the backup is reconstructable.

---

## Test Execution Summary (`BackupSystemTest.java`)

| # | Test Scenario | Verified Invariant | Status |
|---|---|---|:---:|
| 1 | `testFirstBackup` | Initial full backup captures all files, generates manifest, writes storage payloads | PASS |
| 2 | `testIncrementalBackup` | Unchanged files reuse storage hashes without duplicate upload/storage | PASS |
| 3 | `testChangedFile` | Changed file advances version sequence; old version payload retained in history | PASS |
| 4 | `testDeletedFile` | Deletion recorded as tombstone in manifest; past version chunks preserved | PASS |
| 5 | `testHistoricalRestoreCreatesNewVersion` | Restoring earlier snapshot creates a NEW current version sequence (never rewrites history) | PASS |
| 6 | `testPartialBackup` | Selective path inclusion backs up only specified subpaths | PASS |
| 7 | `testInterruptedBackup` | Mid-stream failure ensures no partial or corrupted manifest is committed | PASS |
| 8 | `testBackupVerificationShallowAndDeep` | Verifies reconstructability via manifest validation and deep checksum inspection | PASS |
| 9 | `testBackupVerificationBitrotDetection` | Deep verification flags bitrot and corrupted storage chunks | PASS |
| 10 | `testRetentionPolicyAndGarbageCollection` | Retention prunes expired snapshots and garbage-collects unreferenced storage chunks | PASS |
| 11 | `testProtectedVersionImmunity` | Protected snapshots are immune to retention pruning; protected versions preserved | PASS |
| 12 | `testRestoreConflictFailOnConflict` | Pre-flight conflict detection aborts without touching local modified files | PASS |
| 13 | `testRestoreConflictAlternativePath` | Conflicting files restored to timestamped alternative path without overwrite | PASS |
| 14 | `testBlindTargetBehavior` | Untrusted storage target holds only ciphertext; target lacks decryption authority; client reconstructs with secret key | PASS |

---

## Core System Invariants Verified

- **Unidirectional Semantics:** Source → Backup Target (receive-only by default; never bidirectional sync).
- **History Preservation:** Restoring an older snapshot creates a successor version with monotonic increment.
- **Deduplication:** Chunks with identical hashes are stored once and referenced across snapshots.
- **Blind Backup Security:** Storage encryption (AES-256-GCM) is separate from transport encryption; target possesses zero decryption authority.
- **Protected Versions:** Pinned versions and snapshots are strictly immune to retention pruning and GC.