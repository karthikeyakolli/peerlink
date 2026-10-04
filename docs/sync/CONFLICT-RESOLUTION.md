# Sync Conflict Resolution

Conflicts arise when two peers have CONCURRENT causal versions of the same object.
Timestamps are never used as tiebreakers.

## Conflict Types

| Type | Cause |
|---|---|
| CONCURRENT_CONTENT_EDIT | Both peers edited same file independently |
| DELETE_VS_MODIFY | One deleted, other modified concurrently |
| CONCURRENT_RENAME | Both renamed same object differently |
| CONCURRENT_MOVE | Both moved object to different locations |
| BOTH_CREATED_SAME_PATH | Different objects created at same path |
| TOMBSTONE_VS_NEW_OBJECT | Tombstone meets new object at same path |

## Resolution Options

| Option | Behaviour |
|---|---|
| KEEP_LOCAL | Local version wins |
| KEEP_REMOTE | Remote version wins |
| KEEP_BOTH | Both preserved with disambiguation suffix |
| MERGE | Content merge (text formats, where supported) |
| DEFERRED | Sync paused for this object until user decides |