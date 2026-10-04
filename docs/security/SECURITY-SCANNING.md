# PeerLink — File Safety and Malware Scanning

## 1. Purpose

PeerLink orchestrates file-safety checks; it is **not a replacement antivirus product**.

## 2. Incoming pipeline

```text
Receive
 -> Quarantine/Staging
 -> Integrity verification
 -> File-type/signature inspection
 -> Malware scanner
 -> Policy evaluation
 -> Compatibility/privacy checks
 -> Commit
```

Persistent files should not become user-visible trusted content before the required verification stages complete.

## 3. Scanner abstraction

```text
ScannerProvider
 - scan(path/handle)
 - scan(stream)
 - availability
 - engine version
 - signature version
 - capabilities
```

Provider examples:

- Windows Defender adapter
- ClamAV adapter
- future platform/scanner adapters

## 4. Verdicts

```text
CLEAN
SUSPICIOUS
MALICIOUS
UNKNOWN
SCAN_FAILED
UNAVAILABLE
```

`UNAVAILABLE` must never be displayed as `CLEAN`.

## 5. Policies

A configurable policy can determine behavior when scanning is unavailable:

- STRICT — block/unavailable
- BALANCED — receive to restricted/quarantine state with warning
- OPEN — allow with explicit warning, subject to file-type restrictions

Default policy should be conservative for executables and archives.

## 6. Archive safety

Inspecting archives must enforce resource limits:

- maximum nesting depth
- maximum extracted bytes
- maximum file count
- maximum scan time
- maximum compression ratio
- safe extraction paths

Do not allow archive traversal outside the staging directory.

## 7. Executables

- Never automatically execute received files.
- Preserve signature information where available.
- Report unsigned/unknown publisher status separately from malware verdict.
- Metadata-only handling is the default for execution-capable content.

## 8. Scan cache

A clean result may be reused only under explicit cache policy, keyed at least by:

- content hash
- scanner identity
- engine version
- signature/database version
- scan policy version

## 9. Rescan

Risk-sensitive files can be rescanned when scanner intelligence changes.

## 10. Privacy

Do not upload user file contents to the central control plane merely for scanning. Prefer local/platform scanners or an explicitly configured trusted security service.

## 11. Distinction from PeerLink security

| Security layer | Purpose |
|---|---|
| Device identity | Who is the device? |
| Trust | Do we recognize/trust that identity? |
| Authorization | Is this operation allowed? |
| Transport security | Is the session protected? |
| Integrity verification | Did the bytes arrive intact? |
| Malware scanning | Does an installed scanner detect a threat? |
| Compatibility | Can the target safely store/open/use it? |

No layer should be confused with another.
