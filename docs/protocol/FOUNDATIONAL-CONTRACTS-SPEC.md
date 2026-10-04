# PeerLink Foundational Protocol Contracts Specification (v1)

## 1. Architectural Scope & Principles

This specification defines the neutral, platform-independent wire contract for PeerLink Phase 02. The contracts are defined in Google Protocol Buffers (`proto3`) and compiled to native Java, Dart, and Kotlin environments.

### Core Protocol Design Rules
1. **Never Encode OS-Specific Filesystem Paths as Object Identity:**
   - Identity is represented strictly by a globally unique `ObjectId` (UUID v4 / durable token).
   - Display labels or user-visible names are encapsulated in `logical_name`. Physical filesystem paths (`C:\Users\...` or `/home/...`) are strictly forbidden on the wire.
2. **Never Use Timestamps as Conflict Authority:**
   - Conflict resolution and causal event ordering are governed by `CausalClock` vector clocks (`peer_vectors` mapping peer IDs to monotonically increasing logical counters).
   - UTC millisecond timestamps (`client_modified_hint_utc_ms`, `timestamp_utc_ms`) serve solely as advisory human display hints or TTLs, never as conflict arbitration authorities.
3. **Strict Separation of Object ID and Content Hash:**
   - `ObjectId` represents object identity over time across mutations.
   - `ContentHash` represents cryptographic verification of specific payload bytes at a specific version (`algorithm`, `hex_digest`, `hash_bytes`).
4. **Durable and Unique Operation ID:**
   - All actions are represented by an `OperationRecord` bearing a globally unique `OperationId` and an `idempotency_key` ensuring safe at-least-once transmission and recovery.
5. **Capability Model is Descriptive and May Become Stale:**
   - Capabilities (`CapabilityDescriptor`) describe feature support (`is_enabled`, `valid_until_utc_ms`, `parameters`).
   - Stale capabilities are handled gracefully. Capability negotiation (`CapabilityNegotiationRequest` / `CapabilityNegotiationResponse`) cleanly lists `unsupported_features` without crashing older peers.
6. **Machine-Readable & Human-Explainable Errors:**
   - Every error (`ErrorDetail`) provides a structured `ErrorCode`, a canonical `error_name`, a concise `human_summary`, a detailed `human_explanation`, a concrete `suggested_recovery_action`, and an explicit `is_retryable` flag.
7. **Forward and Backward Compatibility:**
   - Unknown and future protobuf fields are preserved by parsers across all three runtime environments (Java `UnknownFieldSet`, Dart unknown fields, Kotlin property delegates).

---

## 2. Foundational Entities

| Entity | Proto Message | Purpose | Invariants Enforced |
| :--- | :--- | :--- | :--- |
| **Protocol Header** | `peerlink.v1.ProtocolHeader` | Versioning & trace metadata | Defines `version`, `min_supported_version`, `trace_id`, and `feature_flags`. |
| **Peer & Device** | `peerlink.v1.PeerIdentity`, `peerlink.v1.DeviceIdentity` | Cross-device pairing & trust | Public keys (`CryptographicKey`), trust levels, fingerprint hex, device types. |
| **Capability** | `peerlink.v1.CapabilityNegotiationRequest/Response` | Dynamic feature negotiation | Explicit agreement, TTL validity, graceful degraded response for unsupported features. |
| **Session** | `peerlink.v1.SessionDescriptor` | Authenticated peer leases | Direct QUIC, Direct TCP/TLS, or TURN relay sessions with explicit expiry and state. |
| **ObjectReference** | `peerlink.v1.ObjectReference` | Data unit abstraction | Separates logical ID from cryptographic hash; uses vector clock causal ordering. |
| **Operation** | `peerlink.v1.OperationRecord` | Distributed state transition | Durable ID, idempotency key, target object references, deterministic state machine. |
| **Error** | `peerlink.v1.ErrorDetail` | Failure signaling | Structured `ErrorCode` enum, retryability indicator, actionable recovery guidance. |
| **Event Envelope** | `peerlink.v1.PeerLinkEvent` | Universal asynchronous dispatch | Polymorphic envelope carrying session, capability, operation, or peer events. |

---

## 3. Wire Format Compatibility Matrix

All contracts have been verified with bidirectional binary serialization and deserialization across the three platform target runtimes:

```
                  ┌──────────────────────────────┐
                  │    Protobuf Wire (proto3)    │
                  └──────────────┬───────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   Java 17/25     │   │     Dart 3.3     │   │      Kotlin      │
│  (Desktop Node)  │   │  (Flutter UI/App)│   │ (Android Module) │
└──────────────────┘   └──────────────────┘   └──────────────────┘
```

### Verified Test Fixtures
- `peer_identity.bin`: Ed25519 identity keys, device classification, trust level.
- `object_reference.bin`: Path-independent object reference with SHA-256 digest and vector clock.
- `operation_record.bin`: Sync operation record with durable UUID and idempotency key.
- `error_detail.bin`: Structured error detail with recovery guidance and retry flag.
- `capability_response.bin`: Capability negotiation response with graceful `unsupported_features`.
- `peerlink_event.bin`: Universal event envelope containing an established session descriptor.
- `dart_session.bin` / `dart_operation.bin` / `dart_error.bin`: Dart-serialized binaries parsed and verified by Java.

---

## 4. Capability Negotiation Workflow

```mermaid
sequenceDiagram
    autonumber
    participant NodeA as Peer A (Desktop/Java)
    participant NodeB as Peer B (Mobile/Flutter/Android)

    Note over NodeA, NodeB: Capability Negotiation Phase
    NodeA->>NodeB: CapabilityNegotiationRequest (Supported features, protocol version)
    Note over NodeB: Evaluate supported capabilities against local constraints
    NodeB-->>NodeA: CapabilityNegotiationResponse
    Note over NodeB: Returns accepted_capabilities & graceful unsupported_features list
    Note over NodeA: Node A marks unsupported features as disabled; no crash or disconnect
```

---

## 5. Artifact Directory Layout

```
PeerLink/
├── protocol/
│   ├── proto/peerlink/v1/
│   │   ├── common.proto
│   │   ├── identity.proto
│   │   ├── capability.proto
│   │   ├── session.proto
│   │   ├── object_reference.proto
│   │   ├── operation.proto
│   │   ├── error.proto
│   │   ├── event.proto
│   │   ├── discovery.proto
│   │   ├── trust.proto
│   │   ├── transfer.proto
│   │   └── ipc.proto
│   ├── generated-java/
│   ├── generated-dart/
│   └── src/test/
│       ├── java/org/peerlink/protocol/ProtocolContractCompatibilityTest.java
│       └── kotlin/org/peerlink/protocol/ProtocolKotlinCompatibilityTest.kt
├── apps/peerlink-app/
│   ├── lib/core/protocol/peerlink/v1/
│   └── test/protocol_contract_compatibility_test.dart
```
