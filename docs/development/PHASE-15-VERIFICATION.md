# PeerLink Phase 15 Verification Report: Versioned Backup & Restore

**Date:** October 13, 2026  
**Status:** PASS (20 of 20 Tests Passed, 100% Assertion Success)  
**Execution Environment:** OpenJDK 25 (Pure Java SE Runtime) on Windows 11  
**Test Suite:** `Phase15StandaloneTestRunner` (`tools/run-phase15-tests.ps1`)  
**Cross-Platform Parity:** PASS (565 invariant files checked, 0 accidental drift)

---

## 1. Executive Summary

Phase 15 implements, hardens, and verifies PeerLink's **Versioned Backup & Restore** subsystem, establishing it as an immutable, unidirectional preservation engine strictly distinct from bidirectional synchronization.

Key architectural invariants verified:
1. **Unidirectional Preservation vs Bidirectional Sync:**
   - The backup target functions as a receive-only repository (source → target).
   - The target never initiates sync or pushes files back to the source.
2. **Sync Tombstone & Remote Deletion Immunity:**
   - Sync tombstones or remote deletions occurring in sync replicas or local working trees never erase historical backup snapshots or underlying storage payloads.
   - Deletions in the source directory record tombstones only in the *new* incremental manifest, preserving older historical versions intact.
3. **The Cardinal Restore Rule (Never Rewrite History):**
   - Restoring an older snapshot creates a **NEW current version sequence** ($N+1$).
   - History is never rewound; causality moves strictly forward.
4. **Active Recovery & Operation Locks on Retention:**
   - Snapshots and versions needed by active operations or recovery tasks are locked (`activeRecoveryLocks`) and strictly immune to retention pruning.
   - Restoring automatically acquires a recovery lock on the target snapshot to prevent concurrent garbage collection.
5. **Verified Staging & Atomic Exposure:**
   - Restored content is verified before being exposed as a completed restored object.
   - Restores write to private staging files (`.${file}.part.${uuid}.tmp`), force to disk, read back from disk to verify cryptographic hash equivalence, and atomically rename (`ATOMIC_MOVE`) to the target destination.
6. **Conflict Safety & Collision-Free Destination Resolution:**
   - `FAIL_ON_CONFLICT`: Detects pre-existing differing destination files and aborts cleanly without modifying or overwriting any files.
   - `RESTORE_TO_ALTERNATIVE_PATH`: Resolves collision-free alternative paths (`${file}.restored.${timestamp}.${counter}`) without overwriting existing files, even across repeated restore requests.
   - `OVERWRITE_WITH_NEW_VERSION`: Restores file via verified atomic staging while incrementing version sequence.
7. **Pre-Flight Permissions & Disk Capacity Validation:**
   - Pre-flight checks verify read permissions on source files, write permissions on restore destination, and ensure usable disk capacity (`getFileStore().getUsableSpace()`) exceeds total payload size before starting.
8. **Underlying Byte Durability (`FileBasedBackupTarget`):**
   - Backup durability is proven by actual disk persistence and bit-for-bit recoverability of payloads and manifests from physical disk storage, independent of SQLite metadata.

---

## 2. Test Execution Summary (20/20 PASS)

| Test ID | Test Scenario | Verified Behavior | Result |
|:---|:---|:---|:---:|
| **Test 01** | First Backup & Snapshot Manifest | Produces full snapshot manifest with items, storage hashes, and receive-only payload storage. | **PASS** |
| **Test 02** | Incremental Deduplication via Storage Hashes | Unchanged files reuse `storageHash` without storing redundant payload bytes on target. | **PASS** |
| **Test 03** | Edits Advance Sequence & Retain Earlier Payloads | Edited files advance `versionSequence` while preserving `ObjectIdentity` and historical payloads. | **PASS** |
| **Test 04** | Source Deletions Record Tombstones | Deleting source file records deletion tombstone in new manifest while past versions survive. | **PASS** |
| **Test 05** | Sync Tombstones Never Erase Backup History | External sync tombstones/deletions never delete historical backup snapshots or stored payloads. | **PASS** |
| **Test 06** | Immutable Manifest Integrity Verification | Cryptographic manifest digest verification detects tampered items or forged metadata. | **PASS** |
| **Test 07** | Active Recovery Locks Prevent Pruning | Active recovery task locks snapshot; retention pruning keeps locked snapshot and its payloads. | **PASS** |
| **Test 08** | Protected Snapshot & Version Immunity | Snapshots with protected items or legal holds remain immune to maxSnapshots / maxAge pruning. | **PASS** |
| **Test 09** | Reference-Counted Garbage Collection | Unreferenced ephemeral payloads are deleted by GC while shared deduplicated payloads survive. | **PASS** |
| **Test 10** | Complete Version Discovery API | Discovers chronological version history across snapshots by path and by `ObjectIdentity`. | **PASS** |
| **Test 11** | Blind Backup Cipher & Target Zero-Knowledge | Target holds only AES-256-GCM ciphertext without keys; client reconstructs with secret key. | **PASS** |
| **Test 12** | Deep Verification Bitrot Detection | Media bitrot or storage tampering detected by storage hash and content hash re-computation. | **PASS** |
| **Test 13** | Deep Verification Decryption Key Validation | Deep audit detects missing or invalid AEAD decryption keys on blind backup repositories. | **PASS** |
| **Test 14** | Restore Staging & Atomic Expose | Data is staged, verified from disk readback, and atomically exposed; staging files cleaned up. | **PASS** |
| **Test 15** | Corrupted Payloads Rejected During Restore | Corrupted payload is rejected during restore and NEVER exposed at final destination. | **PASS** |
| **Test 16** | Restore Policy `FAIL_ON_CONFLICT` | Pre-existing differing destination file halts restore without modifying existing files. | **PASS** |
| **Test 17** | Policy `RESTORE_TO_ALTERNATIVE_PATH` No Collision | Repeated restores generate collision-free unique paths (`.restored.<ts>.<counter>`). | **PASS** |
| **Test 18** | Policy `OVERWRITE_WITH_NEW_VERSION` Advances Sequence | Restoring earlier content generates sequence $N+1$, never rewinding version history. | **PASS** |
| **Test 19** | Interrupted Backup Fails Cleanly | Simulated power/network interruption leaves zero incomplete or corrupt manifests on target. | **PASS** |
| **Test 20** | Persistent `FileBasedBackupTarget` Durability | Actual payloads and manifests persisted to disk survive source wipe and restore bit-for-bit. | **PASS** |

---

## 3. Persistent File-Based Durability Demonstration (Test 20)

Test 20 validates that backup durability does not rely merely on manifest records existing in SQLite, but proves that the underlying protected bytes remain recoverable from real physical disk storage:

1. **Physical Storage:**
   - Initialized `FileBasedBackupTarget` on disk directory `backup_repository_on_disk/`.
   - Backed up `report.pdf` (binary data) and `database/dump.sql` (SQL data).
   - Manifest persisted to `backup_repository_on_disk/manifests/<backupId>.manifest`.
   - Payloads persisted to `backup_repository_on_disk/payloads/<storageHash>.blob`.
2. **Working Tree Destruction:**
   - Completely deleted source directory (`deleteRecursive(src)`).
3. **Cold Process Restart:**
   - Re-instantiated a brand new `FileBasedBackupTarget` and `BackupEngine` pointing to the storage directory.
   - Catalog discovered manifests and indexed stored payloads directly from disk files.
4. **Deep Verification & Restoration:**
   - Executed deep verification: SHA-256 hashes of all payloads on disk matched manifest records.
   - Executed restore into a brand new directory (`restored_fresh_workspace/`).
   - All files recovered bit-for-bit from physical storage blobs.

---

## 4. Cross-Platform Parity Audit

All backup subsystem components were synchronized across:
- `core/src/main/java/org/peerlink/core/backup/`
- `shared-source/canonical/backup/`
- `windows/backup/` & `windows/src/main/java/org/peerlink/core/backup/`
- `linux/backup/` & `linux/src/main/java/org/peerlink/core/backup/`
- `macos/backup/` & `macos/src/main/java/org/peerlink/core/backup/`
- `android/backup/` & `android/src/main/java/org/peerlink/core/backup/`

Verification with `tools/sync-platform-shared/verify-shared.ps1`:
```
==========================================================
 Parity Verification Summary:
 Total Invariant Files Checked: 565
 Total Accidental Drift:        0
 Status: PASS (Zero Accidental Drift; Perfect Invariant Parity)
==========================================================
```

---

## 5. Conclusion

Phase 15 is complete and verified. The versioned backup and restore engine enforces unidirectional historical preservation, immutable snapshot manifests, active operation locks, verified staging prior to exposure, collision-free restore policies, and proven disk durability.