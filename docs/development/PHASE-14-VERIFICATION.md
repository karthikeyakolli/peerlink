# PeerLink Phase 14 Verification Report: Sync Convergence & Conflict Safety

**Date:** October 13, 2026  
**Status:** PASS (20 of 20 Tests Passed, 100% Assertion Success)  
**Execution Environment:** OpenJDK 25 (Pure Java SE Runtime) on Windows 11  
**Test Suite:** `Phase14StandaloneTestRunner` (`tools/run-phase14-tests.ps1`)

---

## 1. Executive Summary

Phase 14 verifies and hardens PeerLink's distributed synchronization engine to ensure convergent replicas and conflict safety without silent data loss.

Key architectural invariants verified:
1. **Convergence vs Backup**: SYNC maintains convergent replicas via causal vector clocks (`CausalVersion`); it is not a last-modified-wins file copier or one-way backup.
2. **Object Identity vs Content Hash**: `ObjectId` is stable across renames, moves, and edits. Equal content does **not** merge logical objects.
3. **Timestamps as Hints**: Wall-clock timestamps are never used as conflict authority. Causal ancestry alone determines domination, concurrence, and equality.
4. **Watcher Hints vs Startup Scanning**: Filesystem watcher events are hints only. `FilesystemScanner` executes startup and periodic reconciliation to discover missed events and offline modifications.
5. **Tombstone Resurrection Prevention**: Tombstones prevent stale offline copies from resurrecting deleted data when the tombstone's deletion causal version dominates or equals the remote copy's version.
6. **Preservation of Divergent Changes**: Concurrent edits and path collisions are surfaced as explicit conflicts. `KEEP_BOTH` resolution preserves both versions using disambiguated paths (`<path> (conflicted copy <peerId>).<ext>`).
7. **Explicit Mass-Change Policy**: `MassChangePolicy` defines explicit thresholds (50 deletions, 200 changes, 50% extension changes) and programmatic confirmation modes (`REQUIRE_EXPLICIT_CONFIRMATION`, `FAIL_CLOSED`).

---

## 2. Test Execution Summary (20/20 PASS)

| Test ID | Test Scenario | Verified Behavior | Result |
|:---|:---|:---|:---:|
| **Test 01** | Object Identity vs Content Hash | Equal content across files keeps distinct `ObjectId`s; edits preserve stable `ObjectId`. | **PASS** |
| **Test 02** | Causal Lineage & Vector Clocks | Causality verified across `DOMINATES`, `DOMINATED_BY`, `CONCURRENT`, and `EQUAL`. | **PASS** |
| **Test 03** | Simultaneous Concurrent Edits | Independent concurrent edits to same object surface `CONCURRENT_CONTENT_EDIT` conflict. | **PASS** |
| **Test 04** | Offline Divergence Convergence | Peers edit different files while offline; bidirectional sync converges to union of files. | **PASS** |
| **Test 05** | Non-Conflicting Rename / Move | Rename dominates older metadata; path index updates while preserving stable `ObjectId`. | **PASS** |
| **Test 06** | Concurrent Rename Conflict | Both peers rename same object differently -> `CONCURRENT_RENAME` conflict surfaced. | **PASS** |
| **Test 07** | Concurrent Move Conflict | Both peers move object to different destinations -> `CONCURRENT_MOVE` conflict surfaced. | **PASS** |
| **Test 08** | Path Collision Conflict | Different objects created at same path -> `BOTH_CREATED_SAME_PATH` conflict surfaced. | **PASS** |
| **Test 09** | Deletion & Recreation Conflict | Tombstone meets new object created at same path -> `TOMBSTONE_VS_NEW_OBJECT` surfaced. | **PASS** |
| **Test 10** | Tombstone Resurrection Prevention | Stale peer with old copy cannot resurrect deleted file; tombstone propagates to delete stale copy. | **PASS** |
| **Test 11** | Delete vs Modify Conflict | One peer deletes while other peer modifies concurrently -> `DELETE_VS_MODIFY` conflict surfaced. | **PASS** |
| **Test 12** | Legitimate Restore / Recreation | Legitimate restore with dominating causal clock successfully clears tombstone and restores object. | **PASS** |
| **Test 13** | Stale Manifest Reconciliation | Stale peer with outdated manifest syncs with fresh peer without data loss or overwrites. | **PASS** |
| **Test 14** | Interrupted Sync & Idempotency | Re-running sync after interruption or network drop applies 0 duplicate changes and reaches identical state. | **PASS** |
| **Test 15** | Missed Watcher Events Startup Scan | Real files created during downtime are scanned, hashed, and reconciled into manifest. | **PASS** |
| **Test 16** | Duplicate Watcher Deduplication | Duplicate hint notifications do not produce duplicate changes or manifest corruption. | **PASS** |
| **Test 17** | `KEEP_BOTH` Preserves Changes | Conflicted copy preserved at `path (conflicted copy peer).ext` with distinct `ObjectId`. | **PASS** |
| **Test 18** | `KEEP_LOCAL` & `KEEP_REMOTE` | Chosen winner merges and advances causal clock; participating replicas converge on selected version. | **PASS** |
| **Test 19** | Mass-Change Protection Policy | Burst deletions trigger `PAUSED` hold; explicit approval resumes, and rejection fails safely. | **PASS** |
| **Test 20** | Multi-Peer Filesystem Convergence | Two real filesystem directories with independent additions and shared files converge bit-for-bit. | **PASS** |

---

## 3. Real Multi-Peer Filesystem Convergence Demonstration (Test 20)

Test 20 creates two real physical directories on disk (`replica_A` and `replica_B`):
1. **Replica A**: Creates `shared.txt` and `alice_file.txt`.
2. **Replica B**: Creates `shared.txt` and `bob_file.txt`.
3. **Execution**:
   - `FilesystemScanner` scans both directory roots and hashes content.
   - `SyncEngine.reconcileLocalChanges` initializes manifests for `peer-A` and `peer-B`.
   - `peer-A` syncs with `peer-B`'s manifest; `peer-B` syncs with `peer-A`'s manifest.
4. **Outcome**:
   - `Replica A` receives and tracks `bob_file.txt`.
   - `Replica B` receives and tracks `alice_file.txt`.
   - Both manifests converge on the exact same object count, paths, content hashes, and causal lineage.

---

## 4. Cross-Platform Parity Verification

The platform parity audit was executed across all four OS directories (`windows/`, `linux/`, `macos/`, `android/`):
```text
==========================================================
 PeerLink Cross-Platform Parity Verification Tool
 Manifest:          shared-source/PARITY-MANIFEST.json
 Target Platforms:  windows, linux, macos, android
==========================================================
Total Invariant Files Checked: 563
Total Accidental Drift:        0
Status: PASS (Zero Accidental Drift; Perfect Invariant Parity)
==========================================================
```

All 563 invariant files, including `FilesystemScanner.java` and `MassChangePolicy.java`, are physically identical across the four OS project directories.