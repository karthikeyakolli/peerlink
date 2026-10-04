# PeerLink Backup & Restore Architecture

## Overview

The PeerLink Backup & Restore subsystem is intentionally designed as a **unidirectional, versioned preservation system**, strictly distinct from bidirectional synchronization.

### Core Semantics
1. **Unidirectional (Source → Backup Target):**
   - The backup target functions as a receive-only repository by default.
   - The backup target never initiates synchronization or pushes changes back to the source.
2. **Historical Versioning:**
   - Every backup run produces an immutable `BackupManifest` capturing a point-in-time snapshot.
   - Each file entry (`HistoricalVersion`) maintains a monotonic `versionSequence` and stable `ObjectIdentity`.
   - Content deduplication is achieved at the storage layer via cryptographic payload digests (`storageHash`), preventing redundant transfers and duplicate storage across snapshots.
3. **Deletions as Tombstones:**
   - Deletions are captured as explicit deletion records in successor manifests.
   - Deleting a file from the source directory does NOT erase historical versions from past snapshots.
4. **The Cardinal Restore Rule:**
   - **Restore creates a NEW current version. Never rewrite history.**
   - Restoring a file from an older snapshot generates a successor version with a higher sequence number, advancing the causality timeline rather than rewinding it.

```
       ┌───────────────────────┐
       │     Source Peer       │
       │ (Active Working Tree) │
       └──────────┬────────────┘
                  │ Unidirectional Push
                  ▼
       ┌───────────────────────┐
       │     Backup Engine     │
       │ ┌───────────────────┐ │
       │ │ Content / Version │ │
       │ │   Deduplication   │ │
       │ └─────────┬─────────┘ │
       │           │ Encrypt (if blind)
       │           ▼           │
       │ ┌───────────────────┐ │
       │ │ Manifest Builder  │ │
       │ └─────────┬─────────┘ │
       └───────────┼───────────┘
                   │
                   ▼ Receive-Only Storage
       ┌───────────────────────┐
       │     Backup Target     │
       │ ┌───────────────────┐ │
       │ │ Manifest Catalog  │ │
       │ ├───────────────────┤ │
       │ │ Payload Store     │ │
       │ │ (Plain / Cipher)  │ │
       │ └───────────────────┘ │
       └───────────────────────┘
```