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