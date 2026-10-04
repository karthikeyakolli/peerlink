# PeerLink — Contradictions and Constraints Audit

This file records contradictions found during stack and feature review and the final resolution.

## C-001 — Java 25 everywhere

**Problem:** Desktop Java 25 cannot be assumed to be the runtime baseline for Android.

**Resolution:**

- Desktop Local Node/runtime: Java 25.
- Shared JVM core: compile to a deliberately portable Java baseline compatible with Android requirements.
- Android-specific code: Kotlin/Java Android runtime.

## C-002 — Netty/QUIC everywhere

**Problem:** Netty QUIC relies on platform/native components and should not be forced onto Android/future platforms.

**Resolution:** `PeerLinkTransport` is an abstraction. Desktop may use Netty/QUIC; other clients may use platform-native transports. PeerLink protocol semantics remain unchanged.

## C-003 — gRPC everywhere

**Problem:** gRPC Java Netty transport is not the correct Android model.

**Resolution:**

- Desktop Flutter ↔ Java Node: gRPC + Protobuf.
- Android Flutter ↔ native layer: Pigeon/platform APIs.
- gRPC remains a local desktop IPC option, not a universal PeerLink data transport.

## C-004 — Realtime as reliable command delivery

**Problem:** Realtime is transient messaging and has plan/throughput/payload constraints.

**Resolution:** Realtime is used for wakeup, presence and coordination. Durable operations are persisted and reconciled through authoritative state.

## C-005 — Always-online Android

**Problem:** Android background execution is OS-controlled and restricted.

**Resolution:** Android is a full node with explicit availability/capability states. User-initiated long transfers use Android's supported data-transfer mechanisms; scheduled/background work is subject to platform constraints.

## C-006 — One filesystem model everywhere

**Problem:** Windows, Linux, macOS and Android have different filesystem/permission semantics.

**Resolution:** `PeerFileProvider`/filesystem abstraction with per-platform implementations. Object identity is independent of physical path/URI.

## C-007 — Flutter as the authoritative backend

**Problem:** UI lifecycle must not control operation truth.

**Resolution:** Flutter calls the Local Node/application API. The node owns operation, security, filesystem and recovery semantics.

## C-008 — Localhost is trusted

**Problem:** Another local process could potentially attempt to access a Local Node IPC port.

**Resolution:** authenticate local IPC; localhost is a transport location, not a trust decision.

## C-009 — Supabase identity equals PeerLink device identity

**Problem:** account credentials and device cryptographic identity have different lifecycles and security purposes.

**Resolution:** maintain separate account identity and device identity; bind them explicitly through authenticated enrollment.

## C-010 — TURN is a privacy/security authority

**Problem:** a relay can see traffic metadata and traffic volume even if it cannot see encrypted application content.

**Resolution:** application payload is end-to-end encrypted. Relay is transport infrastructure only. Relay usage is visible to policy/UI.

## C-011 — Backup behaves like sync

**Problem:** bidirectional sync can propagate unwanted changes; backup should preserve history.

**Resolution:** backup is protected/versioned/receive-only by default. Exact Mirror is a separate destructive mode.

## C-012 — Hash identifies object

**Problem:** two logically different files can have the same content and one logical file can have many versions.

**Resolution:** `object_id != content_hash` and version identity is separate.

## C-013 — Watch event equals truth

**Problem:** file watcher events can be missed/coalesced.

**Resolution:** watchers are hints; debounce + targeted rescan + periodic reconciliation provide truth.

## C-014 — Timestamp decides conflict

**Problem:** clocks drift and timestamps do not express causality.

**Resolution:** causal/version metadata determines precedence. Timestamps are metadata only.

## C-015 — Malware scanner available everywhere

**Problem:** scanner engines vary by OS and installation.

**Resolution:** scanner-provider abstraction with explicit `UNAVAILABLE`/`UNKNOWN` outcomes and policy-controlled behavior.

## C-016 — One transport fallback chain

**Problem:** TURN behavior depends on transport/protocol. QUIC-over-TURN-UDP and TCP/TLS-over-TURN are different paths.

**Resolution:** transport manager negotiates a concrete candidate/path; it does not blindly treat all relays as interchangeable.

## C-017 — Browser guest sharing makes PeerLink a web app

**Problem:** guest web receive/share could blur product boundaries.

**Resolution:** guest web capability is optional, scoped and temporary. It does not become the normal storage/data plane.

## C-018 — iOS shares the Java runtime core

**Problem:** iOS does not provide a JVM runtime suitable for shipping the desktop Java engine.

**Resolution:** iOS will reuse protocol/contracts and reimplement platform/core services as needed. The protocol, not Java bytecode, is the portability guarantee.

## C-019 — AI can perform operations directly

**Problem:** natural-language models can hallucinate, be manipulated, or misunderstand current state.

**Resolution:** AI only proposes structured intent. Deterministic policy, authorization, resource checks, operation journal and current-state validation remain authoritative.
