# PeerLink Sync Engine Architecture

## Core Design Rules

1. **Timestamps are hints, not conflict authority** — CausalVersion (vector clock) determines ordering.
2. **Watcher events are hints** — always verified via reconciliation; periodic scan always runs.
3. **objectId != contentHash** — equal content does NOT merge logical objects.
4. **Deletions use tombstones** — GC only after safe convergence.
5. **Restore creates a new version** — does NOT undo the tombstone.
6. **Local cache deletion != source deletion** — requires separate authorization.
7. **File locking is advisory** — correctness comes from version/causality.

## Sync Modes

| Mode | Directionality |
|---|---|
| BIDIRECTIONAL | Both ways; conflicts surfaced |
| ONE_WAY_REPLICATION | Source to destination only |
| RECEIVE_ONLY_IMPORT | Local never pushes |
| EXACT_MIRROR | Destructive mirror; requires confirmation |

## Convergence via Vector Clock

| Local vs Remote | Relation | Action |
|---|---|---|
| Local: [A:2,B:0] Remote: [A:0,B:2] | CONCURRENT | Conflict — user must resolve |
| Local: [A:2,B:1] Remote: [A:1,B:1] | DOMINATES | Local wins; apply local |
| Local: [A:1,B:1] Remote: [A:2,B:1] | DOMINATED_BY | Remote wins; apply remote |
| Local: [A:1,B:1] Remote: [A:1,B:1] | EQUAL | No action |

## Session Phases

INITIALIZING -> SCANNING -> RECONCILING -> CONFLICT_RESOLUTION -> APPLYING -> COMPLETED
                                                    |
                                               PAUSED (mass-change)
                                                    |
                                             RECONCILING (on resume)

---

## Tombstone Resurrection Prevention

- When a remote object is presented during sync, the local manifest checks for an existing `Tombstone` for that `objectId`.
- If a tombstone exists and its `deletionCausalVersion` dominates or equals the remote object's version, the remote object is recognized as **stale** and rejected from resurrection.
- The tombstone is propagated back to delete the stale remote copy.
- If the remote object's version strictly dominates the tombstone, the object was legitimately recreated or restored on the remote node and is accepted as a new content version.
- If the tombstone and remote object are concurrent, a `DELETE_VS_MODIFY` conflict is surfaced to prevent silent data loss.

---

## Filesystem Scanner & Watcher Reconciliation

- Filesystem watcher events are treated as **hints**, never authoritative truth.
- `FilesystemScanner` executes startup and periodic scans walking the sync directory tree.
- Missed notifications (due to dropped OS buffers or offline file edits) are detected during the SCANNING phase.
- Detected changes (`CREATED`, `CONTENT_MODIFIED`, `METADATA_CHANGED`, `DELETED`) are reconciled into the manifest before remote reconciliation.
- Rename and move operations correlate disappeared entries with newly appeared entries matching the content hash, preserving the stable `ObjectId` and its causal lineage.