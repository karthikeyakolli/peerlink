# PeerLink Final Security Hardening Review

**Document Version**: 1.0  
**Phase**: 19 (Production Hardening)  
**Security Classification**: CONFIDENTIAL & DEFENSIVE DESIGN  
**Status**: APPROVED

---

## 1. Malware Scanner Defensive Posture

### 1.1 Non-Permissive Failure Invariant
In standard consumer software, malware scanning failures are frequently treated as non-fatal warnings, or defaulted to `CLEAN` to prevent user annoyance. In PeerLink, this is **strictly forbidden**.

```
Inbound Payload
      ↓
Malware Scanner Provider (ClamAV / Windows Defender / Simulated)
      ↓
[Failure / Timeout / Exception / Disconnect]
      ↓
SecurityVerdict = SCAN_FAILED (NEVER CLEAN)
      ↓
Payload Quarantined Immediately (`.peerlink_quarantine/`)
      ↓
User Alerted with Structured Diagnostic Report
```

- Any timeout (>30 seconds), pipe broken error, out-of-memory exception, or unhandled scanner error is caught by `InboundSafetyPipeline` and forced to `SecurityVerdict.SECURITY_VERDICT_SCAN_FAILED`.
- Unscannable files are never placed into the user's workspace or target directory without explicit administrative override.

### 1.2 Scan Cache Version Invalidation
- Cached verdicts in `ScanCache` record the scanner engine version (`scannerVersion`).
- When antivirus definitions or scanner engines update, `ScanCache.invalidateByScannerVersion(...)` purges all previous entries, preventing cache poisoning from outdated signatures.

---

## 2. Archive Safety & Decompression Bomb Defense

### 2.1 Nested Archive Inspection
Archive bombs often nest compressed files within multiple layers of zip/tar archives to bypass simple size-ratio checks.

`ArchiveSafetyInspector` implements recursive inspection:
- **Maximum Recursion Depth**: 3 levels.
- **Maximum Uncompressed Size**: 10 GB cumulative uncompressed size.
- **Maximum Compression Ratio**: 100:1. Any archive exceeding this ratio is flagged as `SECURITY_VERDICT_QUARANTINED` with reason `ZIP_BOMB`.
- **Path Sanitization**: Every entry within an archive must satisfy `PathSandboxValidator`. Any entry containing `../` or absolute drive roots is rejected.

---

## 3. Privacy-Preserving Diagnostics & Secret Redaction

PeerLink diagnostics are designed to be safe for inclusion in customer support tickets or bug reports without risking credential compromise:

1. **Private Keys**:
   - Matches standard PEM private key headers (`-----BEGIN ... PRIVATE KEY-----`).
   - Immediately replaced with `[REDACTED_PRIVATE_KEY]`.
2. **Auth Tokens & Credentials**:
   - Any key in the diagnostic dictionary matching `(?i).*(password|secret|token|bearer|credential|private_?key|auth).*` has its corresponding value redacted to `[REDACTED]`.
   - String values matching token patterns (`token=...`, `bearer ...`) are scrubbed by `SECRET_PATTERN`.
3. **Local Filesystem Privacy**:
   - Diagnostic reports provide relative paths or hash identifiers rather than sensitive host usernames where possible.

---

## 4. Emergency Stop (`STOP ALL PEERLINK ACTIVITY`)

The `EmergencyStopManager` provides a panic button for security incidents:

- **Atomic Halt**:
  - Immediately aborts all active transfer threads.
  - Pauses all continuous synchronization loops.
  - Cancels backup snapshots.
  - Halts clipboard monitoring and sharing engines.
- **New Operations Prohibited**:
  - Any request dispatched to the local node while emergency stop is active throws `IllegalStateException`.
- **Zero Data Corruption**:
  - Files in `.peerlink_staging/` remain isolated and safely recoverable.
  - Authoritative operation journal records transition to `PAUSED` or `ABORTED_SAFELY`.

---

## 5. Relay & Transport Boundary Controls

- All P2P traffic over direct TCP/TLS or QUIC requires mutual TLS or Noise protocol handshake authenticated by ed25519 peer identity keys.
- When traversing TURN relays, all relay frames carry end-to-end encrypted payloads. The TURN relay server cannot inspect file contents, metadata, or token secrets.
- In production, static TURN credentials are replaced by short-lived HMAC time-window tokens generated via the Supabase control plane.
