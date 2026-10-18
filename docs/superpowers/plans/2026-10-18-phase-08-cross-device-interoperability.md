# Phase 8: Cross-Device Interoperability & Backward Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish and verify robust cross-device interoperability and backward compatibility across Android, Desktop (Windows/Linux/macOS), and Flutter UI runtimes, implementing protocol version negotiation, graceful capability degradation, unknown protobuf field preservation, and OS filesystem invariant enforcement per `AGENTS.md` rules.

**Architecture:** 
- **Protocol Compatibility Negotiation:** Portable `ProtocolCompatibilityNegotiator` and `CapabilityRegistry` evaluate mutual protocol versions (major/minor/patch), schema identifiers (`peerlink.v1`), and transport security guarantees, negotiating the highest mutually supported version and degrading gracefully when optional features are missing.
- **Filesystem & Filename Compatibility:** `CompatibilityAnalyzer` implements `docs/compatibility/COMPATIBILITY-FRAMEWORK.md` and `docs/compatibility/OS-FILESYSTEM-RULES.md`, strictly enforcing invariants: Windows reserved names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`) flag `REQUIRES_USER_DECISION` (never silently rename); illegal characters (`< > : " / \ | ? *`) flag `INCOMPATIBLE`; trailing dots/spaces flag `REQUIRES_USER_DECISION`; paths > 260 characters flag `PATH_EXCEEDS_MAX_PATH`; files > 4 GB flag `EXCEEDS_FAT32_LIMIT`; POSIX permissions (`0755`) and symlinks are indexed without silent stripping; inbound binaries (.exe, .elf, .dylib) flag `REQUIRES_USER_DECISION`/`INCOMPATIBLE` and are never auto-executed (Rule 10).
- **Wire Contract & Forward Compatibility:** Protobuf `UnknownFieldSet` preservation guarantees that older or newer nodes forwarding or inspecting messages with future extensions retain unrecognized fields byte-for-byte across serialization cycles without throwing errors.
- **Node & IPC Contract Equivalence:** Verifies parity between Desktop IPC protobuf messages (`InitiateSendRequest`, `PauseTransferRequest`, `ResumeTransferRequest`, `CancelTransferRequest`, `GetNodeStatusRequest`) and native Android Node lifecycle operations.

**Tech Stack:** Java 17/21 / Kotlin (Android Module & Desktop daemon), Dart 3.3+ / Flutter (Mobile & Desktop UI), Google Protocol Buffers (proto3, `com.google.protobuf`), JUnit 4 / AndroidX Test.

**Spec:** `AGENTS.md`, `docs/compatibility/COMPATIBILITY-FRAMEWORK.md`, `docs/compatibility/OS-FILESYSTEM-RULES.md`, `docs/protocol/FOUNDATIONAL-CONTRACTS-SPEC.md`, `docs/protocol/PROTOCOL-AND-CONTRACTS.md`.

## Global Constraints

- Read the relevant specification before modifying code.
- Do not change frozen architecture silently.
- Work in one phase/vertical slice at a time.
- Do not mark a task complete without running the required verification.
- Never place normal user file content in Supabase.
- Never treat discovery as trust.
- Never treat timestamps as sync truth.
- Never treat watcher events as filesystem truth.
- Never blindly replay destructive operations after uncertain outcomes.
- Never auto-execute received files (Rule 10).
- Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
- Never trust localhost merely because it is localhost.
- Never silently rename files matching Windows reserved device names.
- Never silently strip POSIX metadata, extended attributes, or EXIF GPS tags.

## Review Focus

1. **Windows Reserved Device Names (`CON`, `PRN`, `AUX`, `NUL`, etc.)**: Inbound files named `CON.txt` or `aux.dat` received on Windows must trigger `REQUIRES_USER_DECISION` and must never be silently renamed by the receiving node.
2. **Illegal Win32 Filename Characters (`< > : " / \ | ? *`)**: Inbound filenames containing illegal characters must be marked `INCOMPATIBLE`, requiring explicit user rename decision rather than crashing or writing corrupted names.
3. **Protobuf Forward Compatibility (Unknown Field Preservation)**: Wire messages with additional unknown protobuf field tags must be deserialized, held in `UnknownFieldSet`, and re-serialized with zero loss of the unknown payload.
4. **Protocol Version Mismatch & Graceful Rejection**: Mixed-version peers with incompatible major versions (e.g. v2 client connecting to v1 server) must be rejected with machine-readable `ErrorCode` and explanatory text without hanging or dropping connection without explanation.
5. **Missing Required vs Optional Capabilities**: Negotiation must fail when a mandatory capability is missing, but succeed with degraded functionality (reporting `unsupported_features`) when optional capabilities are absent.

---

### Task 1: Port Compatibility Classes to Android Core

**Files:**
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/CompatibilityResult.java`
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/CompatibilityCategory.java`
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/CompatibilityIssue.java`
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/CompatibilityReport.java`
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/CompatibilityAnalyzer.java`
- Create: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/compatibility/ProtocolCompatibilityNegotiator.java`

**Interfaces:**
- Produces: `CompatibilityAnalyzer.analyze(relativePath, sizeBytes, metadataAttributes, targetOs) -> CompatibilityReport`
- Produces: `ProtocolCompatibilityNegotiator.negotiate(remoteMin, remoteMax, remoteSchema, remoteCaps, transportEncrypted) -> ProtocolNegotiationResult`
- Consumes: `CapabilityRegistry`

- [ ] **Step 1: Create compatibility enum, record, and analyzer files in `org.peerlink.core.compatibility`**
  - Implement full 6-category evaluation (`TRANSFER`, `STORAGE`, `OPEN`, `APPLICATION`, `EXECUTION`, `METADATA`).
  - Implement Windows reserved names check (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`).
  - Implement illegal characters check (`< > : " / \ | ? *`).
  - Implement trailing dots/spaces and `MAX_PATH` (> 260 chars) checks.
  - Implement FAT32 4GB volume limit check.
  - Implement metadata preservation for POSIX modes, symlinks, extended attributes, and EXIF GPS tags.
  - Implement binary execution safety checks for PE (.exe/.msi), ELF (.so/.elf), and Mach-O (.dylib/.app).

- [ ] **Step 2: Create `ProtocolCompatibilityNegotiator.java`**
  - Implement mutual version negotiation algorithm: `commonMin = max(localMin, remoteMin)`, `commonMax = min(localMax, remoteMax)`.
  - Validate schema identifier matches `peerlink.v1`.
  - Enforce transport encryption requirement.
  - Filter negotiated capabilities against `CapabilityRegistry.getAllCapabilities()` and ensure all required capabilities are present.

---

### Task 2: Implement Comprehensive JVM Interoperability Test Suite

**Files:**
- Create: `peerlink-android-studio/android/app/src/test/kotlin/org/peerlink/app/AndroidCrossPlatformInteroperabilityTest.kt`

**Interfaces:**
- Tests: `ProtocolCompatibilityNegotiator`, `CompatibilityAnalyzer`, `CapabilityRegistry`, Protobuf `UnknownFieldSet` preservation, Desktop IPC equivalence.

- [ ] **Step 1: Write test suite covering all Phase 8 interoperability requirements**
  - Test 1: Symmetrical protocol version agreement (v1 <-> v1).
  - Test 2: Multi-version range agreement (Local [1..2], Remote [1..1] -> Agrees on v1).
  - Test 3: Major version incompatibility rejection (Local [1..1], Remote [2..3] -> Rejected).
  - Test 4: Unencrypted transport policy rejection.
  - Test 5: Missing required capability rejection with descriptive reason.
  - Test 6: Optional capability negotiation and graceful degradation (`unsupported_features` populated without error).
  - Test 7: Protobuf forward compatibility: Unknown field preservation in wire format roundtrip.
  - Test 8: Windows reserved device name check (`CON.txt`, `PRN`, `AUX.pdf` -> `REQUIRES_USER_DECISION`, never silently renamed).
  - Test 9: Windows illegal character rejection (`< > : " | ? *` -> `INCOMPATIBLE`).
  - Test 10: Trailing dot or space detection (`report. `, `data.` -> `REQUIRES_USER_DECISION`).
  - Test 11: Windows MAX_PATH length constraint (> 260 characters -> `PARTIALLY_COMPATIBLE`).
  - Test 12: FAT32 4GB single file volume limit (> 4 GB -> `PARTIALLY_COMPATIBLE`).
  - Test 13: POSIX metadata and symlink preservation without silent stripping.
  - Test 14: Executable binary reception safety: Inbound `.exe` flags `REQUIRES_USER_DECISION` or `INCOMPATIBLE`, never auto-executed (Rule 10).
  - Test 15: Cross-platform IPC contract equivalence: Protobuf messages serialize and deserialize symmetrically across platforms.

- [ ] **Step 2: Execute JVM unit tests**
  - Run: `$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; .\gradlew.bat :app:testDebugUnitTest`
  - Expected: All tests PASS, bringing JVM test count from 66 to 81.

---

### Task 3: Implement Cross-Platform Flutter Wire & Contract Verification

**Files:**
- Create: `peerlink-android-studio/test/cross_platform_interoperability_test.dart`

**Interfaces:**
- Consumes: Dart generated protobuf classes (`CapabilityNegotiationRequest`, `CapabilityNegotiationResponse`, `ObjectReference`, `OperationRecord`, `UnknownFieldSet`).

- [ ] **Step 1: Write Flutter/Dart cross-platform interoperability test**
  - Verify Dart deserializes and handles `CapabilityNegotiationResponse` with unsupported features gracefully.
  - Verify Dart protobuf parser preserves unknown extension fields in `unknownFields`.
  - Verify path sanitization invariants: paths containing Windows reserved names or illegal characters are detected and never silently renamed.

- [ ] **Step 2: Execute Flutter test suite**
  - Run: `flutter test`
  - Expected: All tests PASS.

---

### Task 4: Documentation and Acceptance Verification Report

**Files:**
- Create: `peerlink-android-studio/docs/reports/phase08_implementation_report.md`
- Create: `docs/reports/phase08_implementation_report.md`

- [ ] **Step 1: Document Phase 8 Implementation Report**
  - Detail protocol version negotiation, capability degradation, Protobuf `UnknownFieldSet` preservation, and filesystem compatibility checks.
  - Document all test results with exact commands, test counts, execution times, and exit codes.
  - Verify and check off all acceptance gates per `AGENTS.md`.
