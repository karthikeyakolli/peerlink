# PeerLink Architecture Corrections & Governance Report

**Document**: `docs/development/ARCHITECTURE-CORRECTIONS-REPORT.md`  
**Version**: 1.0.0  
**Date**: October 2026  
**Author**: PeerLink Principal Architect & Documentation Engineer  
**Status**: APPROVED & RECORDED  

---

## Executive Summary

This report documents the architectural corrections applied to [`docs/architecture/PLATFORM-SEPARATED-REPOSITORY.md`](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/architecture/PLATFORM-SEPARATED-REPOSITORY.md) and recorded in [`docs/architecture/PLATFORM-SEPARATED-REPOSITORY-REVISED.md`](file:///c:/Users/WIN_10/.gemini/antigravity/scratch/New%20folder/PeerLink/docs/architecture/PLATFORM-SEPARATED-REPOSITORY-REVISED.md).

All corrections strictly preserve:
1. The **physically separated, self-contained project structure** for `windows/`, `linux/`, `macos/`, and `android/`.
2. The **physical duplication** of common modules inside each OS project without runtime path redirection or symlinks.
3. The **canonical maintenance source** (`shared-source/canonical/`) and automated verification tooling (`verify-shared`).
4. PeerLink's frozen V1 product scope.

---

## Detailed Corrections Register

| # | Category / Issue | Original Concept / Wording | Corrected Concept / Wording | Architectural Rationale | Affected Sections | Code Changes Required? |
|---|---|---|---|---|---|---|
| **1** | **Wire Protocol Definition** | Implied dual wire protocol (Protobuf binary and JSON equivalent formats). | **Protobuf v3 is the exclusive canonical P2P wire protocol**. JSON is used strictly for HTTP REST/control plane, configuration export, and local debugging. | Dual P2P protocols introduce serialization ambiguity, desync, and security audit complexity. P2P message contracts must be strictly binary and type-safe. | Sections 6.1, 6.2, 16 (Inv 1, 2) | No (Codebase is already Protobuf-first via `peerlink-protocol`). |
| **2** | **Data Integrity Hashing** | Stated BLAKE3 was the canonical content integrity algorithm for V1. | **SHA-256 is the frozen canonical algorithm for V1 content and transfer integrity**. BLAKE3 is reserved only as an optional future optimization requiring an ADR. | Cross-platform cryptographic standardization and ubiquitous hardware acceleration across Android/JVM runtimes in V1. | Sections 3.1, 7.1, 16 (Inv 3) | No (Core and Transfer modules already utilize SHA-256). |
| **3** | **Security Model Separation** | Conflated TLS transport, Ed25519 node identity, and XChaCha20 into one combined invariant. | **Three decoupled layers**: (A) Transport Security (TLS 1.3 / QUIC TLS), (B) Device Identity (Ed25519 keypairs, stable Peer ID), (C) Application Payload Protection (E2EE, zero-knowledge relays). | Conflating transport and device identity creates security vulnerabilities where relays or transport certificates are falsely trusted as identity authorities. | Section 8, 16 (Inv 8, 9, 24) | No (Architecture matches current implementation). |
| **4** | **Windows Filesystem Handling** | Listed Transactional NTFS (TxF) / transactional file APIs as core filesystem capability. | **Removed TxF dependency entirely**. Uses standard Win32/Java NIO, file handles/locks, staging files (`.part`), SHA-256 verification, and atomic rename (`MoveFileExW`). NTFS ADS is optional metadata only. | TxF is deprecated by Microsoft and unsupported across non-NTFS volumes. Standard staging + atomic rename + journal recovery provides robust crash safety. | Section 4.1 | No (Staging and atomic rename are already standard in `desktop-node`). |
| **5** | **Android Availability & Power** | Implied battery optimization whitelisting was a mandatory platform integration. | **Battery optimization exemption is strictly optional and user-controlled**. Android operates via platform-approved mechanisms (Foreground Services and WorkManager). Dynamic states: `ACTIVE`, `BACKGROUND_CAPABLE`, `OS_RESTRICTED`, `UNAVAILABLE`. | Mandating battery optimization exemption violates Google Play policies and architectural feasibility; Android cannot be treated as an always-on desktop daemon. | Section 4.4, 16 (Inv 16) | No (Android layer already separates foreground and background tasks). |
| **6** | **Compatibility Scope Split** | Mixed protocol versioning with file/filesystem path compatibility under a generic `compatibility` module. | **Strictly split into two distinct modules**: (1) `protocol-compatibility/` (version, capabilities, bitsets) and (2) `file-compatibility/` (paths, characters, case, verdicts: `COMPATIBLE`, `PARTIALLY_COMPATIBLE`, `INCOMPATIBLE`, `UNKNOWN`, `REQUIRES_USER_DECISION`). | Protocol negotiation concerns network wire frames; file compatibility concerns filesystem semantics, OS limits, and execution safety. | Sections 2, 3.1, 10 | Documentation and topography taxonomy update. |
| **7** | **Recovery Architecture Semantics** | Claimed generic "vault repair and universal transaction rollback" on crash. | **Recovery based on Operation Journal -> Recovery -> Reconciliation -> Resume -> Retry -> User Decision**. Rollback is permitted only for operations with explicit compensatory actions; universal filesystem rollback is rejected. | File system writes across arbitrary OS platforms cannot be magically rolled back after a power loss; crash consistency requires write-ahead logging, staging reconciliation, and resumption. | Section 11, 16 (Inv 18, 23) | No (Aligns with `StartupRecoveryManager` and journal replay). |
| **8** | **Canonical Source Governance** | Defined canonical hub but lacked strict prohibitions against direct platform editing. | **Authoring is strictly permitted in `shared-source/canonical/` only**. Platform copies must never be independently edited or silently become canonical. Cross-platform bugs must be fixed canonically, synchronized, verified, and tested. | Prevents silent divergence and code drift across the 2,500 physically duplicated files. | Section 3.2, 16 (Inv 20, 21) | No (Governed by CI and `verify-shared`). |
| **9** | **Sync & Verification Scope** | Ambiguity regarding whether build outputs, caches, or platform artifacts were part of verification. | **`verify-shared` audits strictly files declared in the shared manifest**. Build outputs (`target/`, `build/`), `.dart_tool/`, logs, and temporary caches are explicitly excluded. | Build artifacts naturally differ per OS compiler and environment; verifying them causes false positives. | Section 15.1, 15.2 | No (`verify-shared` already targets common modules only). |
| **10** | **Shared Networking Contracts** | Networking was shown only as isolated platform code without common session/transport interfaces. | **Added `shared-source/canonical/networking/`** (`transport-api/`, `session-api/`, `connection-model/`, `capability-model/`) duplicated into `{os}/networking/common/`. Platform implementations (`quic/`, `epoll/`, `kqueue/`, `transport/`) implement these shared contracts. | Without common networking contracts, platform nodes cannot share higher-level streaming and session state management. | Sections 2, 3.1, 9.1 | Documentation alignment with `org.peerlink.core.transport` contracts. |
| **11** | **Transport Strategy & Requirements** | Implied Netty and QUIC were required universally across all operating systems. | **PeerLink Transport API -> Capability Negotiation -> Preferred (QUIC/Netty on desktop) -> Fallback (TCP/TLS) -> TURN Relay**. Android uses platform-appropriate stacks (Cronet/OkHttp/Java NIO). Netty/QUIC are not universal. | Netty native epoll/kqueue and desktop QUIC bindings are unsuited for Android mobile constraints. | Section 9.2, 16 (Inv 15) | No (Desktop node uses Netty; mobile can use standard Android networking). |
| **12** | **Flutter Duplication Governance** | Flutter code was noted as duplicated but lacked synchronization rules. | **Canonical Flutter UI is maintained in `shared-source/canonical/flutter/` and synchronized to `{os}/app/flutter/`**. Platform-specific plugins and runners remain isolated. Zero cross-imports. | Ensures consistent UX and state management while maintaining independent platform builds. | Section 14 | No (Matches current repository layout). |
| **13** | **Language Runtime & API Baseline** | Generalized "Java 25 everywhere" across desktop and mobile. | **Desktop uses Java 25 runtime. Portable shared Java code is restricted to Android-compatible API baseline. Android uses Kotlin + Java platform layer and does not require Java 25**. | Android ART runtime does not support desktop Java 25 features or desktop AWT/JNA libraries. | Section 5 | No (Core module is already compiled to Java 17 / Android baseline). |
| **14** | **Supabase Control Plane Role** | Described Supabase without explicit boundaries regarding payload files or desktop SDKs. | **Supabase handles Auth, PostgreSQL metadata, presence, and signaling only. Zero file bytes in Supabase Storage. Realtime is ephemeral coordination, not durable truth. Desktop uses a controlled HTTP/WebSocket adapter**. | PeerLink is a private P2P transfer network; cloud infrastructure must never become a bottleneck or privacy risk for user data. Unofficial Java SDKs introduce fragility. | Section 12, 16 (Inv 12, 13) | No (Matches existing Supabase client implementation). |
| **15** | **Local IPC Security** | Local IPC between Flutter UI and Local Node was undescribed, risking unauthenticated localhost exposure. | **Flutter ↔ Local Node IPC must be explicitly authenticated** using per-installation secrets or tokens and API version handshakes. Localhost is never blindly trusted. | Prevents malicious local processes or browser tabs from hijacking the Local Node transfer engine. | Section 13, 16 (Inv 22) | No (Matches IPC proto and authentication tokens). |
| **16** | **Zero-Drift Scope Clarification** | Claimed "zero-drift bit-exact verification" globally without bounding it to shared source. | **Zero-drift applies strictly to files within the shared synchronized source manifest**. Platform-specific code is intentionally different. | Clarifies the exact operational guarantee of `verify-shared`. | Section 15.2 | No (Tooling behavior confirmed). |
| **17** | **Comprehensive Invariants List** | Had an incomplete list of 4 high-level invariants. | **Expanded to 24 non-negotiable architectural invariants** covering protocols, hashes, identity, authority, cloud boundaries, and platform independence. | Provides unequivocal rules for human maintainers and autonomous agents. | Section 16 (Invariants 1–24) | Architectural specification. |
| **18** | **Preservation of Duplication Architecture** | Potential risk of reverting to monorepo runtime imports. | **Fully preserved the OS-separated structure (`windows/`, `linux/`, `macos/`, `android/`) and physical duplication**. Symlinks and cross-imports remain banned. | Meets user's primary repository organization mandate. | Sections 1, 2, 3 | Architecture verified. |

---

## Internal Consistency Audit

A strict consistency audit was executed across the revised documents:

1. **Java 25 Everywhere?** ➔ **RESOLVED**. Java 25 is scoped strictly to Desktop Node runtimes (Windows, Linux, macOS). Shared Java code is bound to the Android-compatible API baseline; Android Node uses Kotlin/Java under ART.
2. **Netty / QUIC Everywhere?** ➔ **RESOLVED**. Netty 4.2 and QUIC are desktop transport options; Android and other platforms implement the common Transport API using platform-appropriate network stacks.
3. **Dual Wire Protocol (JSON & Protobuf)?** ➔ **RESOLVED**. Protobuf v3 is declared the exclusive P2P wire protocol format. JSON is limited to HTTP REST, diagnostics, and config.
4. **BLAKE3 Canonical Hash?** ➔ **RESOLVED**. SHA-256 is the frozen canonical integrity hash for V1. BLAKE3 is cited only as a potential future optimization.
5. **Transactional NTFS (TxF) Dependency?** ➔ **RESOLVED**. All references to TxF removed. Replaced by file handles/locks, staging, SHA-256 verification, atomic move, and journal replay.
6. **Mandatory Battery Optimization Exemption?** ➔ **RESOLVED**. Removed mandatory exemption. Replaced with platform-approved Foreground Services, WorkManager, and dynamic availability states (`ACTIVE`, `BACKGROUND_CAPABLE`, `OS_RESTRICTED`, `UNAVAILABLE`).
7. **Universal Rollback?** ➔ **RESOLVED**. Universal filesystem rollback explicitly rejected. Replaced with operation journal reconciliation, resume, and retry.
8. **Compatibility Scope Split?** ➔ **RESOLVED**. Divided cleanly into `protocol-compatibility/` and `file-compatibility/`.
9. **Unauthenticated Localhost?** ➔ **RESOLVED**. Authenticated local IPC required with per-installation tokens.

---

## Verification & Status

* **Status**: PASS
* **Corrections Applied**: 18 major architectural corrections
* **Remaining Contradictions**: 0
* **Remaining Issues**: None
