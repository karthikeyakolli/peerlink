# ADR-000: Post-1.0 Architecture Freeze and Governance Protocol

* **Status**: ACCEPTED  
* **Date**: October 2026  
* **Deciders**: PeerLink Maintainers, Architecture Review Board  
* **Scope**: Entire Repository & All Client/Server Subsystems  

---

## 1. Context and Problem Statement

PeerLink has achieved General Availability (GA) with release `1.0.0`. Over 30 intensive development and verification phases have hardened the multi-transport peer engine (QUIC/TLS/TURN), causal CRDT folder synchronization, chunk-based streaming transfer, zero-trust Supabase control plane, and cross-platform native integrations (Windows, Linux, macOS, Android).

Following release, projects face severe risks of **architectural drift**, **silent semantic mutations disguised as bug fixes**, and **uncontrolled feature expansion**. Without rigorous governance, well-intentioned modifications or AI-suggested changes erode stability, introduce protocol incompatibilities, and break user trust.

---

## 2. Decision

We establish an official **Architecture Freeze** on the PeerLink V1 baseline:

1. **Frozen Baseline**:
   * The system architecture, wire protocol specification (`org.peerlink.protocol.v1`), cryptographic identity models, and storage schemas are frozen.
   * No exploratory or speculative feature development is permitted on the V1 maintenance track.
2. **Valid Change Justifications**:
   * Architectural or code modifications are permitted **only** for:
     1. Security vulnerabilities (CVEs / threat mitigations).
     2. Data-loss or correctness defects.
     3. Mandatory OS/platform requirements (e.g. Android TargetSdk).
     4. Protocol compatibility requirements.
     5. Telemetry-backed performance/scalability bottlenecks.
     6. Critical operational failures.
3. **Mandatory ADR Requirement**:
   * Any change that alters module boundaries, introduces new network protocols, modifies public IPC definitions, or alters database semantics **must** submit an Architectural Decision Record (ADR) in `docs/adr/` and receive formal maintainer sign-off prior to implementation.
4. **Zero Semantic Drift for Bug Fixes**:
   * Bug fixes must restore documented specifications without redefining product contracts.
5. **AI Governance**:
   * All AI-generated or agent-assisted contributions are subject to the same strict governance and verification checks as human engineers.

---

## 3. Consequences

### Positive
* **Rock-Solid Stability**: Production users are protected from breaking changes or sudden behavioral shifts.
* **Predictable Maintenance**: Clear cadences and verification checklists streamline operational duties.
* **Deterministic Compatibility**: All V1.0.x nodes maintain 100% interoperability across local LAN and internet relays.

### Negative / Trade-Offs
* **Deliberate Development Velocity**: Rapid speculative prototyping is restricted in favor of stability.
* **Higher Governance Bar**: Every proposed change requires empirical justification, test automation, and documentation before merge.
