# PeerLink — Decision Log / ADR Index

This index is the place to record future changes. Do not silently edit frozen architecture decisions.

## ADR template

```text
# ADR-XXXX — Title

Status: Proposed | Accepted | Superseded | Rejected
Date: YYYY-MM-DD

## Context

## Decision

## Alternatives considered

## Consequences

## Verification evidence

## Supersedes
```

## Initial decisions

- ADR-0001: Flutter is the cross-platform application layer.
- ADR-0002: Java 25 is the desktop Local Node runtime.
- ADR-0003: Portable JVM logic uses an Android-compatible API baseline.
- ADR-0004: Protobuf is the common cross-platform contract.
- ADR-0005: Desktop Flutter ↔ Java Node uses authenticated local gRPC.
- ADR-0006: Android Flutter ↔ native layer uses Pigeon/platform APIs.
- ADR-0007: Supabase is control plane only; no normal P2P file storage.
- ADR-0008: Transport is abstract; Netty/QUIC is a desktop implementation, not a universal mandate.
- ADR-0009: Android is a full node with OS-constrained availability.
- ADR-0010: Malware scanning is provider-based and not equivalent to antivirus replacement.

## Rule

If implementation reveals a genuine contradiction, stop the affected phase, record an ADR, update the contradiction audit, then continue from the corrected contract.
