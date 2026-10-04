# OS Filesystem Invariants & Filename Rules

## Windows Filesystem Invariants
- **Reserved Names:** `CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`.
  - Inbound files matching these names (e.g. `CON.txt`) flag `REQUIRES_USER_DECISION`.
  - PeerLink **never silently renames** the file.
- **Illegal Characters:** `< > : " / \ | ? *`.
  - Flagged as `INCOMPATIBLE`.
- **Trailing Characters:** Disallows trailing dots and spaces.
- **Path Length:** Paths exceeding 260 characters flag `PATH_EXCEEDS_MAX_PATH`.

## POSIX Metadata Mapping
- POSIX permissions (`chmod 0755`) and symlinks received on Windows targets are indexed in metadata and preserved without silent stripping.