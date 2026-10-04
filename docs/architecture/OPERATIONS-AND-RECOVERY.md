# PeerLink — Operations, Recovery and Commit Semantics

## Operation authority

Every meaningful data mutation is represented as an operation.

```text
operation_id
intent
actor
objects
authorization
preconditions
resource reservation
execution state
outcome
```

## Commit model

```text
INTENT
 -> EXECUTE
 -> VERIFY
 -> COMMIT
 -> FINALIZE
```

For received files, COMMIT means the target mapping is atomically placed into its final authoritative state after required checks.

## Unknown outcome

If the sender loses an acknowledgement after the receiver may already have committed:

```text
OUTCOME_UNKNOWN
 -> reconnect
 -> query operation_id
 -> reconcile
```

Never blindly repeat a destructive operation.

## Crash recovery

On node startup:

1. open/verify SQLite state.
2. inspect incomplete operations.
3. reconcile staging/temp files.
4. reconcile committed object mappings.
5. revalidate resumable work.
6. resume/retry/mark recovery-required according to policy.

## Filesystem truth

Watchers provide hints.

Truth is established by:

- targeted rescan.
- periodic reconciliation.
- verified file metadata/hash where needed.

## Database truth

SQLite is authoritative for operation and index state only within the local database domain. Actual bytes remain filesystem/storage-provider authority.

## Destructive operations

The following require change preview and explicit policy:

- delete.
- replace.
- Exact Mirror.
- conflict resolution that discards a version.
- bulk rename/move.
- restore over existing paths.

## Restore

Restore creates a new logical version rather than rewriting historical versions.
