# PeerLink Release Engineering: Update System & Rollback Protection

## 1. Update Architecture

PeerLink updates protect local SQLite state, pending transfers, and cryptographic identity keys through a multi-stage transactional pipeline:

```
[1. Download Package]
        │
        ▼
[2. Signature Verification] (Ed25519 / Authenticode / Notary)
        │
        ▼
[3. Integrity Check] (SHA-256 Manifest match)
        │
        ▼
[4. Compatibility Check] (min_supported_protocol <= peerlink.v1)
        │
        ▼
[5. Migration Dry-Run] (Execute schema migrations against temporary copy)
        │
        ▼
[6. State Snapshot] (Atomic copy of peerlink_local.db & device identity)
        │
        ▼
[7. Binary Swap] (Replace runtime JAR / binaries via staged rename)
        │
        ▼
[8. Post-Update Health Check] (Local Node starts on ephemeral IPC port)
        │
   ┌────┴───────────────────────────┐
   ▼                                ▼
[SUCCESS]                        [FAILURE]
Finalize and launch              Atomic rollback of binaries & DB snapshot
```

---

## 2. Step-by-Step Update Verification

### Stage 1: Signature & Integrity
- Updates are distributed with an accompanying detached cryptographic signature (`update.tar.gz.sig` or `update.zip.sig`).
- The update engine verifies the signature against the embedded release public key (Ed25519).
- SHA-256 hash of the payload is verified against the signed release manifest. Any mismatch aborts immediately without modifying disk state.

### Stage 2: Compatibility & Protocol Gates
- Manifest contains:
  - `application_version`: target version
  - `protocol_version`: wire format (e.g. `1.0.0`)
  - `min_supported_protocol`: backward compatibility lower bound
- If `min_supported_protocol > local_supported_protocol`, the update displays a compatibility migration warning and prevents broken partial installs.

### Stage 3: Schema Migration Dry-Run
- Before the live database is touched, the update engine:
  1. Copies `peerlink_local.db` to a temporary directory.
  2. Runs `DatabaseMigrationManager.migrate(tempConnection)` up to target schema version.
  3. Validates foreign keys and table integrity (`PRAGMA integrity_check`).
  4. If any migration step throws an exception, the update aborts before live production tables are altered.

### Stage 4: Snapshot & Rollback Recovery
- **Snapshot Creation:** An atomic backup snapshot `peerlink_local.db.pre-update-<timestamp>` is created.
- **Binary Swap:** Old executable jar is renamed to `.bak`, new jar is moved into `lib/`.
- **Health Check:**
  - Launch Local Node daemon in test mode: `java -jar lib/peerlink-desktop-node.jar --port 0 --dry-run-check`
  - Ensure daemon boots, runs startup recovery without errors, and signals readiness within 15 seconds.
- **Rollback Trigger:** If the daemon fails to launch, exits with non-zero code, or fails gRPC IPC handshake:
  1. Restore `.bak` binaries.
  2. Restore database from pre-update snapshot.
  3. Log incident to `logs/update-failure.log`.
  4. Alert user via UI Problems Center.
