# PeerLink Inbound Safety & Malware Scanning Pipeline

## Objective

Add file-safety scanning without turning PeerLink into an antivirus product.

## Pipeline Architecture

All inbound files flow through a strict 6-stage lifecycle before reaching the user's filesystem:

```
 Inbound Payload
       │
       ▼
 [1. Receive & Stage]  ──► Isolated Quarantine Directory (.stage)
       │
       ▼
 [2. Integrity Check]  ──► Verify SHA-256 matches expected ContentHash
       │                    (Mismatch: Immediate deletion & failure)
       ▼
 [3. File Safety]      ──► Archive inspection (bomb defense, traversal)
       │                   Executable inspection (MZ/ELF header detection)
       ▼
 [4. Malware Scan]     ──► ScannerProvider (Defender, ClamAV, etc.)
       │                   ScanCache consulted via ContentHash
       ▼
 [5. Policy Decision]  ──► ScanPolicy (Strict / Standard)
       │                    CLEAN        -> PERMIT_COMMIT
       │                    MALICIOUS    -> REJECT_AND_DELETE
       │                    SUSPICIOUS   -> HOLD_IN_QUARANTINE_FOR_DECISION
       │                    UNAVAILABLE  -> HOLD_IN_QUARANTINE_FOR_DECISION
       ▼
 [6. Commit to Target] ──► Atomic move to destination folder
```

## Critical Invariants

1. **Never claim "safe" when scanner is unavailable:**
   - If the host antimalware daemon is stopped, uninstalled, or inaccessible, the scan verdict is strictly `UNAVAILABLE` or `UNKNOWN`.
   - Inbound files are held in quarantine pending explicit user confirmation; they are never silently admitted.
2. **Never silently execute:**
   - Inbound executables are identified via file header inspection (magic bytes) regardless of extension and flagged for user decision.
3. **Never silently rename, convert, delete, or strip metadata:**
   - Security and compatibility findings prompt explicit user actions.