# Restore Planning, Dry-Run & Execution

## Conflict Resolution Policies

When restoring historical backups to a destination directory, conflicts may arise if a file already exists locally with differing content. PeerLink provides three deterministic policies:

1. **`OVERWRITE_WITH_NEW_VERSION` (Default):**
   - Restores the file content from the snapshot.
   - **Crucial Rule:** Creates a **NEW current version sequence** (e.g. sequence $N+1$).
   - Never rewinds version history.
2. **`FAIL_ON_CONFLICT`:**
   - Detects all conflicting files during the planning and dry-run phase.
   - Aborts restoration without modifying or overwriting any existing local files.
3. **`RESTORE_TO_ALTERNATIVE_PATH`:**
   - Preserves existing local files intact.
   - Writes restored files to a timestamped alternate path (e.g. `${path}.restored.${timestamp}`).
   - Guarantees collision-free destination resolution across repeated requests by incrementing a monotonic suffix (`${path}.restored.${timestamp}.${counter}`) if the candidate path exists.

## Safe Staging & Atomic Exposure
Restore verifies data **before** exposing it as a completed restored object:
1. **Pre-flight Checks:** Verifies destination directory write permissions and ensures available disk capacity (`getFileStore().getUsableSpace()`) exceeds total restoration size.
2. **Memory Verification:** Verifies storage payload SHA-256 and decrypts AEAD authenticated ciphertext.
3. **Staged Disk Verification:** Writes bytes to a private staging file (`.${file}.part.${uuid}.tmp`), forces write to disk, and reads back the content from disk to verify cryptographic hash equivalence before exposing.
4. **Atomic Expose:** Atomically renames (`ATOMIC_MOVE`) the verified staging file to the target destination. If an error occurs during write or readback, staging files are deleted and corrupt files are never exposed.

## Verification & Reconstructability

Before and after restore, `BackupVerifier` can perform:
- **Shallow Verification:** Validates manifest continuity, manifest digest integrity, and verifies that 100% of referenced storage chunks exist.
- **Deep Verification:** Reads each stored chunk from storage, computes its SHA-256 digest, decrypts AEAD payloads (if blind), and verifies bit-for-bit equivalence with the original unencrypted `ContentHash`.