# Retention Policy & Garbage Collection

## Policy Evaluation

Retention policies in PeerLink govern the lifecycle of backup snapshots. The policy defines rules for retaining and pruning manifests:
- `maxSnapshots`: Retain the latest $N$ snapshots.
- `maxAgeMs`: Retain snapshots newer than a specified duration.
- GFS rules: Retain daily, weekly, and monthly baselines.

## Protected Versions: The Immunity Rule

> **CRITICAL INVARIANT:**  
> Any snapshot marked as protected, or any snapshot containing items explicitly protected (e.g., legal hold, designated milestone), is **STRICTLY IMMUNE** to retention pruning.

Even when `maxSnapshots` is exceeded or age thresholds expire, protected snapshots remain pinned and are never deleted during retention evaluation.

## Version Garbage Collection (`VersionGarbageCollector`)

When older manifests are pruned, payload chunks are reclaimed through a reference-counted garbage collection pass:
1. **Manifest Deletion:** Pruned manifests are deleted from the `BackupTarget`.
2. **Reference Enumeration:** The GC scans all surviving manifests across the target repository and builds the complete set of actively referenced `storageHash` payloads.
3. **Payload Pruning:** Any stored payload whose hash is unreferenced by all remaining manifests is permanently deleted.
4. **Safety Guarantee:** Shared payloads (deduplicated files present in multiple snapshots) are safely preserved as long as at least one surviving manifest references them.