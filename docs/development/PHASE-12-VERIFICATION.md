# PHASE 12 - SYNCHRONIZATION ENGINE: Verification

## PASS Criterion

Independent peers converge according to the defined causality rules
without silently losing concurrent changes.

## Test Coverage (21 scenarios in SyncEngineTest.java)

1.  Independent offline changes (different files)       - Completed, 0 conflicts
2.  Concurrent edits same file                          - CONCURRENT_CONTENT_EDIT conflict
3.  Non-conflicting rename (dominating version)         - 0 conflicts, applied
4.  Concurrent rename by both peers                     - CONCURRENT_RENAME conflict
5.  Delete vs modify (tombstone vs active)              - DELETE_VS_MODIFY conflict
6.  Duplicate content (same hash, diff objectId)        - 2 objects, NOT merged
7.  Tombstone survives until GC-safe                    - Refuses early GC
8.  Restore creates new version, not undo tombstone     - Higher cv.sequence
9.  Watcher hint flagged for verification               - requiresVerification=true
10. Selective sync excludes *.tmp and node_modules      - Exclusions enforced
11. Sync dry-run reports intent without applying        - Result produced, no apply
12. Mass deletion triggers protection                   - triggered=true
13. Mass extension change (ransomware-style)            - triggered=true
14. Mass-change hold pause and resume lifecycle         - PAUSED -> RECONCILING
15. Network disconnect: remote manifest absent          - FAILED gracefully
16. Conflict resolution KEEP_LOCAL                      - resolved=true
17. Vector clock causal ordering correctness            - All 4 relations correct
18. One-way replication receives only                   - wouldSendToRemote=0
19. Receive-only import never sends                     - wouldSendToRemote=0
20. Huge dataset (2000 objects)                         - Completed, 0 conflicts
21. Legitimate remote catch-up not blocked              - Not PAUSED

## Implementation Invariants

- Timestamps are NOT conflict authority (only CausalVersion)
- Watcher events are hints (periodic reconciliation always required)
- objectId != contentHash (equal content does not merge logical objects)
- Deletions use tombstones (never silently removed)
- Tombstone GC requires safe convergence
- Restore creates new version (does not undo tombstone)
- Cache deletion != source deletion (separate authorization required)
- File locking is advisory (correctness from causality)
- Mass-change protection preserves versions; requires explicit resume