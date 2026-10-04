# PeerLink Platform Source Duplication & Synchronization Strategy

**Document**: `docs/development/PLATFORM-DUPLICATION-STRATEGY.md`  
**Version**: 1.0.0  
**Phase**: Repository Architecture Transformation  
**Status**: ACTIVE & MANDATORY  
**Audience**: Maintainers, Platform Engineers, SRE, Tooling Developers  

---

## 1. Rationale: Why Physical Duplication?

In distributed, cross-platform engineering, traditional "shared common library" approaches frequently introduce:
1. **Unintended Runtime Coupling**: A change made for one OS unintentionally breaks builds or runtime behavior on another.
2. **Platform Dependency Leakage**: Desktop APIs (e.g., modern Java 25 features or JNA) accidentally slip into Android mobile compilations.
3. **Complex Cross-Project Build Graph**: Building a single platform binary requires invoking monorepo build tools across multiple modules and subdirectories.
4. **Symlink Fragility**: Symlinks and directory junctions break across git checkouts on Windows, CI/CD zip archives, and Docker containers.

By **physically duplicating** the common modules into self-contained operating system projects (`windows/`, `linux/`, `macos/`, `android/`), each platform project functions as an independent, fully buildable software project. A Windows developer can clone and build `windows/` without needing an Android SDK, and an Android developer can build `android/` without needing desktop native build tools.

---

## 2. Canonical Shared Source Hub (`shared-source/canonical/`)

Physical duplication requires a strict mechanism to prevent **code drift**. The canonical source hub serves as the **single source of truth for maintenance**:

* **Location**: `shared-source/canonical/`
* **Role**: Maintenance and synchronization only. The canonical source is **never directly imported at runtime** by any platform build.
* **Scope**: Contains the 14 common modules:
  * `core/`, `protocol/`, `operations/`, `transfer/`, `sync/`, `backup/`, `access/`, `sharing/`, `workspace/`, `clipboard/`, `compatibility/`, `security/`, `recovery/`, `diagnostics/`, and `flutter/`.

---

## 3. Synchronization Tooling & Process (`sync-shared`)

### 3.1 Overview
The synchronization tool (`tools/sync-platform-shared/sync-shared`) copies changes from `shared-source/canonical/` to all four platform projects:

```
                  shared-source/canonical/
                             │
     ┌───────────────┬───────┴───────┬───────────────┐
     ▼               ▼               ▼               ▼
  windows/        linux/          macos/          android/
```

### 3.2 Synchronization Rules
1. **Unidirectional by Default**: Flow is canonical `shared-source/canonical/` ➔ platform copies.
2. **Platform Preservation**: The synchronization tool copies *only* mapped shared modules. Platform-specific directories (`filesystem/`, `os/`, `networking/`, platform runners) are **strictly preserved** and never modified or deleted.
3. **Hash-Based Change Detection**: Files are hashed using SHA-256 to ensure that unchanged files are not re-written (preserving filesystem timestamps).
4. **Dry-Run Support**: Supports `--dry-run` to preview all planned additions, updates, or removals before execution.

---

## 4. Conflict Handling & Drift Resolution

If an engineer inadvertently modifies a duplicated common file directly inside an OS folder (e.g. `windows/core/Object.java`) rather than in `shared-source/canonical/core/Object.java`:

1. **Detection**: `verify-shared` compares the SHA-256 hash of the canonical file against the platform copy and flags a **HASH MISMATCH CONFLICT**.
2. **Resolution Protocol**:
   * If the change is a general bug fix: The engineer must backport the change to `shared-source/canonical/` and execute `sync-shared`.
   * If the change is an OS-specific hack: The change must be removed from the common module and re-implemented inside the platform-specific module (`{os}/os/` or `{os}/filesystem/`).
   * No commit may be merged if `verify-shared` reports conflicts.

---

## 5. Verification Tooling (`verify-shared`)

The verification tool (`tools/sync-platform-shared/verify-shared`) performs strict consistency checks:

1. **Missing File Detection**: Verifies that every file in `shared-source/canonical/{module}` physically exists in `{os}/{module}`.
2. **Modified File Detection**: Compares SHA-256 hashes between canonical and platform copies.
3. **Unexpected File Detection**: Flags common files present in platform projects that have no corresponding canonical source.
4. **Exit Codes**: Returns exit code `0` on 100% synchronization; returns non-zero (`1`) on any discrepancy, blocking CI/CD pipelines.

---

## 6. How to Add a New Operating System Platform

To onboard a new operating system (e.g., `freebsd/` or `ios/`):

1. Create target platform directory: `mkdir -p <platform>/os <platform>/filesystem <platform>/networking <platform>/tests <platform>/scripts`.
2. Register the new platform in `tools/sync-platform-shared/sync-shared.ps1` and `sync-shared.sh`.
3. Run `sync-shared` to populate the 14 common modules into the new platform directory.
4. Implement native bindings in `<platform>/os/` and `<platform>/filesystem/`.
5. Provide `<platform>/README.md` documenting platform build requirements.
6. Execute `verify-shared` to confirm 100% synchronization.
