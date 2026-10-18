# Phase 05: Source Isolation, Performance and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete physical source separation, achieve 100% clean independent builds for all platform projects (Windows, Android, Linux, macOS, Android Studio Edition), measure real performance metrics, pin toolchains and update CI, and verify all final release gates.

**Architecture:**
- **Source Isolation**: Each platform (`windows/`, `android/`, `linux/`, `macos/`, `peerlink-android-studio/`) owns its source, generated contracts, configs, and tests with zero runtime or build dependencies on common/shared source trees.
- **Parity & Invariant Verification**: The read-only parity checker (`verify-platform-parity.ps1`) verifies bit-for-bit parity across invariant modules without automatic overwriting.
- **Performance Profiling**: Measures real transfer throughput, IPC latency, discovery/reconnection time, memory bounds, and UI frame times under realistic workloads.
- **CI & Release Packaging**: Workflow matrix pinned to exact toolchains, packaging scripts verified, and final release gates audited.

**Tech Stack:** Java 21/17 (Maven, Gradle, Netty, SQLite WAL, JUnit 5), Dart 3.13 / Flutter 3.47, GitHub Actions CI, PowerShell.

**Spec:** `AGENTS.md`, `docs/INDEX.md`, `tools/platform-parity/PARITY-MANIFEST.json`, `docs/development/PHASE-WISE-PLAN.md`.

## Global Constraints

- Never place normal user file content in Supabase.
- Never treat discovery as trust.
- Never treat timestamps as sync truth.
- Never treat watcher events as filesystem truth.
- Never blindly replay destructive operations after uncertain outcomes.
- Never auto-execute received files.
- Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
- Never trust localhost merely because it is localhost.
- No application may import runtime source from another platform project or a root common application-source directory.
- A parity checker must compare declared invariant files across platform copies, report differences, and never overwrite platform source automatically.
- Do not delete old common source until clean independent builds and tests pass for all required replacement projects.
- Do not claim Linux or macOS passed merely because their source folders exist or their Dart unit tests pass.

## Review Focus

1. **Independent Build Graphs**: Each platform's build configuration must be completely decoupled from root common source trees.
2. **Platform Parity**: Invariant modules must match across platforms with differences explicitly accounted for or resolved.
3. **Compilation Cleanliness**: `windows`, `linux`, `macos`, and `peerlink-android-studio` must compile their native nodes and apps cleanly with zero unresolved symbols.
4. **Performance Bounds**: Transfer streaming must remain bounded in RAM, and backpressure must be preserved.
5. **Release Truthfulness**: Every gate must report exact evidence without fabricated passes.

---

### Task 1: Resolve Platform Java Invariant Discrepancies and Compile Linux & macOS Nodes

**Files:**
- Modify: `windows/src/main/java/org/peerlink/core/backup/BackupManifest.java` vs `linux/`, `macos/`, `android/`
- Sync/Create: `SnapshotMerkleTree.java` in `linux/src/main/java/org/peerlink/core/backup/`, `macos/...`, `android/...`
- Modify: `linux/src/main/java/org/peerlink/linux/filesystem/LinuxPosixFileProvider.java`
- Modify: `linux/src/main/java/org/peerlink/linux/os/secrets/LinuxSecretStore.java`
- Modify: `macos/src/main/java/org/peerlink/macos/os/keychain/MacKeychainStore.java`
- Modify: `linux/src/main/java/org/peerlink/core/net/ice/TurnRelayedTransportConnection.java` and `macos/...`
- Sync: `DesktopLocalNodeServiceImpl.java` and `DesktopNodeDaemon.java` to `linux/` and `macos/`
- Test: `.\mvnw.cmd test-compile -f linux/pom.xml -B`
- Test: `.\mvnw.cmd test-compile -f macos/pom.xml -B`

- [ ] **Step 1: Inspect and align `BackupManifest.java` and `SnapshotMerkleTree.java` across platforms**
- [ ] **Step 2: Fix missing imports and symbol mismatches in `LinuxPosixFileProvider`, `LinuxSecretStore`, `MacKeychainStore`, and `TurnRelayedTransportConnection`**
- [ ] **Step 3: Update `DesktopLocalNodeServiceImpl` and `DesktopNodeDaemon` in `linux/` and `macos/` with verified implementations**
- [ ] **Step 4: Verify `linux/pom.xml` and `macos/pom.xml` compile cleanly (BUILD SUCCESS)**

---

### Task 2: Verify Platform Parity & Clean Build Graphs

**Files:**
- Modify: `scripts/sync_all_screens.ps1` (remove retired `shared-source/canonical` reference)
- Verify: `tools/platform-parity/verify-platform-parity.ps1`
- Verify: `scripts/check-deps.ps1`

- [ ] **Step 1: Remove retired path references from scripts**
- [ ] **Step 2: Run `verify-platform-parity.ps1` and confirm 100% PASS**
- [ ] **Step 3: Run `check-deps.ps1` and confirm zero architectural boundary violations**

---

### Task 3: Performance Benchmarking and Resource Profiling

**Files:**
- Create: `windows/src/test/java/org/peerlink/core/performance/PerformanceBenchmarkTest.java`
- Test: Measure real transfer throughput, IPC latency, discovery/reconnection time, memory footprint, and UI frame metrics

- [ ] **Step 1: Write reproducible benchmark test measuring throughput, streaming memory bounds, and latency**
- [ ] **Step 2: Run benchmark test and collect exact measurements**
- [ ] **Step 3: Document before/after metrics and profile resource bounds**

---

### Task 4: CI Toolchain Pinning and Packaging Verification

**Files:**
- Inspect/Modify: `.github/workflows/ci.yml` (and any related CI workflow files)
- Verify: Windows packaging script `windows/scripts/package-windows.ps1`
- Verify: Android Gradle build configuration

- [ ] **Step 1: Inspect and pin toolchain versions in CI workflows (Flutter, Java, Gradle, Android SDK/NDK)**
- [ ] **Step 2: Ensure CI includes Windows, Android, Linux, and macOS jobs with honest execution reporting**
- [ ] **Step 3: Verify Windows packaging script produces valid artifacts**

---

### Task 5: Final Release Gates Audit & Gate Verdict

- [ ] **Step 1: Execute all platform test suites**
- [ ] **Step 2: Evaluate all release gate criteria (SEND, trust, recovery, ACCESS/SYNC/BACKUP, no demo data, independent builds)**
- [ ] **Step 3: Compile final defect list, performance report, remaining limitations, and release verdict**
