# PeerLink Post-1.0 Change Policy & Architectural Invariants

**Document**: `docs/maintenance/CHANGE-POLICY.md`  
**Version**: 1.0.0  
**Phase**: 30 (Maintainer & Architecture Governance)  
**Status**: ACTIVE & MANDATORY  
**Audience**: Maintainers, Architecture Review Board, Core Contributors, AI Agents  

---

## 1. Foundational Principle: End of Feature-Discovery Mode

With the General Availability (GA) release of **PeerLink 1.0.0**, the product is **no longer in feature-discovery mode**. 

PeerLink has achieved a stable, verified, production-hardened baseline. The architecture is **frozen**. Uncontrolled feature growth, speculative redesigns, and architectural drift degrade reliability, compromise security, and increase maintenance friction. 

Every future change must be:
* **Evidence-driven**: Grounded in verifiable empirical observations, logs, or CVEs.
* **Tested**: Accompanied by pre-existing or test-driven unit/integration regressions.
* **Documented**: Fully tracked in architecture documentation and release notes.
* **Backward-aware**: Wire-compatible with existing V1.0.0 nodes.
* **Security-reviewed**: Evaluated against the zero-trust threat matrix.
* **Architecture-reviewed**: Governed by an approved Architectural Decision Record (ADR) whenever subsystem boundaries or invariant contracts are affected.

---

## 2. Valid vs. Invalid Reasons for Change

### 2.1 Strictly Valid Reasons for Change
A pull request or proposed change is eligible for consideration **only** if justified by one or more of the following six criteria:

1. **Security Vulnerability**: A confirmed vulnerability, weakness, or CVE in application code or upstream dependencies.
2. **Data-Loss or Correctness Problem**: A bug leading to data corruption, failed checkpointing, vector clock desynchronization, or data truncation.
3. **Unavoidable Platform Requirement**: Breaking changes mandated by OS vendors (e.g. Google Play target SDK bumps, Android foreground service permission policies, macOS hardened runtime requirements, Windows API deprecations, or Java LTS runtime evolutions).
4. **Protocol Compatibility Requirement**: Ensuring ongoing inter-node interoperability across supported versions or standards compliance.
5. **Proven Performance or Scalability Limitation**: Measurable bottleneck backed by telemetry flamegraphs, memory dumps, or network packet traces (not theoretical micro-optimizations).
6. **Critical Operational Problem**: Production relay failures, cloud control plane schema compatibility, or certificate rotation failures.

---

### 2.2 Invalid Justifications (Rejected by Default)
A proposal is **invalid** and must be rejected without architecture board review if its primary justification relies on:

* ❌ *"This technology / library is trendy or modern"*
* ❌ *"Another application has this feature"*
* ❌ *"AI suggested or generated it"*
* ❌ *"It would be cool / nice to have"*
* ❌ *"We could add just one more mode / option / setting"*
* ❌ *"Speculative future-proofing for hypothetical requirements"*

---

## 3. Mandatory 15-Step Evaluation Procedure

Every proposed code or configuration change must pass through the following 15-step evaluation protocol:

```
[1. Explain Problem] ──► [2. Gather Evidence] ──► [3. Current Arch Check]
                                                            │
[6. Data Integrity] ◄── [5. Security Impact] ◄── [4. Compatibility Impact]
        │
        ▼
[7. Migration Impact] ─► [8. Protocol Impact] ──► [9. Platform Impact]
                                                            │
[12. Smallest Fix] ◄─── [11. Pre-Change Tests] ◄── [10. ADR Required?]
        │
        ▼
[13. Regression Run] ──► [14. Doc Update] ──────► [15. Standard Release]
```

1. **Explain Problem**: Articulate the exact failure mode, limitation, or requirement.
2. **Gather Evidence**: Provide reproducer script, crash trace, CVE identifier, or profiling metrics.
3. **Check Current Architecture**: Determine whether existing extension points, configuration flags, or subsystems already solve the problem without modification.
4. **Determine Compatibility Impact**: Verify that V1.0.0 nodes can continue communicating with upgraded nodes over QUIC, TLS, and gRPC.
5. **Determine Security Impact**: Review attack surfaces, cryptographic invariants (Ed25519, AES-GCM), key isolation, and ensure zero service-role keys are exposed.
6. **Determine Data-Integrity Impact**: Confirm SHA-256 integrity hashing, atomic database writes (WAL), and causal vector clock rules are preserved.
7. **Determine Migration Impact**: Validate that local SQLite migrations remain strictly additive (Schema v3+).
8. **Determine Protocol Impact**: Check protobuf schema numbers in `protocol/src/main/proto/`. No breaking field changes or tag renumbering.
9. **Determine Platform Impact**: Test behavior across Windows, macOS, Linux, and Android.
10. **Create ADR**: If architectural boundaries or wire formats are altered, draft an ADR in `docs/adr/`.
11. **Add Tests First**: Write failing regression tests capturing the defect before applying code modifications.
12. **Implement Smallest Justified Change**: Apply the minimal targeted diff. Resist refactoring unrelated code.
13. **Run Regression Suite**: Execute `mvn clean test` across parent, protocol, core, and desktop modules.
14. **Update Documentation**: Update relevant manuals in `docs/operations/`, `docs/release/`, and `docs/maintenance/`.
15. **Release via Normal Process**: Bundle and distribute through the official release pipeline with semantic versioning.

---

## 4. Anti-Drift Guardrails

### 4.1 Bug Fixes Must Not Redefine Semantics
* A bug fix must restore documented behavior, not silently alter API contracts, state machine transitions, or wire schemas.
* If a fix requires semantic alterations, it must be elevated to an Architectural Review.

### 4.2 AI Governance Invariant
* AI coding assistants, agents, and subagents must strictly adhere to this governance policy.
* AI-suggested code changes are subject to the same empirical validation, test enforcement, and architectural review as human contributions. No AI-generated change may bypass these guardrails.
