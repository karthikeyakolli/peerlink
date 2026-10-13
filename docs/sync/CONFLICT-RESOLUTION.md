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
| KEEP_LOCAL | Local version wins; causal clock merges with remote and increments to dominate remote |
| KEEP_REMOTE | Remote version wins; local manifest adopts remote version |
| KEEP_BOTH | Both preserved without data loss; remote copy assigned disambiguated path with new `ObjectId` |
| MERGE | Content merge (text formats, where supported); merged clock advances |
| DEFERRED | Sync paused for this object until user decides; neither file is overwritten |

---

## Disambiguation Naming Scheme (KEEP_BOTH)

When `KEEP_BOTH` is selected or automatically configured:
- Local object remains at its original path (e.g., `documents/report.pdf`).
- Remote version is created with a new `ObjectId` at a disambiguated path:
  `documents/report (conflicted copy <remotePeerId>).pdf`
- For extensionless files:
  `notes (conflicted copy <remotePeerId>)`
- Both files are tracked in the manifest and participate in subsequent sync rounds as independent objects.